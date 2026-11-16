import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import 'runtime_memory.dart';

@immutable
class PerformanceReading {
  const PerformanceReading({
    required this.id,
    required this.label,
    required this.name,
    required this.unit,
    required this.value,
    required this.budget,
    required this.detail,
  });

  final String id;
  final String label;
  final String name;
  final String unit;
  final double? value;
  final double budget;
  final String detail;

  /// Remaining headroom against the stated reference, not an OS health score.
  double? get health => value == null || budget <= 0
      ? null
      : (1 - value! / budget).clamp(0.0, 1.0);

  String get formatted => value == null
      ? '—'
      : '${value!.toStringAsFixed(value! >= 100 ? 0 : 1)} $unit';
}

/// Bounded frame collection with low-frequency publication. Listening to frame
/// timings does not request new frames or keep the app rendering while idle.
class RuntimePerformanceMonitor extends ChangeNotifier {
  RuntimePerformanceMonitor({int? Function()? readMemory})
    : _readMemory = readMemory ?? processMemoryBytes;

  final int? Function() _readMemory;
  final _frames = ListQueue<FrameTiming>();
  Timer? _timer;
  double refreshRate = 60;
  List<PerformanceReading> readings = const [];
  bool get isRunning => _timer != null;
  int get frameCount => _frames.length;
  double get frameBudgetMs => 1000 / (refreshRate > 0 ? refreshRate : 60);

  void start() {
    if (isRunning) return;
    _frames.clear();
    SchedulerBinding.instance.addTimingsCallback(recordFrames);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => sample());
    sample();
  }

  void stop() {
    if (!isRunning) return;
    SchedulerBinding.instance.removeTimingsCallback(recordFrames);
    _timer!.cancel();
    _timer = null;
  }

  void recordFrames(List<FrameTiming> frames) {
    for (final frame in frames) {
      _frames.addLast(frame);
      if (_frames.length > 120) _frames.removeFirst();
    }
  }

  void sample() {
    double? percentile(Duration Function(FrameTiming) read) {
      if (_frames.isEmpty) return null;
      final values = _frames.map((f) => read(f).inMicroseconds).toList()
        ..sort();
      return values[((values.length - 1) * 0.95).ceil()] / 1000;
    }

    final frameBudget = frameBudgetMs;
    final timingDetail =
        '95th percentile of the last ${_frames.length} measured frames. '
        'Reference: ${frameBudget.toStringAsFixed(2)} ms at '
        '${refreshRate.toStringAsFixed(0)} Hz.';
    PerformanceReading timing(
      String id,
      String label,
      String name,
      Duration Function(FrameTiming) read,
    ) => PerformanceReading(
      id: id,
      label: label,
      name: name,
      unit: 'ms',
      value: percentile(read),
      budget: frameBudget,
      detail: timingDetail,
    );
    final memory = _readMemory();
    final images = PaintingBinding.instance.imageCache;
    readings = [
      timing('ui', 'UI', 'UI frame time', (f) => f.buildDuration),
      timing('raster', 'Raster', 'Raster frame time', (f) => f.rasterDuration),
      timing(
        'latency',
        'Latency',
        'Frame pipeline latency',
        (f) => f.totalSpan,
      ),
      timing('vsync', 'Vsync', 'Vsync delay', (f) => f.vsyncOverhead),
      PerformanceReading(
        id: 'jank',
        label: 'Jank',
        name: 'Over-budget frames',
        unit: '%',
        value: _frames.isEmpty
            ? null
            : _frames
                      .where(
                        (f) =>
                            math.max(
                              f.buildDuration.inMicroseconds,
                              f.rasterDuration.inMicroseconds,
                            ) >
                            frameBudget * 1000,
                      )
                      .length *
                  100 /
                  _frames.length,
        budget: 10,
        detail:
            'Last ${_frames.length} measured frames; 10% is the red reference. '
            'An indicator of jank, not a hardware dropped-frame counter.',
      ),
      PerformanceReading(
        id: 'memory',
        label: 'RAM',
        name: 'Process memory',
        unit: 'MB',
        value: memory == null ? null : memory / (1024 * 1024),
        budget: 512,
        detail: memory == null
            ? 'Process memory is unavailable on this platform.'
            : 'Resident process memory. Headroom uses an illustrative 512 MB '
                  'reference, not the device or OS memory limit.',
      ),
      PerformanceReading(
        id: 'images',
        label: 'Images',
        name: 'Image cache',
        unit: 'MB',
        value: images.currentSizeBytes / (1024 * 1024),
        budget: images.maximumSizeBytes / (1024 * 1024),
        detail:
            'Cached image bytes against the configured cache capacity. '
            'This is cache headroom, not all image or GPU memory.',
      ),
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
