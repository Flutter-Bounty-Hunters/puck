import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/spring_puck.dart';

void main() {
  for (final counts in [
    [5],
    [4, 7, 12],
  ]) {
    for (final edge in PuckEdge.values) {
      testWidgets(
        'items retain arc sequence and mirror as a whole across docks: $counts/$edge',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(500, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = PuckMenuController()..open();
          addTearDown(controller.dispose);
          const root = ValueKey('root');
          await tester.pumpWidget(
            MaterialApp(
              home: PuckMenu.multiLevel(
                layout: PuckMenuLayout(
                  initialEdge: edge,
                  levelRadius: counts.length == 1 ? 156 : 80,
                ),
                controller: controller,
                rootPuck: const ColoredBox(key: root, color: Colors.blue),
                puckItems: [
                  for (var tier = 0; tier < counts.length; tier++)
                    List.generate(
                      counts[tier],
                      (i) => ColoredBox(
                        key: ValueKey((tier, i)),
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          void checkOrder({bool settled = false}) {
            final center = tester.getCenter(find.byKey(root));
            for (var tier = 0; tier < counts.length; tier++) {
              final points = [
                for (var i = 0; i < counts[tier]; i++)
                  if (settled)
                    tester.getCenter(find.byKey(ValueKey((tier, i))))
                  else
                    tester
                            .widget<SpringPuck>(
                              find.ancestor(
                                of: find.byKey(ValueKey((tier, i))),
                                matching: find.byType(SpringPuck),
                              ),
                            )
                            .target +
                        const Offset(24, 24),
              ];
              if (settled) {
                // Both docks read from the upper cap to the lower cap.
                expect(points.first.dy, lessThan(points.last.dy));
              }
              final steps = [
                for (var i = 1; i < points.length; i++)
                  math.atan2(
                    math.sin(
                      (points[i] - center).direction -
                          (points[i - 1] - center).direction,
                    ),
                    math.cos(
                      (points[i] - center).direction -
                          (points[i - 1] - center).direction,
                    ),
                  ),
              ];
              // Every consecutive pair follows the same direction and spacing.
              // Sorting by absolute Y breaks this as soon as the arc tilts or
              // extends beyond a semicircle.
              for (final step in steps) {
                expect(step, closeTo(steps.first, 1e-6));
                expect(step.abs(), greaterThan(1e-4));
              }
            }
          }

          checkOrder(settled: true);
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(root)),
          );
          final sign = edge == PuckEdge.left ? 1.0 : -1.0;
          await gesture.moveBy(Offset(30 * sign, 0));
          await tester.pump();
          for (var step = 0; step < 40; step++) {
            await gesture.moveBy(
              Offset(11 * sign, step == 10 ? -300 : (step == 30 ? 300 : 0)),
            );
            await tester.pump();
            checkOrder();
          }
          await gesture.up();
          await tester.pumpAndSettle();
          checkOrder(settled: true);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
