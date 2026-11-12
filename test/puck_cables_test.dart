import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/src/puck_cables.dart';
import 'package:puck/puck.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'ropes default off and can toggle without remounting menu items',
    (tester) async {
      bool? show;
      late StateSetter rebuild;
      const parent = ValueKey('parent');
      const item = ValueKey('item');
      final painter = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is PuckCablePainter,
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              const puck = ColoredBox(key: parent, color: Color(0xFF0000FF));
              const items = [ColoredBox(key: item, color: Color(0xFF00FF00))];
              return show == null
                  ? const PuckOverlay(
                      puck: puck,
                      menuItems: items,
                      child: SizedBox.expand(),
                    )
                  : PuckOverlay(
                      showRopes: show!,
                      puck: puck,
                      menuItems: items,
                      child: const SizedBox.expand(),
                    );
            },
          ),
        ),
      );
      await tester.tap(find.byKey(parent));
      await tester.pumpAndSettle();
      expect(painter, findsNothing);
      final element = tester.element(find.byKey(item));
      for (final enabled in [true, false, true]) {
        rebuild(() => show = enabled);
        await tester.pumpAndSettle();
        expect(painter, enabled ? findsOneWidget : findsNothing);
        expect(tester.element(find.byKey(item)), same(element));
      }
      await tester.tap(find.byKey(parent));
      await tester.pumpAndSettle();
      expect(find.byKey(item, skipOffstage: false), findsNothing);
    },
  );

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

      Future<List<int>> pixelsAt(
        List<int> xs, {
        PuckRopeStyle style = const PuckRopeStyle(),
        int y = 50,
      }) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xFF20CC40), BlendMode.src);
        PuckCablePainter(
          cables,
          style: style,
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
        final result = [for (final x in xs) bytes.getUint32((y * 200 + x) * 4)];
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

      const style = PuckRopeStyle(
        thickness: 12,
        brightColor: Color(0xFF00FFFF),
        darkColor: Color(0xFFFF0000),
      );
      expect((await pixelsAt([50], style: style)).single, 0x00FFFFFF);
      expect((await pixelsAt([50], style: style, y: 54)).single, 0xFF0000FF);
      expect((await pixelsAt([50], style: style, y: 57)).single, 0x20CC40FF);

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
