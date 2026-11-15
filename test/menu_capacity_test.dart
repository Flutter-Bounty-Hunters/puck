import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/puck_anchor_painter.dart';

void main() {
  for (final counts in [
    [2, 3, 4],
    [3, 4, 5],
    [4, 7, 12],
  ]) {
    testWidgets('narrower arcs retain useful radius without crowding $counts', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(402, 778));
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
              for (final count in counts)
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
      await gesture.moveBy(const Offset(140, 150) - layout().center);
      await tester.pump();
      final improved = layout();
      // Preserving the angular span used to shrink the outer radius to 172px
      // here, leaving the 48px pucks overlapping across the innermost tier gap.
      expect(improved.radii.first, 80);
      expect(improved.radii.last, greaterThan(195));
      expect(improved.arc!.$2 - improved.arc!.$1, lessThan(math.pi));
      final points = improved.anchors.skip(1).toList();
      for (var i = 0; i < points.length; i++) {
        for (var j = i + 1; j < points.length; j++) {
          expect(
            (points[i] - points[j]).distance - 48,
            greaterThan(2),
            reason: 'items $i and $j must fit, including across tiers',
          );
        }
      }
      var offset = 1;
      for (var tier = 0; tier < counts.length; tier++) {
        for (final end in [0, counts[tier] - 1]) {
          final angle = end == 0 ? improved.arc!.$1 : improved.arc!.$2;
          final point =
              improved.center +
              Offset(math.cos(angle), math.sin(angle)) * improved.radii[tier];
          expect(
            improved.anchors
                .sublist(offset, offset + counts[tier])
                .map((anchor) => (anchor - point).distance)
                .reduce(math.min),
            lessThan(1e-6),
          );
        }
        offset += counts[tier];
      }

      var previous = improved;
      Future<void> move(Offset target) async {
        await gesture.moveBy(target - layout().center);
        await tester.pump();
        final current = layout();
        final oldMiddle = (previous.arc!.$1 + previous.arc!.$2) / 2;
        final middle = (current.arc!.$1 + current.arc!.$2) / 2;
        expect(
          math
              .atan2(math.sin(middle - oldMiddle), math.cos(middle - oldMiddle))
              .abs(),
          lessThan(.12),
          reason: 'orientation jump at $target',
        );
        expect(
          ((current.arc!.$2 - current.arc!.$1) -
                  (previous.arc!.$2 - previous.arc!.$1))
              .abs(),
          lessThan(.15),
          reason: 'span jump at $target',
        );
        for (var tier = 0; tier < counts.length; tier++) {
          expect(
            (current.radii[tier] - previous.radii[tier]).abs(),
            lessThan(5),
            reason: 'radius jump at $target',
          );
          expect(
            current.radii[tier],
            inInclusiveRange(80 + (resting[tier] - 80) * .5, resting[tier]),
          );
          for (var i = 0; i <= 16; i++) {
            final a =
                current.arc!.$1 + (current.arc!.$2 - current.arc!.$1) * i / 16;
            final point =
                current.center +
                Offset(math.cos(a), math.sin(a)) * current.radii[tier];
            expect(point.dx, inInclusiveRange(28 - 1e-6, 374 + 1e-6));
            expect(point.dy, inInclusiveRange(28 - 1e-6, 750 + 1e-6));
          }
        }
        previous = current;
      }

      for (var x = 140.25; x <= 300; x += .25) {
        await move(Offset(x, 150));
      }
      for (var x = 299.75; x >= 140; x -= .25) {
        await move(Offset(x, 150));
      }
      expect(layout().radii, improved.radii);
      expect(layout().arc, improved.arc);
      for (var y = 150.25; y <= 300; y += .25) {
        await move(Offset(140, y));
      }
      for (var y = 299.75; y >= 150; y -= .25) {
        await move(Offset(140, y));
      }
      expect(layout().radii, improved.radii);
      expect(layout().arc, improved.arc);
      await gesture.up();
      await tester.pump();
      expect(layout().radii, improved.radii);
      expect(layout().arc, improved.arc);
      await tester.pumpAndSettle();
      final docked = layout();
      await tester.pump(const Duration(seconds: 1));
      expect(layout().radii, docked.radii);
      expect(layout().arc, docked.arc);
      expect(tester.takeException(), isNull);
    });
  }
}
