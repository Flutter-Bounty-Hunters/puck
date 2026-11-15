import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/performance/run.dart' as runner;
import '../tool/performance/cpu_profile.dart';

Map<String, dynamic> report() => {
  'config': {'variant': 'solid_single'},
  'mode': 'debug',
  'success': true,
  'scenarios': [
    for (final name in runner.scenarios)
      {
        'name': name,
        'repetition': 1,
        'start_us': 0,
        'end_us': 10000,
        'duration_ms': 10,
        'milestones_ms': {'first_content_emergence': 4, 'settled': 10},
        'metrics': {
          'frame_count': 1,
          'over_budget_percent': 0,
          'ui': {'p95_ms': 1, 'max_ms': 1},
          'raster': {'p95_ms': 2, 'max_ms': 2},
        },
      },
  ],
};

void main() {
  test('CPU compaction preserves every stack and remaps its symbols', () {
    final profile = compactCpuSamples({
      'sampleCount': 2,
      'functions': [
        {'function': 'unused'},
        {'function': 'caller'},
        {'function': 'leaf'},
      ],
      'samples': [
        {
          'timestamp': 1,
          'stack': [2, 1],
        },
        {
          'timestamp': 2,
          'stack': [1],
        },
      ],
    });
    expect(profile['functions'], [
      {'function': 'caller'},
      {'function': 'leaf'},
    ]);
    expect(profile['samples'], [
      {
        'timestamp': 1,
        'stack': [1, 0],
      },
      {
        'timestamp': 2,
        'stack': [0],
      },
    ]);
    expect(profile['sampleCount'], 2);
    expect(profile['unreferenced_symbols_removed'], 1);
    expect(compactCpuSamples(profile), profile);
  });
  test('opening profiler preserves fresh first open and gathers CPU data', () {
    final options = runner.RunnerOptions([
      '--profile-opening',
      '--repeats',
      '1',
    ]);
    final command = runner.launchCommand(
      options,
      'glass_three_tier',
      'profile',
      'phone',
    );
    expect(command, contains('--dart-define=PUCK_TRACE_OPENING=true'));
    expect(command, contains('--profile-startup'));
    expect(
      command[command.indexOf('--route') + 1],
      contains('opening_profile=1'),
    );
    final data = report();
    data['scenarios'] = (data['scenarios'] as List)
        .where(
          (s) =>
              ['first_open', 'repeat_close', 'repeat_open'].contains(s['name']),
        )
        .toList();
    runner.validateReport(data, 'solid_single', 1, openingOnly: true);
    expect(
      () => runner.validateReport(data, 'solid_single', 1),
      throwsStateError,
    );
  });
  test(
    'checkpoints replace one complete JSON file without extra artifacts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'puck-checkpoint-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/run.json');
      await runner.writeJson(file, {'status': 'running'});
      await runner.writeJson(file, {
        'status': 'complete',
        'samples': [1, 2],
      });
      expect(jsonDecode(await file.readAsString()), {
        'status': 'complete',
        'samples': [1, 2],
      });
      expect(await directory.list().length, 1);
    },
  );

  test('measurements require profile mode on hardware', () {
    expect(
      () => runner.selectMode('auto', {
        'targetPlatform': 'ios',
        'emulator': true,
      }),
      throwsStateError,
    );
    expect(
      runner.selectMode('auto', {'targetPlatform': 'ios', 'emulator': false}),
      'profile',
    );
  });

  test('launch route preserves benchmark options with one app entry point', () {
    final options = runner.RunnerOptions([
      '--repeats',
      '3',
      '--curves',
      '--device-connection',
      'attached',
    ]);
    final command = runner.launchCommand(
      options,
      'glass_three_tier',
      'profile',
      'device',
    );
    expect(command, contains('lib/performance/main.dart'));
    expect(command[command.indexOf('--device-connection') + 1], 'attached');
    final route = Uri.parse(command[command.indexOf('--route') + 1]);
    expect(route.path, '/glass_three_tier');
    expect(route.queryParameters, containsPair('automated', '1'));
    expect(route.queryParameters, containsPair('repeats', '3'));
    expect(route.queryParameters, isNot(contains('prepare')));
    expect(route.queryParameters, containsPair('curves', '1'));
    expect(runner.RunnerOptions(['--cold-runs=2']).coldRuns, 2);
  });

  test('invalid options fail before launching an app', () {
    for (final arguments in [
      ['--unknown'],
      ['--device'],
      ['--trace=true'],
      ['--repeats', '0'],
      ['--budget-fps', 'NaN'],
      ['--timeout', '-1'],
      ['--mode', 'release'],
      ['--mode', 'debug'],
      ['--device-connection', 'invalid'],
      ['--variants', 'solid_single,solid_single'],
      ['--variants', 'unknown'],
    ]) {
      expect(
        () => runner.RunnerOptions(arguments),
        throwsFormatException,
        reason: arguments.join(' '),
      );
    }
  });

  test(
    'missing motion, scenarios, frames, and wrong variants fail validation',
    () {
      runner.validateReport(report(), 'solid_single', 1);
      final noMotion = report();
      noMotion['scenarios'][0]['milestones_ms'] = <String, dynamic>{};
      expect(
        () => runner.validateReport(noMotion, 'solid_single', 1),
        throwsStateError,
      );
      final noScenario = report();
      (noScenario['scenarios'] as List).removeLast();
      expect(
        () => runner.validateReport(noScenario, 'solid_single', 1),
        throwsStateError,
      );
      final noFrames = report();
      noFrames['scenarios'][0]['metrics']['frame_count'] = 0;
      expect(
        () => runner.validateReport(noFrames, 'solid_single', 1),
        throwsStateError,
      );
      expect(
        () => runner.validateReport(report(), 'glass_single', 1),
        throwsStateError,
      );
      expect(
        () => runner.validateReport(report(), 'solid_single', 2),
        throwsStateError,
      );
    },
  );

  test('one JSON file contains summaries and every launch artifact', () async {
    final directory = await Directory.systemTemp.createTemp(
      'puck-runner-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final cases = <Map<String, dynamic>>[
      {
        'variant': 'solid_single',
        'launch': 1,
        'report': report(),
        'command': ['flutter', 'run'],
        'process': {'pid': 123, 'start_time': 456},
        'flutter_log': 'launch output\nApplication finished.\n',
        'traces': [
          {
            'completed_scenarios': 9,
            'timeline': {
              'traceEvents': [
                {'name': 'frame'},
              ],
            },
          },
        ],
      },
      {
        'variant': 'glass_single', 'launch': 1,
        'error': 'device disconnected', 'flutter_log': 'connection lost\n',
        // Invalid raw reports are retained but excluded from aggregate samples.
        'report': {
          'success': false,
          'scenarios': [
            {'incomplete': true},
          ],
        },
      },
    ];
    final summary = runner.summarizeRun(cases);
    await runner.writeJson(File('${directory.path}/run.json'), {
      'schema_version': 2,
      'status': 'failed',
      'cases': cases,
      'summary': summary,
    });
    final files = await directory.list().toList();
    expect(files, hasLength(1));
    final saved = jsonDecode(await (files.single as File).readAsString());
    expect(saved['summary']['samples'], hasLength(runner.scenarios.length));
    expect(saved['summary']['markdown'], contains('Failed launches: 1'));
    expect(saved['summary']['markdown'], contains('device disconnected'));
    expect(saved['summary']['markdown'], contains('Build mode: debug'));
    expect(saved['cases'], cases);
    expect(runner.median([1, 5, 2, 4]), 3);
  });
}
