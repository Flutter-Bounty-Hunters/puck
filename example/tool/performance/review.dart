// Opens the most recent consolidated run in the performance app.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:puck_example/performance/results_files.dart';

import 'run.dart' as benchmark;

Future<void> main(List<String> arguments) async {
  HttpServer? server;
  try {
    final remaining = <String>[];
    String? resultsPath;
    for (var i = 0; i < arguments.length; i++) {
      if (arguments[i] == '--results') {
        if (++i == arguments.length || arguments[i].startsWith('--')) {
          throw const FormatException('--results requires a file or directory');
        }
        resultsPath = arguments[i];
      } else if (arguments[i].startsWith('--results=')) {
        resultsPath = arguments[i].substring('--results='.length);
      } else {
        remaining.add(arguments[i]);
      }
    }
    final options = benchmark.RunnerOptions(remaining);
    if (options.showHelp) {
      stdout.writeln(
        'Open the latest saved performance run.\n'
        'dart run tool/performance/review.dart --device <id> [--results <file-or-directory>] [--flutter <path>]',
      );
      return;
    }
    final example = Directory.fromUri(Platform.script.resolve('../../'));
    final device = await benchmark.resolveDevice(options, example);
    final source = resultsPath ?? '${example.path}/build/performance_runs';
    final sourceIsFile =
        await FileSystemEntity.type(source) == FileSystemEntityType.file;
    final physical =
        device['emulator'] != true &&
        !['darwin', 'linux', 'windows'].contains(device['targetPlatform']);
    var host = '127.0.0.1';
    if (physical) {
      final addresses = [
        for (final interface in await NetworkInterface.list(
          type: InternetAddressType.IPv4,
        ))
          ...interface.addresses.where(
            (a) => !a.isLoopback && !a.address.startsWith('169.254.'),
          ),
      ];
      if (addresses.isEmpty) {
        throw StateError(
          'Connect the computer and device to the same local network.',
        );
      }
      host = addresses.first.address;
    } else if (device['targetPlatform'].toString().startsWith('android') &&
        device['emulator'] == true) {
      host = '10.0.2.2';
    }
    server = await HttpServer.bind(
      physical || host == '10.0.2.2'
          ? InternetAddress.anyIPv4
          : InternetAddress.loopbackIPv4,
      0,
    );
    final random = Random.secure();
    final token = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    server.listen((request) async {
      try {
        if (request.method != 'GET' || request.uri.path != '/$token/latest') {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          final file = sourceIsFile
              ? File(source)
              : await latestPerformanceFile(Directory(source));
          request.response.headers.set(
            HttpHeaders.cacheControlHeader,
            'no-store',
          );
          if (file == null) {
            request.response.statusCode = HttpStatus.noContent;
          } else {
            request.response.headers.contentType = ContentType.json;
            // Read a complete checkpoint before sending it, so an update cannot
            // truncate the HTTP response midway through a refresh.
            final bytes = await file.readAsBytes();
            request.response.add(bytes);
            stdout.writeln('Reviewing ${file.path}');
          }
        }
      } catch (error) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': error.toString()}));
      } finally {
        await request.response.close();
      }
    });
    final url = 'http://$host:${server.port}/$token/latest';
    stdout.writeln(
      'Opening results review. Keep this command running to refresh results.',
    );
    final process = await Process.start(
      options.flutter,
      [
        'run',
        '-d',
        device['id'] as String,
        '-t',
        'lib/performance/main.dart',
        '--route',
        '/results',
        '--dart-define=PUCK_PERFORMANCE_RESULTS_URL=$url',
      ],
      workingDirectory: example.path,
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await process.exitCode;
  } catch (error) {
    stderr.writeln('Could not open results: $error');
    exitCode = 1;
  } finally {
    await server?.close(force: true);
  }
}
