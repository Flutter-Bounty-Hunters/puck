import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/src/puck_level_curves.dart';

void main() {
  test('measure demo arc paint CPU time', () {
    final curves = PuckLevelCurves();
    var index = 0;
    for (final (level, count, radius) in [
      (0, 4, 80.0),
      (1, 7, 168.0),
      (2, 12, 264.0),
    ]) {
      for (var i = 0; i < count; i++) {
        final angle = math.pi / 2 + math.pi * i / (count - 1);
        curves.update(
          index++,
          bounds: Rect.fromCircle(
            center:
                const Offset(374, 422) +
                Offset(math.cos(angle), math.sin(angle)) * radius,
            radius: 24,
          ),
          level: level,
          order: i,
        );
      }
    }
    final painter = PuckLevelCurvePainter(
      curves,
      parentBounds: const Rect.fromLTWH(342, 390, 64, 64),
    );
    final results = <double>[];
    for (var run = 0; run < 6; run++) {
      final watch = Stopwatch()..start();
      for (var frame = 0; frame < 200; frame++) {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(390, 844));
        recorder.endRecording().dispose();
      }
      watch.stop();
      if (run > 0) results.add(watch.elapsedMicroseconds / 200);
    }
    results.sort();
    // ignore: avoid_print
    print('ARC_PAINT_CPU_MEDIAN_US=${results[2]}');
    curves.dispose();
  });
}
