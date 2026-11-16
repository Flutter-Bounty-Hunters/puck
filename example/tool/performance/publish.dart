// Publish a saved benchmark into the asset shared by both performance UIs.
import 'dart:convert';
import 'dart:io';

import 'package:puck_example/performance/performance_asset.dart';
import 'package:puck_example/performance/results_files.dart';

bool publishablePerformanceRun(Map<String, dynamic> data) =>
    data['schema_version'] == 2 &&
    data['status'] == 'complete' &&
    data['mode'] == 'profile' &&
    data['parameters'] is Map &&
    data['parameters']['profile_opening'] != true &&
    data['cases'] is List &&
    (data['cases'] as List).isNotEmpty &&
    (data['cases'] as List).every(
      (entry) =>
          entry is Map &&
          !entry.containsKey('error') &&
          entry['report'] is Map &&
          entry['report']['success'] == true &&
          entry['report']['mode'] == 'profile',
    );

Future<File?> latestPublishablePerformanceRun(Directory directory) async {
  if (!await directory.exists()) return null;
  final candidates = <(File, DateTime)>[];
  await for (final entry in directory.list()) {
    if (entry is! File || !entry.path.endsWith('.json')) continue;
    final handle = await entry.open();
    late String header;
    try {
      header = utf8.decode(await handle.read(4096), allowMalformed: true);
    } finally {
      await handle.close();
    }
    if (!RegExp(r'"schema_version"\s*:\s*2\b').hasMatch(header) ||
        !RegExp(r'"status"\s*:\s*"complete"').hasMatch(header) ||
        !RegExp(r'"mode"\s*:\s*"profile"').hasMatch(header) ||
        RegExp(r'"profile_opening"\s*:\s*true').hasMatch(header)) {
      continue;
    }
    final started = RegExp(r'"started_utc"\s*:\s*"([^"]+)"')
        .firstMatch(header)
        ?.group(1);
    candidates.add((
      entry,
      parsePerformanceTimestamp(started) ?? (await entry.stat()).modified,
    ));
  }
  candidates.sort((a, b) => b.$2.compareTo(a.$2));
  for (final (file, _) in candidates) {
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (publishablePerformanceRun(data)) return file;
  }
  return null;
}

Future<void> publishPerformanceRun(File source, File asset) async {
  final data = jsonDecode(await source.readAsString()) as Map<String, dynamic>;
  if (!publishablePerformanceRun(data)) {
    throw const FormatException(
      'Only complete, successful profile benchmark runs can be published.',
    );
  }
  compactPerformanceRun(data);
  data['publication'] = {
    'source_file': source.uri.pathSegments.last,
    'published_utc': DateTime.now().toUtc().toIso8601String(),
  };
  await asset.parent.create(recursive: true);
  final pending = File('${asset.path}.$pid.tmp');
  try {
    await pending.writeAsString('${jsonEncode(data)}\n', flush: true);
    await pending.rename(asset.path);
  } finally {
    if (await pending.exists()) await pending.delete();
  }
}

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length > 1) {
      throw const FormatException(
        'Expected zero or one results file/directory.',
      );
    }
    if (arguments.contains('--help')) {
      stdout.writeln(
        'dart run tool/performance/publish.dart [results-file-or-directory]',
      );
      return;
    }
    final example = Directory.fromUri(Platform.script.resolve('../../'));
    final path = arguments.isEmpty
        ? '${example.path}/build/performance_runs'
        : arguments.single;
    final source =
        await FileSystemEntity.type(path) == FileSystemEntityType.file
        ? File(path)
        : await latestPublishablePerformanceRun(Directory(path));
    if (source == null) {
      throw StateError('No complete profile benchmark results found in $path.');
    }
    final asset = File('${example.path}/$performanceResultsAsset');
    await publishPerformanceRun(source, asset);
    stdout.writeln(
      'Published ${source.path} to ${asset.path} (${await asset.length()} bytes).',
    );
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
