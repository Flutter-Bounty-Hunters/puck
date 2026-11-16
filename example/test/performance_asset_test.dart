import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puck_example/performance/performance_results.dart';

import '../tool/performance/publish.dart';

Map<String, dynamic> report({String started = '2026-11-13T14:00:00Z'}) => {
  'schema_version': 2,
  'status': 'complete',
  'mode': 'profile',
  'started_utc': started,
  'device': {'name': 'Measured device'},
  'parameters': {'profile_opening': false},
  'cases': [
    {
      'variant': 'solid_single',
      'launch': 1,
      'flutter_log': 'Original log',
      'traces': [
        {'traceEvents': []},
      ],
      'cpu_profiles': [{}],
      'opening_timeline': {
        'traceEvents': [{}, {}],
      },
      'report': {
        'mode': 'profile',
        'success': true,
        'scenarios': [
          {
            'name': 'first_open',
            'repetition': 1,
            'metrics': {
              'frame_count': 1,
              'ui': {'p95_ms': 2},
            },
            'milestones_ms': {'first_item_motion': 12},
            'frames': [
              {'build_us': 2000, 'raster_us': 1000, 'total_us': 3500},
            ],
          },
        ],
      },
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real published results load from the app asset', () async {
    final run = await loadBundledPerformanceRun();
    expect(run.status, 'complete');
    expect(run.mode, 'profile');
    expect(run.launches, isNotEmpty);
    expect(run.launches.every((launch) => launch.success), isTrue);
    expect(run.samples.any((sample) => sample.frames.isNotEmpty), isTrue);
    expect(run.data['publication']['source_file'], endsWith('.json'));
  });

  test(
    'publication preserves real measurements and diagnostic counts',
    () async {
      final directory = await Directory.systemTemp.createTemp('puck-publish-');
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/run.json');
      final asset = File('${directory.path}/assets/latest.json');
      final data = report();
      await source.writeAsString(jsonEncode(data));
      await publishPerformanceRun(source, asset);
      final saved =
          jsonDecode(await asset.readAsString()) as Map<String, dynamic>;
      expect(saved['cases'][0]['report'], data['cases'][0]['report']);
      expect(saved['cases'][0]['flutter_log'], 'Original log');
      expect(saved['cases'][0].containsKey('traces'), isFalse);
      final run = parsePerformanceRun(await asset.readAsString());
      expect(run.launches.single.data['trace_count'], 1);
      expect(run.launches.single.data['cpu_profile_count'], 1);
      expect(run.launches.single.data['opening_timeline_event_count'], 2);
      expect(run.samples.single.frames.single['build_us'], 2000);
    },
  );

  test('failed, diagnostic, and running results cannot replace the published asset', () async {
    final directory = await Directory.systemTemp.createTemp('puck-publish-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/run.json');
    final asset = File('${directory.path}/latest.json');
    await asset.writeAsString('previous results');
    for (final data in [
      {...report(), 'status': 'failed'},
      {...report(), 'status': 'running'},
      {
        ...report(),
        'parameters': {'profile_opening': true},
      },
      {...report(), 'mode': 'debug'},
    ]) {
      await source.writeAsString(jsonEncode(data));
      await expectLater(
        publishPerformanceRun(source, asset),
        throwsFormatException,
      );
      expect(await asset.readAsString(), 'previous results');
    }
  });

  test('publication selects the newest complete benchmark rather than diagnostic captures', () async {
    final directory = await Directory.systemTemp.createTemp('puck-publish-');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/older.json')
        .writeAsString(jsonEncode(report(started: '2026-11-12T14:00:00Z')));
    final latest = File('${directory.path}/latest.json');
    await latest.writeAsString(jsonEncode(report()));
    await File('${directory.path}/diagnostic.json').writeAsString(
      jsonEncode({
        ...report(started: '2026-11-14T14:00:00Z'),
        'parameters': {'profile_opening': true},
      }),
    );
    await File('${directory.path}/running.json').writeAsString(
      jsonEncode({
        ...report(started: '2026-11-15T14:00:00Z'),
        'status': 'running',
      }),
    );
    expect(
      (await latestPublishablePerformanceRun(directory))?.path,
      latest.path,
    );
  });
}
