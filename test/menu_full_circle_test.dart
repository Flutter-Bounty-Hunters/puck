import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/puck_anchor_painter.dart';

void main() {
  for (final width in [402.0, 1000.0]) {
    testWidgets('tiers unfold into distinct, evenly spaced rings at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = PuckMenuController()..open();
      addTearDown(controller.dispose);
      const root = ValueKey('root');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckMenu.multiLevel(
            debug: const PuckMenuDebug(layoutPreview: true, showAnchors: true),
            controller: controller,
            rootPuck: const ColoredBox(key: root, color: Colors.blue),
            puckItems: [
              for (final count in [4, 7, 12])
                List.generate(count, (_) => const SizedBox()),
            ],
            layout: const PuckMenuLayout(levelRadius: 80),
          ),
        ),
      );
      await tester.pumpAndSettle();
      PuckAnchorPainter layout() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<PuckAnchorPainter>()
          .single;
      final resting = List<double>.of(layout().radii);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(root)),
      );
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      await gesture.moveBy(Offset(width / 2 - layout().center.dx, 0));
      await tester.pump();
      final ring = layout();
      expect(ring.arc!.$2 - ring.arc!.$1, closeTo(2 * math.pi, 1e-7));
      if (width == 1000) expect(ring.radii, resting);
      var offset = 1;
      for (var tier = 0; tier < 3; tier++) {
        final count = [4, 7, 12][tier];
        final points = ring.anchors.sublist(offset, offset + count);
        final angles = points.map((p) => (p - ring.center).direction).toList()
          ..sort();
        for (var i = 0; i < count; i++) {
          expect(
            (points[i] - ring.center).distance,
            closeTo(ring.radii[tier], 1e-6),
          );
          expect(
            (angles[(i + 1) % count] - angles[i]) % (2 * math.pi),
            closeTo(2 * math.pi / count, 1e-6),
          );
        }
        expect(
          ring.radii[tier],
          greaterThanOrEqualTo(80 + (resting[tier] - 80) * .5),
        );
        offset += count;
      }
      // At full width the seam has no visual meaning: crossing the screen's
      // midpoint must not rotate the actual item destinations.
      if (width == 1000) {
        await gesture.moveBy(const Offset(-1, 0));
        await tester.pump();
        final moved = layout();
        for (var i = 1; i < ring.anchors.length; i++) {
          expect(
            (moved.anchors[i] - moved.center - (ring.anchors[i] - ring.center))
                .distance,
            lessThan(1e-6),
          );
        }
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
