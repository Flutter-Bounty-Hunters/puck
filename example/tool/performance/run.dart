// Run from example: dart run tool/performance/run.dart --device <device-id>
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:puck_example/performance/performance_asset.dart';

import 'cpu_profile.dart';
import 'publish.dart' as published;

typedef Json = Map<String, dynamic>;

const variants = [
  'solid_single',
  'solid_three_level',
  'photos_single',
  'photos_three_level',
  'glass_single',
  'glass_three_level',
];
const scenarios = [
  'first_open',
  'repeat_close',
  'repeat_open',
  'closed_pull',
  'closed_rapid_drag',
  'closed_release',
  'open_pull',
  'open_rapid_drag',
  'open_release',
];
const help = '''Cold-launch menu demos and collect real engine frame timings.

Run from example:
  dart run tool/performance/run.dart --device <device-id>

Options:
  --device <id>           Flutter device ID or unambiguous prefix
  --device-connection <type>  both (default), attached (USB), or wireless
  --mode <mode>           auto (default) or profile; measurements require profile
  --flutter <path>        Flutter executable (default: flutter on PATH)
  --variants <ids>        Comma-separated variants (default: all six)
  --cold-runs <count>     Fresh launches per variant (default: 1)
  --repeats <count>       Close/open pairs per launch (default: 5)
  --start-delay-ms <ms>   First tap delay after first frame (default: 250)
  --budget-fps <fps>      Measurement budget, not refresh-rate request (default: 60)
  --timeout <seconds>     Per-launch timeout including build (default: 300)
  --output <file>         New self-contained JSON file
  --binary <path>         Prebuilt app from lib/performance/main.dart
  --curves               Include level curves in every variant
  --trace                Save incremental VM traces (adds overhead)
  --profile-opening      Capture opening timeline and CPU call stacks
  --dry-run              Print launch commands without launching
  --help                 Show this help
''';

class RunnerOptions {
  RunnerOptions(List<String> arguments) {
    const flags = {'curves', 'trace', 'dry-run', 'help', 'profile-opening'};
    const values = {
      'device',
      'device-connection',
      'mode',
      'flutter',
      'variants',
      'cold-runs',
      'repeats',
      'start-delay-ms',
      'budget-fps',
      'timeout',
      'output',
      'binary',
    };
    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i];
      if (argument == '-h') {
        _arguments['help'] = 'true';
        continue;
      }
      if (!argument.startsWith('--')) {
        throw FormatException('Unexpected argument: $argument');
      }
      final parts = argument.substring(2).split('=');
      final name = parts.first;
      if (flags.contains(name)) {
        if (parts.length != 1) throw FormatException('--$name takes no value');
        _arguments[name] = 'true';
      } else if (values.contains(name)) {
        if (parts.length > 1) {
          _arguments[name] = parts.skip(1).join('=');
        } else {
          if (++i == arguments.length || arguments[i].startsWith('--')) {
            throw FormatException('--$name requires a value');
          }
          _arguments[name] = arguments[i];
        }
      } else {
        throw FormatException('Unknown option: --$name');
      }
    }
    if (showHelp) return;
    if (selectedVariants.toSet().length != selectedVariants.length) {
      throw const FormatException('Duplicate variants would overwrite results');
    }
    if (selectedVariants.any((v) => !variants.contains(v))) {
      throw FormatException(
        'Unknown variant. Choose from ${variants.join(', ')}',
      );
    }
    if (!{'auto', 'profile'}.contains(mode)) {
      throw const FormatException(
        'Performance measurements require profile mode',
      );
    }
    if (!{'both', 'attached', 'wireless'}.contains(deviceConnection)) {
      throw const FormatException(
        'Device connection must be both, attached, or wireless',
      );
    }
    if (coldRuns < 1 ||
        repeats < 1 ||
        startDelayMs < 0 ||
        !budgetFps.isFinite ||
        budgetFps <= 0 ||
        !timeoutSeconds.isFinite ||
        timeoutSeconds <= 0) {
      throw const FormatException(
        'Counts/FPS/timeout must be positive and finite; startup delay must be nonnegative',
      );
    }
  }

  final _arguments = <String, String>{};
  String? get device => _arguments['device'];
  String get deviceConnection => _arguments['device-connection'] ?? 'both';
  String get mode => _arguments['mode'] ?? 'auto';
  String get flutter => _arguments['flutter'] ?? 'flutter';
  List<String> get selectedVariants =>
      (_arguments['variants'] ?? variants.join(',')).split(',');
  int get coldRuns => int.parse(_arguments['cold-runs'] ?? '1');
  int get repeats => int.parse(_arguments['repeats'] ?? '5');
  int get startDelayMs => int.parse(_arguments['start-delay-ms'] ?? '250');
  double get budgetFps => double.parse(_arguments['budget-fps'] ?? '60');
  double get timeoutSeconds => double.parse(_arguments['timeout'] ?? '300');
  String? get output => _arguments['output'];
  String? get binary => _arguments['binary'];
  bool get curves => _arguments.containsKey('curves');
  bool get trace => _arguments.containsKey('trace');
  bool get profileOpening => _arguments.containsKey('profile-opening');
  bool get dryRun => _arguments.containsKey('dry-run');
  bool get showHelp => _arguments.containsKey('help');
  Json toJson() => {
    'device': device,
    'device_connection': deviceConnection,
    'mode': mode,
    'flutter': flutter,
    'variants': selectedVariants,
    'cold_runs': coldRuns,
    'repeats': repeats,
    'start_delay_ms': startDelayMs,
    'budget_fps': budgetFps,
    'timeout': timeoutSeconds,
    'output': output,
    'binary': binary,
    'curves': curves,
    'trace': trace,
    'profile_opening': profileOpening,
  };
}

String selectMode(String requested, Json device) {
  final platform = device['targetPlatform'] as String? ?? '';
  if (device['emulator'] == true || platform.startsWith('web')) {
    throw StateError(
      'Performance measurements require a physical device in profile mode. Simulators can only be used to review saved results.',
    );
  }
  if (!{'auto', 'profile'}.contains(requested)) {
    throw const FormatException(
      'Performance measurements require profile mode',
    );
  }
  return 'profile';
}

List<String> launchCommand(
  RunnerOptions options,
  String variant,
  String mode,
  String deviceId,
) {
  final query = Uri(
    queryParameters: {
      'automated': '1',
      'repeats': '${options.repeats}',
      'start_delay_ms': '${options.startDelayMs}',
      'budget_fps': '${options.budgetFps}',
      'curves': options.curves ? '1' : '0',
      'opening_profile': options.profileOpening ? '1' : '0',
    },
  ).query;
  return [
    options.flutter,
    'run',
    '-d',
    deviceId,
    '--device-connection',
    options.deviceConnection,
    '--$mode',
    '-t',
    'lib/performance/main.dart',
    '--route',
    '/$variant?$query',
    '--disable-dds',
    '--host-vmservice-port=0',
    if (options.profileOpening) ...[
      '--dart-define=PUCK_TRACE_OPENING=true',
      '--enable-dart-profiling',
      '--profile-startup',
      '--endless-trace-buffer',
    ],
    if (options.binary != null) ...[
      '--use-application-binary',
      File(options.binary!).absolute.path,
    ],
  ];
}

Future<Json> resolveDevice(RunnerOptions options, Directory example) async {
  final result = await Process.run(options.flutter, [
    'devices',
    '--device-connection',
    options.deviceConnection,
    '--machine',
  ], workingDirectory: example.path);
  if (result.exitCode != 0) {
    throw StateError('Flutter device discovery failed: ${result.stderr}');
  }
  final devices = (jsonDecode(result.stdout as String) as List).cast<Json>();
  final matches = devices
      .where(
        (device) =>
            device['isSupported'] != false &&
            (options.device == null ||
                (device['id'] as String).startsWith(options.device!)),
      )
      .toList();
  if (matches.length != 1) {
    throw StateError(
      'Select exactly one device with --device. Available:\n'
      '${devices.map((d) => '  ${d['id']}: ${d['name']}').join('\n')}',
    );
  }
  return matches.single;
}

Future<Json> rpc(
  String base,
  String method, [
  Map<String, String>? params,
]) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final uri = Uri.parse('$base$method').replace(queryParameters: params);
    return await (() async {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('VM service HTTP ${response.statusCode}: $body');
      }
      final value = jsonDecode(body) as Json;
      if (value.containsKey('error')) {
        throw StateError('$method: ${value['error']}');
      }
      return value['result'] as Json;
    })().timeout(const Duration(seconds: 15));
  } finally {
    client.close(force: true);
  }
}

Future<void> writeJson(File file, Object value) async {
  // Reviewers can read the previous checkpoint while the next is encoded.
  final pending = File('${file.path}.$pid.tmp');
  try {
    await pending.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(value)}\n',
      flush: true,
    );
    await pending.rename(file.path);
  } finally {
    if (await pending.exists()) await pending.delete();
  }
}

void validateReport(
  Json report,
  String variant,
  int repeats, {
  bool openingOnly = false,
}) {
  if ((report['config'] as Json?)?['variant'] != variant) {
    throw StateError(
      'App returned a different variant; refusing contaminated cold data',
    );
  }
  if (report['success'] != true) {
    throw StateError('App errors: ${report['errors']}');
  }
  final samples = (report['scenarios'] as List? ?? []).cast<Json>();
  for (final name in scenarios) {
    if (openingOnly &&
        !['first_open', 'repeat_close', 'repeat_open'].contains(name)) {
      continue;
    }
    final matching = samples.where((s) => s['name'] == name).toList();
    final expected = name.startsWith('repeat_') ? repeats : 1;
    if (matching.length != expected) {
      throw StateError(
        '$name: expected $expected samples, received ${matching.length}',
      );
    }
    for (final sample in matching) {
      if (sample['end_us'] == null || sample['metrics']['frame_count'] == 0) {
        throw StateError('$name: incomplete scenario or no engine frame data');
      }
    }
  }
  final cold = samples.firstWhere((s) => s['name'] == 'first_open');
  if (!(cold['milestones_ms'] as Json).containsKey('first_content_emergence')) {
    throw StateError('First opening never produced a visible menu item');
  }
}

Future<void> stopProcess(Process process) async {
  Future<bool> exited(int seconds) async {
    try {
      await process.exitCode.timeout(Duration(seconds: seconds));
      return true;
    } on TimeoutException {
      return false;
    }
  }

  try {
    process.stdin.writeln('q');
    await process.stdin.flush();
    if (await exited(15)) return;
  } on IOException {
    // Flutter may already have exited.
  } on StateError {
    // stdin may already be closed.
  }
  for (final attempt in [
    (ProcessSignal.sigint, 10),
    (ProcessSignal.sigterm, 5),
    (ProcessSignal.sigkill, 5),
  ]) {
    process.kill(attempt.$1);
    if (await exited(attempt.$2)) return;
  }
  throw StateError('Could not stop Flutter process ${process.pid}');
}

Future<void> runCase(
  RunnerOptions options,
  String variant,
  String mode,
  Json device,
  Directory example,
  Json entry,
  Set<String> seenProcesses, {
  required bool Function() interrupted,
}) async {
  final command = launchCommand(options, variant, mode, device['id'] as String);
  entry['command'] = command;
  entry['flutter_log'] = '';
  entry['traces'] = <Json>[];
  final process = await Process.start(
    command.first,
    command.skip(1).toList(),
    workingDirectory: example.path,
  );
  final log = StringBuffer();
  // Observe stdin failures even if the app exits before cleanup writes to it.
  unawaited(process.stdin.done.catchError((Object _) {}));
  final ansi = RegExp(r'\x1b\[[0-9;]*[A-Za-z]');
  final serviceUrl = RegExp(r'Dart VM Service.*?(http://[^\s]+/)');
  String? base;
  int? exitStatus;
  unawaited(
    process.exitCode.then((value) {
      exitStatus = value;
    }),
  );
  Future<void> consume(Stream<List<int>> stream) async {
    await for (final raw
        in stream
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())) {
      final line = raw.replaceAll(ansi, '').replaceAll('\r', '');
      log.writeln(line);
      final match = serviceUrl.firstMatch(line);
      if (match != null) base = match.group(1);
    }
  }

  final readers = Future.wait([
    consume(process.stdout),
    consume(process.stderr),
  ]);
  final elapsed = Stopwatch()..start();
  String? isolate;
  Json? vm;
  var traceCount = 0;
  String? progress;
  try {
    while (elapsed.elapsedMilliseconds < options.timeoutSeconds * 1000) {
      if (interrupted()) throw StateError('Run interrupted');
      if (exitStatus != null) {
        throw StateError(
          'Flutter exited with $exitStatus; see this launch’s flutter_log',
        );
      }
      if (base != null && isolate == null) {
        vm = await rpc(base!, 'getVM');
        isolate =
            (vm['isolates'] as List).cast<Json>().firstWhere(
                  (i) => i['isSystemIsolate'] != true,
                )['id']
                as String;
        if (!seenProcesses.add('${vm['pid']}:${vm['startTime']}')) {
          throw StateError(
            'Reused app process; first-opening measurement is not cold',
          );
        }
        entry['process'] = {
          'pid': vm['pid'],
          'start_time': vm['startTime'],
          'isolate': isolate,
          'mode': mode,
        };
        if (options.trace || options.profileOpening) {
          await rpc(base!, 'setVMTimelineFlags', {
            'recordedStreams': '[Dart,Embedder,GC]',
          });
        }
      }
      if (isolate != null) {
        Json result;
        try {
          result = await rpc(base!, 'ext.puck.performance', {
            'isolateId': isolate,
          });
        } on StateError catch (error) {
          // Service discovery can precede main registering its extension.
          if (error.toString().contains('Method not found') ||
              error.toString().contains('Unknown service')) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            continue;
          }
          rethrow;
        }
        final current = '${result['current']}:${result['completed']}';
        if (current != progress) {
          stdout.writeln(
            '    ${result['current'] ?? 'between scenarios'} (${result['completed']} recorded)',
          );
          progress = current;
        }
        if (options.trace && (result['completed'] as int? ?? 0) > traceCount) {
          traceCount = result['completed'] as int;
          (entry['traces'] as List<Json>).add({
            'completed_scenarios': traceCount,
            'timeline': await rpc(base!, 'getVMTimeline'),
          });
          await rpc(base!, 'clearVMTimeline');
        }
        if (result['done'] == true) {
          final report = result['report'] as Json;
          report['launch'] = {
            'pid': vm!['pid'],
            'vm_start_time': vm['startTime'],
            'isolate_id': isolate,
            'fresh_process_verified': true,
          };
          entry['report'] = report;
          if (options.profileOpening) {
            entry['timeline_flags'] = await rpc(base!, 'getVMTimelineFlags');
            entry['opening_timeline'] = await rpc(base!, 'getVMTimeline');
            entry['cpu_profiles'] = <Json>[];
            for (final phase in (report['scenarios'] as List).cast<Json>()) {
              final start = phase['start_us'] as int;
              final end = phase['end_us'] as int;
              final cpu = await rpc(base!, 'getCpuSamples', {
                'isolateId': isolate,
                'timeOriginMicros': '$start',
                'timeExtentMicros': '${end - start}',
              });
              (entry['cpu_profiles'] as List<Json>).add({
                'phase': phase['name'],
                'repetition': phase['repetition'],
                'start_us': start,
                'end_us': end,
                'data': compactCpuSamples(cpu),
              });
            }
          }
          validateReport(
            report,
            variant,
            options.repeats,
            openingOnly: options.profileOpening,
          );
          if (report['mode'] != mode) {
            throw StateError('App build mode differs from requested mode');
          }
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw TimeoutException(
      'Case exceeded ${options.timeoutSeconds}s; see this launch’s flutter_log',
    );
  } finally {
    try {
      await stopProcess(process);
    } finally {
      try {
        await readers;
      } finally {
        entry['flutter_log'] = log.toString();
      }
    }
  }
}

double median(Iterable<num> input) {
  final values = input.map((n) => n.toDouble()).toList()..sort();
  final middle = values.length ~/ 2;
  return values.length.isOdd
      ? values[middle]
      : (values[middle - 1] + values[middle]) / 2;
}

Json summarizeRun(List<Json> cases) {
  final flat = <Json>[];
  for (final entry in cases.where((entry) => !entry.containsKey('error'))) {
    for (final sample
        in (entry['report']?['scenarios'] as List? ?? []).cast<Json>()) {
      final metrics = sample['metrics'] as Json;
      final markers = sample['milestones_ms'] as Json;
      flat.add({
        'variant': entry['variant'],
        'launch': entry['launch'],
        'scenario': sample['name'],
        'repetition': sample['repetition'],
        'duration_ms': sample['duration_ms'],
        'response_ms':
            markers['first_content_emergence'] ??
            markers['first_item_emergence'] ??
            markers['fully_covered'] ??
            markers['first_root_motion'],
        'settled_ms': markers['settled'],
        'frame_count': metrics['frame_count'],
        'jank_percent': metrics['over_budget_percent'],
        'ui_p95_ms': metrics['ui']['p95_ms'],
        'ui_max_ms': metrics['ui']['max_ms'],
        'raster_p95_ms': metrics['raster']['p95_ms'],
        'raster_max_ms': metrics['raster']['max_ms'],
      });
    }
  }
  final rows = <String>[];
  for (final variant in variants) {
    for (final scenario in scenarios) {
      final samples = flat
          .where((s) => s['variant'] == variant && s['scenario'] == scenario)
          .toList();
      if (samples.isEmpty) continue;
      final responses = samples.map((s) => s['response_ms']).whereType<num>();
      final response = responses.isEmpty
          ? '—'
          : median(responses).toStringAsFixed(1);
      final jank = median(samples.map((s) => s['jank_percent'] as num))
          .toStringAsFixed(1);
      final ui = samples
          .map((s) => s['ui_max_ms'] as num)
          .reduce(math.max)
          .toStringAsFixed(1);
      final raster = samples
          .map((s) => s['raster_max_ms'] as num)
          .reduce(math.max)
          .toStringAsFixed(1);
      rows.add(
        '| $variant | $scenario | ${samples.length} | $response | $jank% | $ui | $raster |',
      );
    }
  }
  final failed = cases.where((c) => c.containsKey('error')).toList();
  final modes =
      cases
          .where((c) => c.containsKey('report'))
          .map((c) => c['report']['mode'] as String? ?? 'unknown')
          .toSet()
          .toList()
        ..sort();
  final modeNote =
      'Build mode: ${modes.isEmpty ? 'no successful launches' : modes.join(', ')}. '
      '${modes.contains('debug') ? 'Debug includes JIT/assertion overhead; use a physical device in profile mode for performance decisions.' : ''}';
  final markdown =
      '# Floating-menu performance results\n\n$modeNote\n\n'
      'Each launch is a fresh verified VM process. First-open samples never follow an automatic warm-up open. '
      'Jank means engine UI or raster work over the configured frame budget; it is not a measured display drop count.\n\n'
      '| Variant | Scenario | Samples | Median response (ms) | Median over-budget frames | Worst UI (ms) | Worst raster (ms) |\n'
      '|---|---|---:|---:|---:|---:|---:|\n${rows.join('\n')}\n\n'
      'Failed launches: ${failed.length}\n'
      '${failed.map((c) => '- ${c['variant']} launch ${c['launch']}: ${c['error']}').join('\n')}\n';
  return {'markdown': markdown, 'samples': flat};
}

Future<int> runSuite(RunnerOptions options, Directory example) async {
  final device = await resolveDevice(options, example);
  final mode = selectMode(options.mode, device);
  if (options.dryRun) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'mode': mode,
        'commands': [
          for (final v in options.selectedVariants)
            launchCommand(options, v, mode, device['id'] as String),
        ],
      }),
    );
    return 0;
  }
  final timestamp = DateTime.now().toUtc().toIso8601String();
  final directoryName = timestamp.replaceAll(RegExp('[-:.]'), '');
  final output = File(
    options.output ??
        '${example.path}/build/performance_runs/$directoryName.json',
  ).absolute;
  if (await FileSystemEntity.type(output.path) !=
      FileSystemEntityType.notFound) {
    throw StateError('Output already exists: ${output.path}');
  }
  await output.parent.create(recursive: true);
  final cases = <Json>[];
  final seen = <String>{};
  var interrupted = false;
  final signal = ProcessSignal.sigint.watch().listen((_) {
    interrupted = true;
  });
  final result = <String, dynamic>{
    'schema_version': 2,
    'status': 'running',
    'started_utc': timestamp,
    'device': device,
    'mode': mode,
    'parameters': options.toJson(),
    'cases': cases,
  };
  Future<void> checkpoint() async {
    result['summary'] = summarizeRun(cases);
    await writeJson(output, result);
  }

  stdout.writeln(
    'Mode: $mode; device: ${device['name']}; results: ${output.path}',
  );
  try {
    await checkpoint();
    for (final variant in options.selectedVariants) {
      for (
        var launch = 1;
        launch <= options.coldRuns && !interrupted;
        launch++
      ) {
        stdout.writeln('[$variant] fresh launch $launch/${options.coldRuns}');
        final entry = <String, dynamic>{'variant': variant, 'launch': launch};
        cases.add(entry);
        try {
          await runCase(
            options,
            variant,
            mode,
            device,
            example,
            entry,
            seen,
            interrupted: () => interrupted,
          );
        } catch (error) {
          entry['error'] = error.toString();
          stdout.writeln('    FAILED: $error');
        }
        await checkpoint();
      }
      if (interrupted) break;
    }
  } finally {
    await signal.cancel();
    result['status'] = interrupted
        ? 'interrupted'
        : cases.any((c) => c.containsKey('error'))
        ? 'failed'
        : 'complete';
    result['finished_utc'] = DateTime.now().toUtc().toIso8601String();
    await checkpoint();
  }
  if (result['status'] == 'complete' && !options.profileOpening) {
    final asset = File('${example.path}/$performanceResultsAsset');
    await published.publishPerformanceRun(output, asset);
    stdout.writeln('Published app asset: ${asset.path}');
  }
  stdout.writeln('Results: ${output.path}');
  stdout.writeln(
    'Review: dart run tool/performance/review.dart --device ${device['id']} --results "${output.path}"',
  );
  return interrupted
      ? 130
      : cases.any((c) => c.containsKey('error'))
      ? 1
      : 0;
}

Future<void> main(List<String> arguments) async {
  try {
    final options = RunnerOptions(arguments);
    if (options.showHelp) {
      stdout.write(help);
      return;
    }
    // Resolve relative to this script, so launching from another cwd also works.
    final example = Directory.fromUri(Platform.script.resolve('../../'));
    exitCode = await runSuite(options, example);
  } catch (error) {
    stderr.writeln('Error: $error');
    exitCode = 2;
  }
}
