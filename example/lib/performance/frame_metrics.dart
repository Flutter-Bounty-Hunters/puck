import 'dart:math' as math;

/// Pure aggregation; raw engine timestamps remain in the report for auditing.
Map<String, Object?> summarizeFrames(
  List<Map<String, int>> frames,
  double budgetFps,
) {
  final budget = 1000000 / budgetFps;
  Map<String, double> distribution(Iterable<int> input) {
    final values = input.toList()..sort();
    double percentile(double p) => values.isEmpty
        ? 0
        : values[((values.length - 1) * p).ceil()].toDouble() / 1000;
    return {
      'mean_ms': values.isEmpty
          ? 0
          : values.reduce((a, b) => a + b) / values.length / 1000,
      'p50_ms': percentile(.5),
      'p90_ms': percentile(.9),
      'p95_ms': percentile(.95),
      'p99_ms': percentile(.99),
      'max_ms': percentile(1),
    };
  }

  final uiOver = frames.where((f) => f['build_us']! > budget).length;
  final rasterOver = frames.where((f) => f['raster_us']! > budget).length;
  final over = frames
      .where((f) => math.max(f['build_us']!, f['raster_us']!) > budget)
      .length;
  return {
    'frame_count': frames.length,
    'frame_budget_ms': budget / 1000,
    'ui_over_budget_frames': uiOver,
    'raster_over_budget_frames': rasterOver,
    'over_budget_frames': over,
    'over_budget_percent': frames.isEmpty ? 0.0 : over * 100 / frames.length,
    'estimated_missed_refresh_intervals': frames.fold<int>(
      0,
      (sum, f) =>
          sum +
          math.max(
            0,
            (math.max(f['build_us']!, f['raster_us']!) / budget).ceil() - 1,
          ),
    ),
    'ui': distribution(frames.map((f) => f['build_us']!)),
    'raster': distribution(frames.map((f) => f['raster_us']!)),
    'pipeline_total': distribution(frames.map((f) => f['total_us']!)),
    'note':
        'Over-budget work is a jank indicator, not a hardware presentation/drop counter. '
        'Pipeline total includes queueing and is not used as the work budget.',
  };
}
