import 'dart:convert';
import 'dart:io';

DateTime? parsePerformanceTimestamp(String? value) {
  if (value == null) return null;
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;
  // Early runs used a compact timestamp with no fractional-second separator.
  final legacy = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(\d{6})Z$',
  ).firstMatch(value);
  if (legacy == null) return null;
  return DateTime.tryParse(
    '${legacy[1]}-${legacy[2]}-${legacy[3]}T${legacy[4]}:${legacy[5]}:${legacy[6]}.${legacy[7]}Z',
  );
}

/// Uses the run's start time, so copying/consolidating an old result does not
/// make it newer than a more recent measurement. Legacy folders are ignored.
Future<File?> latestPerformanceFile(Directory directory) async {
  if (!await directory.exists()) return null;
  final candidates = <(File, DateTime)>[];
  await for (final entity in directory.list()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    try {
      final handle = await entity.open();
      late String prefix;
      try {
        prefix = utf8.decode(await handle.read(4096), allowMalformed: true);
      } finally {
        await handle.close();
      }
      if (!RegExp(r'"schema_version"\s*:\s*2\b').hasMatch(prefix)) continue;
      // Focused profiler captures omit drag scenarios and often most variants.
      // Keep the dashboard on benchmark runs; diagnostics remain reviewable
      // through the launcher's explicit --results <file> option.
      if (RegExp(r'"profile_opening"\s*:\s*true\b').hasMatch(prefix)) {
        continue;
      }
      final started = RegExp(r'"started_utc"\s*:\s*"([^"]+)"')
          .firstMatch(prefix)
          ?.group(1);
      candidates.add((
        entity,
        parsePerformanceTimestamp(started) ?? (await entity.stat()).modified,
      ));
    } on FileSystemException {
      continue;
    }
  }
  candidates.sort((a, b) => b.$2.compareTo(a.$2));
  return candidates.isEmpty ? null : candidates.first.$1;
}
