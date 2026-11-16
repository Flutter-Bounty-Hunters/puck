import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'results_files.dart';
import 'performance_asset.dart';

export 'performance_asset.dart' show performanceResultsAsset;

const resultsUrl = String.fromEnvironment('PUCK_PERFORMANCE_RESULTS_URL');
const scenarioLabels = {
  'first_open': 'First opening',
  'repeat_close': 'Repeated closing',
  'repeat_open': 'Repeated opening',
  'closed_pull': 'Closed · pull from wall',
  'closed_rapid_drag': 'Closed · rapid drag',
  'closed_release': 'Closed · release to wall',
  'open_pull': 'Open · pull from wall',
  'open_rapid_drag': 'Open · rapid drag',
  'open_release': 'Open · release to wall',
};
String variantLabel(String id) => id
    .replaceAll('three_level', '3 levels')
    .replaceAll('single', '1 level')
    .replaceAll('_', ' · ')
    .replaceFirstMapped(RegExp(r'^.'), (match) => match[0]!.toUpperCase());

double? number(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;
double? medianValue(Iterable<double> input) {
  final values = input.toList()..sort();
  if (values.isEmpty) return null;
  final middle = values.length ~/ 2;
  return values.length.isOdd
      ? values[middle]
      : (values[middle - 1] + values[middle]) / 2;
}

class PerformanceRun {
  PerformanceRun(this.data) {
    if (data['schema_version'] != 2 || data['cases'] is! List) {
      throw const FormatException(
        'This file is not a consolidated performance run (version 2).',
      );
    }
    launches = [
      for (final entry in data['cases'] as List)
        PerformanceLaunch(Map<String, dynamic>.from(entry as Map)),
    ];
  }
  final Map<String, dynamic> data;
  late final List<PerformanceLaunch> launches;
  String get status => data['status'] as String? ?? 'unknown';
  String get mode => data['mode'] as String? ?? 'unknown';
  String get device => data['device']?['name'] as String? ?? 'Unknown device';
  DateTime? get started =>
      parsePerformanceTimestamp(data['started_utc'] as String?);
  double get budgetFps =>
      number(data['parameters']?['budget_fps']) ??
      (launches.isEmpty
          ? null
          : number(
              launches.first.data['report']?['config']?['frame_budget_fps'],
            )) ??
      60;
  List<PerformanceSample> get samples => [
    for (final launch in launches.where((l) => l.success)) ...launch.samples,
  ];
  int get failedLaunches => launches.where((l) => !l.success).length;

  List<String> get variants => launches.map((l) => l.variant).toSet().toList();

  PerformanceProfile profile({String? variant, String? scenario}) =>
      PerformanceProfile.fromSamples(
        samples.where(
          (sample) =>
              (variant == null || sample.variant == variant) &&
              (scenario == null || sample.name == scenario),
        ),
      );

  /// Group only successful launches. Material and level counts are intentional
  /// experiment variables; viewport, renderer, input policy and mode are not.
  Map<String, List<PerformanceLaunch>> get setupGroups {
    final groups = <String, List<PerformanceLaunch>>{};
    for (final launch in launches.where((l) => l.success)) {
      final report = launch.data['report'] as Map;
      final config = report['config'] as Map? ?? {};
      final signature = jsonEncode(
        _canonicalJson({
          'device': data['device']?['id'] ?? device,
          'mode': report['mode'] ?? mode,
          'platform': report['platform'] ?? data['device']?['targetPlatform'],
          'viewport': report['viewport'],
          'display_refresh_rate_hz': report['display_refresh_rate_hz'],
          'native_shader_filters_supported':
              report['native_shader_filters_supported'],
          'interaction_readiness':
              report['interaction_readiness'] ?? 'legacy_unchecked',
          // Older fixtures shared a layer per level. Do not pool their frame
          // timings with current independent-puck rendering measurements.
          'glass_layer_policy':
              (config['glass_layer_policy'] as String? ?? 'per_level')
                  .replaceAll('per_tier', 'per_level'),
          'prepare_glass':
              config['prepare_glass'] ??
              (data['parameters']?['no_prepare'] is bool
                  ? !(data['parameters']['no_prepare'] as bool)
                  : null),
          for (final key in ['curves', 'start_delay_ms', 'repeats'])
            key: config[key] ?? data['parameters']?[key],
          // Preserve comparability of previously saved reports without
          // mixing their old mounted-item policy with current measurements.
          'closed_item_policy':
              config['closed_item_policy'] ??
              switch (config['maintain_menu_state']) {
                true => 'legacy_mounted',
                false => 'dispose',
                _ => null,
              },
        }),
      );
      groups.putIfAbsent(signature, () => []).add(launch);
    }
    return groups;
  }

  bool get comparableSetup => setupGroups.length <= 1;

  List<PerformanceSetupGroup> get comparisonSetups => [
    for (final entry in setupGroups.entries)
      PerformanceSetupGroup(entry.key, entry.value),
  ];
}

class PerformanceSetupGroup {
  const PerformanceSetupGroup(this.id, this.launches);
  final String id;
  final List<PerformanceLaunch> launches;
  Map<String, dynamic> get configuration =>
      jsonDecode(id) as Map<String, dynamic>;
  List<PerformanceSample> get samples => [
    for (final launch in launches) ...launch.samples,
  ];
  bool get hasKnownSetup {
    final setup = configuration;
    final viewport = setup['viewport'] as Map?;
    return viewport != null &&
        number(viewport['width']) != null &&
        number(viewport['height']) != null &&
        number(setup['display_refresh_rate_hz']) != null &&
        ['debug', 'profile', 'release'].contains(setup['mode']) &&
        setup['platform'] != null &&
        setup['native_shader_filters_supported'] is bool &&
        ['prepare_glass', 'curves'].every((key) => setup[key] is bool) &&
        setup['closed_item_policy'] is String &&
        [
          'start_delay_ms',
          'repeats',
        ].every((key) => number(setup[key]) != null);
  }

  String get label {
    final setup = configuration;
    final viewport = setup['viewport'] as Map?;
    final size = viewport == null
        ? 'Unknown viewport'
        : '${viewport['width']} × ${viewport['height']}';
    final hz = setup['display_refresh_rate_hz'];
    final prep = setup['prepare_glass'];
    final glass = setup['glass_layer_policy'] == 'individual_pucks'
        ? 'individual glass layers'
        : 'per-level glass layers';
    return '$size · ${hz == null ? 'unknown Hz' : '$hz Hz'} · ${setup['mode']} · '
        '$glass${prep == true ? ' · prepared' : ''}';
  }
}

Object? _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonicalJson(value[key])};
  }
  if (value is List) return value.map(_canonicalJson).toList();
  return value;
}

class PerformanceLaunch {
  PerformanceLaunch(this.data);
  final Map<String, dynamic> data;
  // Normalize names from reports saved before the level terminology rename.
  String get variant => (data['variant'] as String? ?? 'unknown').replaceAll(
    'three_tier',
    'three_level',
  );
  int get launch => (data['launch'] as num?)?.toInt() ?? 1;
  bool get success =>
      !data.containsKey('error') && data['report']?['success'] == true;
  String? get error =>
      data['error']?.toString() ??
      (success
          ? null
          : data['report']?['errors']?.toString() ?? 'No completed report');
  bool get glassFallback =>
      variant.startsWith('glass_') &&
      data['report']?['native_shader_filters_supported'] == false;
  List<PerformanceSample> get samples => [
    for (final sample in data['report']?['scenarios'] as List? ?? [])
      if (sample is Map && sample['metrics'] is Map)
        PerformanceSample(Map<String, dynamic>.from(sample), variant, launch),
  ];
}

class PerformanceSample {
  PerformanceSample(this.data, this.variant, this.launch);
  final Map<String, dynamic> data;
  final String variant;
  final int launch;
  String get name => data['name'] as String? ?? 'unknown';
  String get label => scenarioLabels[name] ?? name;
  int get repetition => (data['repetition'] as num?)?.toInt() ?? 1;
  double? get response =>
      number(data['milestones_ms']?['first_content_emergence']) ??
      number(data['milestones_ms']?['first_item_emergence']) ??
      number(data['milestones_ms']?['fully_covered']) ??
      number(data['milestones_ms']?['first_root_motion']);
  double? get settled => number(data['milestones_ms']?['settled']);
  Map<String, dynamic> get metrics => data['metrics'] as Map<String, dynamic>;
  int get frameCount => (metrics['frame_count'] as num?)?.toInt() ?? 0;
  double? get jank => number(metrics['over_budget_percent']);
  double? get uiP95 => number(metrics['ui']?['p95_ms']);
  double? get rasterP95 => number(metrics['raster']?['p95_ms']);
  double? get uiMax => number(metrics['ui']?['max_ms']);
  double? get rasterMax => number(metrics['raster']?['max_ms']);
  double get budgetMs => number(metrics['frame_budget_ms']) ?? 1000 / 60;
  List<Map<String, dynamic>> get frames =>
      (data['frames'] as List? ?? []).cast<Map<String, dynamic>>();
}

/// One engine frame. UI and raster work overlap in the pipeline, so the work
/// budget is their maximum rather than their sum or queued total latency.
class FrameWork {
  const FrameWork(this.uiMs, this.rasterMs);
  final double uiMs;
  final double rasterMs;
  double get workMs => math.max(uiMs, rasterMs);
}

/// A budget evaluation over all samples. Unknown frames are explicit: a saved
/// 60Hz percentage cannot tell us how many frames missed the 120Hz budget.
class FrameBudgetProfile {
  const FrameBudgetProfile({
    required this.fps,
    required this.overBudgetFrames,
    required this.coveredFrameCount,
    required this.unknownFrameCount,
    this.unknownMeasurementCount = 0,
  });
  final int fps;
  final int overBudgetFrames;
  final int coveredFrameCount;
  final int unknownFrameCount;
  final int unknownMeasurementCount;
  double get budgetMs => 1000 / fps;
  double? get overBudgetPercent =>
      unknownFrameCount > 0 ||
          unknownMeasurementCount > 0 ||
          coveredFrameCount == 0
      ? null
      : overBudgetFrames * 100 / coveredFrameCount;
  double? get withinBudgetPercent =>
      overBudgetPercent == null ? null : 100 - overBudgetPercent!;
}

/// Pooled frame distributions, with response/settling medians across windows.
/// Missing measurements remain null; they are never represented as zero work.
class PerformanceProfile {
  PerformanceProfile.fromSamples(Iterable<PerformanceSample> input)
    : samples = List.unmodifiable(input) {
    for (final sample in samples) {
      final valid = <FrameWork>[];
      for (final frame in sample.frames) {
        final ui = number(frame['build_us']);
        final raster = number(frame['raster_us']);
        if (ui != null && raster != null && ui >= 0 && raster >= 0) {
          valid.add(FrameWork(ui / 1000, raster / 1000));
        }
      }
      _sampleFrames.add(valid);
      frames.addAll(valid);
    }
  }

  final List<PerformanceSample> samples;
  final frames = <FrameWork>[];
  final _sampleFrames = <List<FrameWork>>[];
  int get measurementCount => samples.length;
  int get frameCount => List.generate(
    samples.length,
    (i) => math.max(samples[i].frameCount, _sampleFrames[i].length),
  ).fold(0, (a, b) => a + b);
  int get rawFrameCount => frames.length;
  bool get hasCompleteRawFrames =>
      frameCount > 0 &&
      List.generate(
        samples.length,
        (i) =>
            _sampleFrames[i].isNotEmpty &&
            _sampleFrames[i].length ==
                math.max(samples[i].frameCount, _sampleFrames[i].length),
      ).every((valid) => valid);
  bool get usesAggregateFallback => frames.isEmpty && samples.isNotEmpty;
  double? get responseMs =>
      medianValue(samples.map((s) => s.response).whereType<double>());
  double? get slideStartMs => medianValue(
    samples
        .map((s) => number(s.data['milestones_ms']?['first_item_motion']))
        .whereType<double>(),
  );
  double? get settledMs =>
      medianValue(samples.map((s) => s.settled).whereType<double>());
  double? get uiP95Ms => frames.isEmpty
      ? medianValue(samples.map((s) => s.uiP95).whereType<double>())
      : percentile(frames.map((f) => f.uiMs), .95);
  double? get rasterP95Ms => frames.isEmpty
      ? medianValue(samples.map((s) => s.rasterP95).whereType<double>())
      : percentile(frames.map((f) => f.rasterMs), .95);
  double? get workP50Ms => percentile(frames.map((f) => f.workMs), .5);
  double? get workP95Ms => percentile(frames.map((f) => f.workMs), .95);
  double? get workP99Ms => percentile(frames.map((f) => f.workMs), .99);
  double? get worstWorkMs {
    final recorded = <double>[];
    for (var i = 0; i < samples.length; i++) {
      if (_sampleFrames[i].isEmpty ||
          _sampleFrames[i].length < samples[i].frameCount) {
        recorded.addAll(
          [samples[i].uiMax, samples[i].rasterMax].whereType<double>(),
        );
      }
    }
    final values = [...frames.map((f) => f.workMs), ...recorded];
    return values.isEmpty ? null : values.reduce(math.max);
  }

  FrameBudgetProfile budget(int fps) {
    if (fps <= 0) throw ArgumentError.value(fps, 'fps', 'Must be positive');
    final limitUs = 1000000 / fps;
    var over = 0;
    var covered = 0;
    var unknown = 0;
    var unknownMeasurements = 0;
    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final raw = _sampleFrames[i];
      final count = math.max(sample.frameCount, raw.length);
      if (count == 0) unknownMeasurements++;
      if (raw.isNotEmpty && raw.length == count) {
        // Compare microseconds to avoid turning an exact threshold into an
        // overrun through floating-point round trips to milliseconds.
        over += raw.where((f) => f.workMs * 1000 > limitUs).length;
        covered += count;
      } else {
        final recordedBudget = number(sample.metrics['frame_budget_ms']);
        final recordedOver = number(sample.metrics['over_budget_frames']);
        if (recordedBudget != null &&
            (recordedBudget - 1000 / fps).abs() < .001 &&
            recordedOver != null &&
            recordedOver >= 0 &&
            recordedOver <= count) {
          over += recordedOver.toInt();
          covered += count;
        } else {
          // A partial raw capture still tells us about those individual
          // frames, but cannot establish the rate for the whole window.
          over += raw.where((f) => f.workMs * 1000 > limitUs).length;
          covered += raw.length;
          unknown += count - raw.length;
        }
      }
    }
    return FrameBudgetProfile(
      fps: fps,
      overBudgetFrames: over,
      coveredFrameCount: covered,
      unknownFrameCount: unknown,
      unknownMeasurementCount: unknownMeasurements,
    );
  }
}

double? percentile(Iterable<double> input, double percentile) {
  final sorted = input.toList()..sort();
  if (sorted.isEmpty) return null;
  return sorted[((sorted.length - 1) * percentile).ceil()];
}

PerformanceRun parsePerformanceRun(String source) => PerformanceRun(
  compactPerformanceRun(jsonDecode(source) as Map<String, dynamic>),
);

/// The same published measurement snapshot is bundled in both app entry points.
Future<PerformanceRun> loadBundledPerformanceRun({AssetBundle? bundle}) async {
  final source = await (bundle ?? rootBundle).loadString(
    performanceResultsAsset,
    cache: false,
  );
  return compute(parsePerformanceRun, source);
}

Future<PerformanceRun?> loadLatestPerformanceRun() async {
  if (resultsUrl.isNotEmpty) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(resultsUrl));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode == HttpStatus.noContent) return null;
      if (response.statusCode != HttpStatus.ok) {
        throw const HttpException('The latest results could not be read.');
      }
      final source = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 30));
      return await compute(parsePerformanceRun, source);
    } finally {
      client.close(force: true);
    }
  }
  return loadBundledPerformanceRun();
}
