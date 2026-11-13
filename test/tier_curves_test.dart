import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/puck_tier_curves.dart';

Future<int> alphaAt(PuckTierCurves curves, Offset point) async {
  final recorder = ui.PictureRecorder();
  PuckTierCurvePainter(
    curves,
    parentBounds: const Rect.fromLTWH(168, 168, 64, 64),
  ).paint(Canvas(recorder), const Size(400, 400));
  final picture = recorder.endRecording();
  final image = await picture.toImage(400, 400);
  final bytes = (await image.toByteData())!;
  final alpha = bytes.getUint8(
    (point.dy.toInt() * 400 + point.dx.toInt()) * 4 + 3,
  );
  image.dispose();
  picture.dispose();
  return alpha;
}

void main() {
  test(
    'full-circle curves connect the closing gap and retain puck holes',
    () async {
      final curves = PuckTierCurves()..fullCircle = true;
      addTearDown(curves.dispose);
      final points = [
        const Offset(200, 100),
        const Offset(300, 200),
        const Offset(200, 300),
        const Offset(100, 200),
      ];
      for (var i = 0; i < points.length; i++) {
        curves.update(
          i,
          bounds: Rect.fromCircle(center: points[i], radius: 20),
          tier: 0,
          order: i,
        );
      }
      expect(await alphaAt(curves, const Offset(129, 129)), greaterThan(0));
      expect(await alphaAt(curves, const Offset(271, 129)), greaterThan(0));
      for (final point in points) {
        expect(await alphaAt(curves, point), 0);
      }
    },
  );

  test(
    'circular tier arcs cut out translucent pucks and fade near the root',
    () async {
      final curves = PuckTierCurves();
      addTearDown(curves.dispose);
      final points = [
        const Offset(200, 100),
        const Offset(100, 200),
        const Offset(200, 300),
      ];
      for (var i = 0; i < points.length; i++) {
        curves.update(
          i,
          bounds: Rect.fromCircle(center: points[i], radius: 20),
          tier: 0,
          order: i,
        );
      }
      expect(await alphaAt(curves, const Offset(129, 129)), greaterThan(0));
      // A true circle passes through (129, 129), away from the old spline.
      expect(await alphaAt(curves, const Offset(144, 144)), 0);
      expect(await alphaAt(curves, const Offset(100, 200)), 0);
      expect(await alphaAt(curves, const Offset(200, 200)), 0);
      // Overlapping holes from other tiers must not expose a filled lens.
      curves.update(
        'overlap1',
        bounds: Rect.fromCircle(center: const Offset(129, 129), radius: 12),
        tier: 1,
        order: 0,
      );
      curves.update(
        'overlap2',
        bounds: Rect.fromCircle(center: const Offset(132, 126), radius: 12),
        tier: 2,
        order: 0,
      );
      expect(await alphaAt(curves, const Offset(129, 129)), 0);
      curves.remove('overlap1');
      curves.remove('overlap2');
      expect(await alphaAt(curves, const Offset(129, 129)), greaterThan(0));
      for (var i = 0; i < points.length; i++) {
        final center =
            const Offset(200, 200) + (points[i] - const Offset(200, 200)) * 0.2;
        curves.update(
          i,
          bounds: Rect.fromCircle(center: center, radius: 20),
          tier: 0,
          order: i,
        );
      }
      expect(await alphaAt(curves, const Offset(129, 129)), 0);
    },
  );

  testWidgets(
    'curve endpoints follow staggered springs through opening, reversal and disposal',
    (tester) async {
      const root = ValueKey('root');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckOverlay(
            showTierCurves: true,
            puck: const ColoredBox(key: root, color: Colors.blue),
            menuTiers: [
              for (var tier = 0; tier < 2; tier++)
                [
                  for (var i = 0; i < 3; i++)
                    ColoredBox(
                      key: ValueKey(tier * 3 + i),
                      color: Colors.green,
                    ),
                ],
            ],
            child: const SizedBox.expand(),
          ),
        ),
      );
      final painterFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is PuckTierCurvePainter,
      );
      final curves =
          (tester.widget<CustomPaint>(painterFinder).painter!
                  as PuckTierCurvePainter)
              .curves;
      expect(curves.items, isEmpty);
      await tester.tap(find.byKey(root));
      await tester.pump();
      final origin = tester.getCenter(find.byKey(root));
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        for (final item in curves.items) {
          expect(
            (item.bounds.center -
                    tester.getCenter(find.byKey(ValueKey(item.order))))
                .distance,
            lessThan(0.000001),
          );
        }
      }
      expect(
        curves.items.any((item) => (item.bounds.center - origin).distance > 30),
        isTrue,
      );
      await tester.tap(find.byKey(root));
      await tester.pump();
      for (var frame = 0; frame < 100; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        for (final item in curves.items) {
          expect(
            (item.bounds.center -
                    tester.getCenter(find.byKey(ValueKey(item.order))))
                .distance,
            lessThan(0.000001),
          );
        }
      }
      expect(curves.items, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
