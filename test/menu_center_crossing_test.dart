import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/puck_layout_preview_painter.dart';

// Compare visible sectors, rather than a ring's arbitrary start-angle seam.
double sectorChange((double, double) a, (double, double) b) {
  bool inside((double, double) arc, double angle) =>
      (angle - arc.$1) % (2 * math.pi) <= arc.$2 - arc.$1 + 1e-8;
  var changed = 0;
  for (var i = 0; i < 3600; i++) {
    final angle = i * 2 * math.pi / 3600;
    if (inside(a, angle) != inside(b, angle)) changed++;
  }
  return changed * 2 * math.pi / 3600;
}

void main() {
  for (final y in [340.0, 353.0, 370.0, 388.0, 389.0, 390.0, 408.0, 425.0]) {
    testWidgets('recorded center crossing stays continuous at y=$y', (
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
            debug: const PuckMenuDebug(layoutPreview: true),
            controller: controller,
            rootPuck: const ColoredBox(key: root, color: Colors.blue),
            puckItems: [
              for (final n in [4, 7, 12])
                List.generate(n, (_) => const SizedBox()),
            ],
            layout: const PuckMenuLayout(levelRadius: 80),
          ),
        ),
      );
      await tester.pumpAndSettle();
      PuckLayoutPreviewPainter layout() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<PuckLayoutPreviewPainter>()
          .single;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(root)),
      );
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      await gesture.moveBy(Offset(220, y) - layout().center);
      await tester.pump();
      var previous = layout();
      Future<void> move(double x) async {
        await gesture.moveBy(Offset(x, y) - layout().center);
        await tester.pump();
        final current = layout();
        expect(
          sectorChange(previous.arc!, current.arc!),
          lessThan(.3),
          reason: 'x=$x y=$y before=${previous.arc} after=${current.arc}',
        );
        for (var tier = 0; tier < current.radii.length; tier++) {
          expect(
            (current.radii[tier] - previous.radii[tier]).abs(),
            lessThanOrEqualTo(
              (current.center - previous.center).distance + 1e-4,
            ),
            reason: 'radius jump at x=$x y=$y',
          );
          for (var point = 0; point <= 16; point++) {
            final angle =
                current.arc!.$1 +
                (current.arc!.$2 - current.arc!.$1) * point / 16;
            final p =
                current.center +
                Offset(math.cos(angle), math.sin(angle)) * current.radii[tier];
            expect(p.dx, inInclusiveRange(28 - 1e-6, 374 + 1e-6));
            expect(p.dy, inInclusiveRange(28 - 1e-6, 750 + 1e-6));
          }
        }
        if ((x - 201).abs() < 1e-6) {
          expect(current.arc!.$2 - current.arc!.$1, closeTo(2 * math.pi, 1e-6));
        }
        previous = current;
      }

      for (var x = 219.75; x >= 182; x -= .25) {
        await move(x);
      }
      for (var x = 182.25; x <= 220; x += .25) {
        await move(x);
      }
      await gesture.up();
      await tester.pumpAndSettle();
    });
  }
}
