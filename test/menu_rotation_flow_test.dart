import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/puck_layout_preview_painter.dart';

void main() {
  for (final width in [402.0, 480.0]) {
    for (final towardTop in [true, false]) {
      for (final depth in [140.0, 220.0, 298.0]) {
        testWidgets(
          'rotation flows across $width/top=$towardTop/depth=$depth',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 900));
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
            double angle() => (layout().arc!.$1 + layout().arc!.$2) / 2;
            double paintedChange((double, double) a, (double, double) b) {
              bool contains((double, double) arc, double angle) =>
                  (angle - arc.$1) % (2 * math.pi) <= arc.$2 - arc.$1 + 1e-8;
              var changed = 0;
              for (var i = 0; i < 1440; i++) {
                final a0 = i * 2 * math.pi / 1440;
                if (contains(a, a0) != contains(b, a0)) changed++;
              }
              return changed * 2 * math.pi / 1440;
            }

            final dockRadius = layout().radii.last;
            final gesture = await tester.startGesture(
              tester.getCenter(find.byKey(root)),
            );
            await gesture.moveBy(const Offset(-20, 0));
            await tester.pump();
            await gesture.moveBy(const Offset(-60, 0));
            await tester.pump();
            final y = towardTop ? depth : 900 - depth;
            await gesture.moveBy(Offset(0, y - layout().center.dy));
            await tester.pump();
            if (depth < dockRadius) {
              expect(layout().radii.last, lessThan(dockRadius));
            }
            final startX = layout().center.dx;
            final startAngle = angle();

            Future<void> traverse(double target) async {
              final movingLeft = target < layout().center.dx;
              final rotationSign = (movingLeft == towardTop) ? -1.0 : 1.0;
              var previous = angle();
              var previousArc = layout().arc!;
              while ((layout().center.dx - target).abs() > 1e-8) {
                final fine = (layout().center.dx - width / 2).abs() < 9;
                final step = fine ? .25 : 2.0;
                final dx = (target - layout().center.dx).clamp(-step, step);
                await gesture.moveBy(Offset(dx, 0));
                await tester.pump();
                final current = angle();
                final delta = math.atan2(
                  math.sin(current - previous),
                  math.cos(current - previous),
                );
                final currentArc = layout().arc!;
                expect(
                  paintedChange(previousArc, currentArc),
                  lessThan(fine ? .3 : .7),
                  reason: 'angle jump at x=${layout().center.dx}',
                );
                final directional =
                    math.max(
                      previousArc.$2 - previousArc.$1,
                      currentArc.$2 - currentArc.$1,
                    ) <=
                    math.pi + 1e-6;
                if (directional) {
                  expect(delta * rotationSign, greaterThanOrEqualTo(-.0001));
                }
                if (directional &&
                    (layout().center.dx - width / 2).abs() < .5) {
                  expect(
                    math.sin(current) * (towardTop ? 1 : -1),
                    greaterThan(.98),
                  );
                }
                final p = layout();
                for (final radius in [p.radii.first, p.radii.last]) {
                  for (var i = 0; i <= 4; i++) {
                    final a = p.arc!.$1 + (p.arc!.$2 - p.arc!.$1) * i / 4;
                    final point =
                        p.center + Offset(math.cos(a), math.sin(a)) * radius;
                    expect(
                      point.dx,
                      inInclusiveRange(28 - 1e-6, width - 28 + 1e-6),
                    );
                    expect(point.dy, inInclusiveRange(28 - 1e-6, 872 + 1e-6));
                  }
                }
                previous = current;
                previousArc = currentArc;
              }
            }

            await traverse(60);
            expect(math.cos(angle()), greaterThan(.75));
            await traverse(startX);
            expect(angle(), closeTo(startAngle, .0001));
            // Shrinking the step must shrink the change: no hidden side switch
            // may remain at the exact viewport midpoint.
            await gesture.moveBy(
              Offset(width / 2 + .001 - layout().center.dx, 0),
            );
            await tester.pump();
            final justRight = layout().arc!;
            await gesture.moveBy(const Offset(-.002, 0));
            await tester.pump();
            expect(paintedChange(justRight, layout().arc!), lessThan(.04));
            await gesture.up();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
