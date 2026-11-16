const performanceResultsAsset = 'assets/performance/results/latest.json';

/// Keep measurements, frame samples, setup, and logs; large diagnostic traces
/// stay in the original report. Counts survive repeated compacting/parsing.
Map<String, dynamic> compactPerformanceRun(Map<String, dynamic> data) {
  for (final entry in data['cases'] as List? ?? []) {
    if (entry is! Map) continue;
    entry['trace_count'] =
        (entry.remove('traces') as List?)?.length ?? entry['trace_count'] ?? 0;
    entry['opening_timeline_event_count'] =
        (entry.remove('opening_timeline') as Map?)?['traceEvents']?.length ??
        entry['opening_timeline_event_count'] ??
        0;
    entry['cpu_profile_count'] =
        (entry.remove('cpu_profiles') as List?)?.length ??
        entry['cpu_profile_count'] ??
        0;
  }
  data.remove('summary');
  return data;
}
