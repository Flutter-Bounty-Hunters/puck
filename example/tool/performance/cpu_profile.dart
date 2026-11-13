/// Keep every captured stack, while dropping VM-wide symbols not referenced by
/// this time window. Stack indices are remapped into the smaller function table.
Map<String, dynamic> compactCpuSamples(Map<String, dynamic> source) {
  final functions = source['functions'] as List;
  final samples = (source['samples'] as List).cast<Map<String, dynamic>>();
  final used = <int>{
    for (final sample in samples) ...((sample['stack'] as List).cast<int>()),
  }.toList()..sort();
  final remap = {for (var i = 0; i < used.length; i++) used[i]: i};
  return {
    ...source,
    'functions': [for (final index in used) functions[index]],
    'samples': [
      for (final sample in samples)
        {
          ...sample,
          'stack': [for (final index in sample['stack'] as List) remap[index]!],
        },
    ],
    'unreferenced_symbols_removed':
        (source['unreferenced_symbols_removed'] as int? ?? 0) +
        functions.length -
        used.length,
  };
}
