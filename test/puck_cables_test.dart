import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/src/puck_cables.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'only cables are masked by the union of all current puck circles',
    () async {
      final cables = PuckCables();
      addTearDown(cables.dispose);
      cables.update(
        'rope',
        points: [const Offset(20, 50), const Offset(180, 50)],
        bounds: Rect.fromCircle(center: const Offset(180, 50), radius: 10),
      );
      // These are other pucks crossing this rope, including overlapping circles.
      cables.update(
        'crossing',
        points: [],
        bounds: Rect.fromCircle(center: const Offset(100, 50), radius: 15),
      );
      cables.update(
        'overlapping',
        points: [],
        bounds: Rect.fromCircle(center: const Offset(110, 50), radius: 15),
      );

      Future<List<int>> pixelsAt(List<int> xs) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xFF20CC40), BlendMode.src);
        PuckCablePainter(
          cables,
          parentBounds: Rect.fromCircle(
            center: const Offset(20, 50),
            radius: 10,
          ),
        ).paint(canvas, const Size(200, 100));
        // Later content must not inherit the cable clip.
        canvas.drawRect(
          const Rect.fromLTWH(18, 48, 4, 4),
          Paint()..color = const Color(0xFFFFFFFF),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(200, 100);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final result = [
          for (final x in xs) bytes.getUint32((50 * 200 + x) * 4),
        ];
        image.dispose();
        picture.dispose();
        return result;
      }

      final pixels = await pixelsAt([20, 25, 50, 100, 110, 120, 150, 180]);
      expect(pixels[0], 0xFFFFFFFF);
      for (final i in [1, 3, 4, 5, 7]) {
        expect(
          pixels[i],
          0x20CC40FF,
        ); // Background survives inside every circle.
      }
      for (final i in [2, 6]) {
        expect(pixels[i], isNot(0x20CC40FF)); // Rope survives between circles.
      }

      cables.update(
        'crossing',
        points: [],
        bounds: Rect.fromCircle(center: const Offset(100, 20), radius: 15),
      );
      cables.remove('overlapping');
      expect((await pixelsAt([100])).single, isNot(0x20CC40FF));
    },
  );
}
