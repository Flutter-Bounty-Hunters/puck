import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/puck_anchor_painter.dart';
import 'dart:math' as math;

void main() {
  for (final width in [402.0, 480.0]) {
    for (final edge in PuckEdge.values) {
      for (final towardTop in [true, false]) {
        testWidgets(
          'rotates caps before compressing at $width/$edge/top=$towardTop',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final controller = PuckMenuController()..open();
            addTearDown(controller.dispose);
            const root = ValueKey('root');
            await tester.pumpWidget(
              MaterialApp(
                home: PuckMenu.multiLevel(
                  layout: PuckMenuLayout(initialEdge: edge, levelRadius: 80),
                  debug: const PuckMenuDebug(
                    layoutPreview: true,
                    showAnchors: true,
                  ),
                  controller: controller,
                  rootPuck: const ColoredBox(key: root, color: Colors.blue),
                  puckItems: [
                    for (final n in [4, 7, 12])
                      List.generate(n, (_) => const SizedBox()),
                  ],
                ),
              ),
            );
            await tester.pumpAndSettle();
            PuckAnchorPainter layout() => tester
                .widgetList<CustomPaint>(find.byType(CustomPaint))
                .map((w) => w.painter)
                .whereType<PuckAnchorPainter>()
                .single;
            final inward = edge == PuckEdge.left ? 1.0 : -1.0;
            final gesture = await tester.startGesture(
              tester.getCenter(find.byKey(root)),
            );
            await gesture.moveBy(Offset(20 * inward, 0));
            await tester.pump();
            await gesture.moveBy(Offset(80 * inward, 0));
            await tester.pump();
            final radii = List<double>.of(layout().radii);
            expect(
              layout().arc!.$2 - layout().arc!.$1,
              greaterThanOrEqualTo(math.pi - 1e-7),
            );
            // Approach the barrier far enough to require cap movement, while
            // a rotated semicircle still has room at the current radii.
            final y = towardTop ? radii.last + 14 : 900 - radii.last - 14;
            await gesture.moveBy(Offset(0, y - layout().center.dy));
            await tester.pump();
            final rotated = layout();
            for (var tier = 0; tier < radii.length; tier++) {
              expect(rotated.radii[tier], closeTo(radii[tier], .001));
            }
            expect(
              rotated.arc!.$2 - rotated.arc!.$1,
              greaterThanOrEqualTo(math.pi - 1e-7),
            );
            final freeCap = towardTop == (edge == PuckEdge.right)
                ? rotated.arc!.$1
                : rotated.arc!.$2;
            expect(math.cos(freeCap) * inward, lessThan(-.05));
            for (final radius in rotated.radii) {
              for (var i = 0; i <= 20; i++) {
                final a =
                    rotated.arc!.$1 +
                    (rotated.arc!.$2 - rotated.arc!.$1) * i / 20;
                final p =
                    rotated.center + Offset(math.cos(a), math.sin(a)) * radius;
                expect(p.dx, inInclusiveRange(28 - 1e-6, width - 28 + 1e-6));
                expect(p.dy, inInclusiveRange(28 - 1e-6, 872 + 1e-6));
              }
            }
            final inwardAngle = edge == PuckEdge.left ? 0.0 : math.pi;
            var previousRotation =
                ((rotated.arc!.$1 + rotated.arc!.$2) / 2 - inwardAngle).abs();
            for (var step = 1; step <= 8; step++) {
              final nextY = y + (450 - y) * step / 8;
              await gesture.moveBy(Offset(0, nextY - layout().center.dy));
              await tester.pump();
              final arc = layout().arc!;
              final rotation = ((arc.$1 + arc.$2) / 2 - inwardAngle).abs();
              expect(rotation, lessThanOrEqualTo(previousRotation + 1e-6));
              previousRotation = rotation;
            }
            final restored = layout();
            expect(
              (restored.arc!.$1 + restored.arc!.$2) / 2,
              closeTo(inwardAngle, 1e-6),
            );
            // Each end's closest puck/wall clearance should be balanced,
            // including while the barrier requires a rotated orientation.
            double clearance(PuckAnchorPainter p, double angle) {
              return [
                for (final r in [p.radii.first, p.radii.last]) ...[
                  p.center.dx + r * math.cos(angle) - 28,
                  width - 28 - p.center.dx - r * math.cos(angle),
                  p.center.dy + r * math.sin(angle) - 28,
                  872 - p.center.dy - r * math.sin(angle),
                ],
              ].reduce(math.min);
            }

            for (final p in [rotated, restored]) {
              expect(
                clearance(p, p.arc!.$1),
                closeTo(clearance(p, p.arc!.$2), .01),
              );
            }
            await gesture.up();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final edge in PuckEdge.values) {
    for (final preview in [false, true]) {
      testWidgets(
        'reversing toward $edge wall keeps radii stable (preview: $preview)',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(402, 752));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = PuckMenuController()..open();
          addTearDown(controller.dispose);
          const root = ValueKey('root');
          await tester.pumpWidget(
            MaterialApp(
              home: PuckMenu.multiLevel(
                layout: PuckMenuLayout(initialEdge: edge, levelRadius: 80),
                debug: PuckMenuDebug(layoutPreview: preview, showAnchors: true),
                controller: controller,
                rootPuck: const ColoredBox(key: root, color: Colors.blue),
                puckItems: [
                  for (final count in [4, 7, 12])
                    List.generate(count, (_) => const SizedBox()),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          PuckAnchorPainter layout() => tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((w) => w.painter)
              .whereType<PuckAnchorPainter>()
              .single;
          final initial = layout();
          final inward = edge == PuckEdge.left ? 1.0 : -1.0;
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(root)),
          );
          await gesture.moveBy(Offset(20 * inward, 0));
          await tester.pump();
          await gesture.moveBy(Offset(20 * inward, 0));
          await tester.pump();
          expect(layout().arc!.$2 - layout().arc!.$1, greaterThan(math.pi));
          // Return to the docking edge without a transient radius collapse.
          for (var step = 0; step < 40; step++) {
            await gesture.moveBy(Offset(-inward, 0));
            await tester.pump(const Duration(milliseconds: 16));
            expect(layout().radii, initial.radii, reason: 'outward step $step');
          }
          expect(layout().arc, initial.arc);
          // Keep pulling until the root's center is outside the viewport.
          // Assert pointer tracking as well as radii, so clamping the root
          // cannot accidentally make this regression test pass.
          var previousSpan = layout().arc!.$2 - layout().arc!.$1;
          for (var step = 1; step <= 30; step++) {
            await gesture.moveBy(Offset(-inward, 0));
            await tester.pump(const Duration(milliseconds: 16));
            final expectedX = initial.center.dx - inward * step;
            expect(
              tester.getCenter(find.byKey(root)).dx,
              closeTo(expectedX, 1e-8),
            );
            expect(layout().center.dx, closeTo(expectedX, 1e-8));
            expect(
              layout().radii,
              initial.radii,
              reason: 'offscreen step $step',
            );
            final span = layout().arc!.$2 - layout().arc!.$1;
            expect(span, lessThanOrEqualTo(previousSpan + 1e-8));
            previousSpan = span;
          }
          // Even a captured drag far outside the viewport must not shrink the
          // other tiers to compensate for an invisible fixed inner circle.
          await gesture.moveBy(Offset(-70 * inward, 0));
          await tester.pump(const Duration(milliseconds: 16));
          expect(layout().radii, initial.radii);
          expect(layout().arc, isNull);
          expect(
            tester.getCenter(find.byKey(root)).dx,
            closeTo(initial.center.dx - 100 * inward, 1e-8),
          );
          await gesture.moveBy(Offset(70 * inward, 0));
          await tester.pump(const Duration(milliseconds: 16));
          expect(layout().radii, initial.radii);
          expect(layout().arc, isNotNull);
          final releasedX = tester.getCenter(find.byKey(root)).dx;
          await gesture.up();
          await tester.pump();
          expect(
            tester.getCenter(find.byKey(root)).dx,
            closeTo(releasedX, 1e-8),
          );
          await tester.pumpAndSettle();
          expect(
            tester.getCenter(find.byKey(root)).dx,
            closeTo(initial.center.dx, 1e-8),
          );
          expect(layout().radii, initial.radii);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('compresses only when rotation cannot preserve the fan span', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 900));
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
            for (final n in [4, 7, 12])
              List.generate(n, (_) => const SizedBox()),
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
    final initial = layout();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(root)),
    );
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-1, 0));
    await tester.pump();
    await gesture.moveBy(Offset(201 - layout().center.dx, 0));
    await tester.pump();
    final compressed = layout();
    expect(compressed.radii.first, initial.radii.first);
    expect(compressed.radii.last, lessThan(initial.radii.last));
    final scale =
        (compressed.radii.last - compressed.radii.first) /
        (initial.radii.last - initial.radii.first);
    expect(scale, inInclusiveRange(.5, 1.0));
    expect(compressed.arc!.$2 - compressed.arc!.$1, closeTo(2 * math.pi, 1e-7));
    // Move away and back to force fresh layout evaluations at the same point.
    await gesture.moveBy(const Offset(.1, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-.1, 0));
    await tester.pump();
    for (var tier = 0; tier < compressed.radii.length; tier++) {
      expect(layout().radii[tier], closeTo(compressed.radii[tier], .0001));
    }
    await gesture.moveBy(Offset(initial.center.dx - layout().center.dx, 0));
    await tester.pump();
    expect(layout().radii, initial.radii);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('obstacles rotate end caps before compressing tiers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const root = ValueKey('root');
    await tester.pumpWidget(
      MaterialApp(
        home: PuckMenu.multiLevel(
          layout: const PuckMenuLayout(initialEdge: PuckEdge.left),
          debug: const PuckMenuDebug(showAnchors: true),
          rootPuck: const ColoredBox(key: root, color: Colors.blue),
          puckItems: [
            for (final count in [3, 4, 5])
              [
                for (var i = 0; i < count; i++)
                  const ColoredBox(color: Colors.green),
              ],
          ],
        ),
      ),
    );
    PuckAnchorPainter layout() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<PuckAnchorPainter>()
        .single;
    await tester.tap(find.byKey(root));
    await tester.pumpAndSettle();
    final initial = layout();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(root)),
    );
    // First cross the drag threshold, then apply the measured displacement.
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(430, 0));
    await tester.pump();
    final rotated = layout();
    expect(rotated.arc, isNot(initial.arc));
    expect(rotated.radii, initial.radii);
    // Rebuilding at the same position must not change the radii.
    await tester.pump(const Duration(milliseconds: 16));
    expect(layout().radii, rotated.radii);
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump();
    final rearranged = layout();
    expect(rearranged.radii, initial.radii);
    await gesture.moveBy(const Offset(-600, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(layout().radii, initial.radii);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'arc fans out on the first frame after reversing away from a barrier',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const root = ValueKey('root');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckMenu.multiLevel(
            layout: const PuckMenuLayout(initialEdge: PuckEdge.left),
            debug: const PuckMenuDebug(showAnchors: true),
            rootPuck: const ColoredBox(key: root, color: Colors.blue),
            puckItems: [
              for (final count in [3, 4, 5])
                [
                  for (var i = 0; i < count; i++)
                    const ColoredBox(color: Colors.green),
                ],
            ],
          ),
        ),
      );
      PuckAnchorPainter layout() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<PuckAnchorPainter>()
          .single;
      double span() => layout().arc!.$2 - layout().arc!.$1;
      await tester.tap(find.byKey(root));
      await tester.pumpAndSettle();
      final openSpan = span();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(root)),
      );
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -380));
      await tester.pump();
      final squeezedSpan = span();
      expect(squeezedSpan, lessThan(openSpan));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(span(), greaterThan(squeezedSpan));
      final widerSpan = span();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(span(), greaterThan(widerSpan));
      await gesture.moveBy(const Offset(0, 320));
      await tester.pump();
      expect(span(), closeTo(openSpan, 0.001));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'right-wall horizontal reversal immediately restores angular space',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const root = ValueKey('root');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckMenu.multiLevel(
            debug: const PuckMenuDebug(showAnchors: true),
            rootPuck: const ColoredBox(key: root, color: Colors.blue),
            puckItems: [
              for (final count in [3, 4, 5])
                [
                  for (var i = 0; i < count; i++)
                    const ColoredBox(color: Colors.green),
                ],
            ],

            layout: const PuckMenuLayout(levelRadius: 80),
          ),
        ),
      );
      PuckAnchorPainter layout() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<PuckAnchorPainter>()
          .single;
      double span() => layout().arc!.$2 - layout().arc!.$1;
      await tester.tap(find.byKey(root));
      await tester.pumpAndSettle();
      final initial = span();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(root)),
      );
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      for (var step = 0; step < 80 && span() > initial - 0.4; step++) {
        await gesture.moveBy(const Offset(-4, 0));
        await tester.pump();
      }
      final narrow = span();
      expect(narrow, lessThan(initial - 0.4));
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump();
      expect(span(), greaterThan(narrow));
      final wider = span();
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump();
      expect(span(), greaterThanOrEqualTo(math.min(wider, math.pi) - 1e-7));
      expect(span(), greaterThanOrEqualTo(initial - 0.001));
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  for (final edge in PuckEdge.values) {
    testWidgets('docking at $edge restores stable resting tier distances', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const root = ValueKey('root');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckMenu.multiLevel(
            layout: PuckMenuLayout(initialEdge: edge, levelRadius: 80),
            debug: const PuckMenuDebug(showAnchors: true),
            rootPuck: const ColoredBox(key: root, color: Colors.blue),
            puckItems: [
              for (final count in [3, 4, 5])
                [
                  for (var i = 0; i < count; i++)
                    const ColoredBox(color: Colors.green),
                ],
            ],
          ),
        ),
      );
      PuckAnchorPainter layout() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<PuckAnchorPainter>()
          .single;
      await tester.tap(find.byKey(root));
      await tester.pumpAndSettle();
      final initialRadii = List.of(layout().radii);
      final direction = edge == PuckEdge.right ? -1.0 : 1.0;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(root)),
      );
      await gesture.moveBy(Offset(direction * 20, 0));
      await tester.pump();
      await gesture.moveBy(Offset(direction * 160, 0));
      await tester.pump();
      expect(layout().radii.last, lessThan(initialRadii.last));
      // Pause to avoid introducing a fling, then release and sample every frame
      // of the root's docking spring, including the final settled frames.
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();
      final dock = layout();
      expect(dock.radii, initialRadii);
      for (var frame = 0; frame < 150; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(layout().radii, initialRadii);
        expect(layout().arc, dock.arc);
        expect(layout().center, dock.center);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final edge in PuckEdge.values) {
    for (final alignment in [0.0, 0.1, 0.4, 0.5, 0.6, 0.9, 1.0]) {
      testWidgets('tiers share end caps at $edge/$alignment', (tester) async {
        // Leave enough vertical room for the expanded spacing to have a
        // horizontal region between the top and bottom barriers.
        await tester.binding.setSurfaceSize(const Size(800, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const root = ValueKey('root');
        await tester.pumpWidget(
          MaterialApp(
            home: PuckMenu.multiLevel(
              layout: PuckMenuLayout(
                initialEdge: edge,
                initialVerticalAlignment: alignment,
              ),
              debug: const PuckMenuDebug(showAnchors: true),
              rootPuck: const ColoredBox(key: root, color: Colors.blue),
              puckItems: [
                for (final count in [3, 4, 5])
                  [
                    for (var i = 0; i < count; i++)
                      const ColoredBox(color: Colors.green),
                  ],
              ],
            ),
          ),
        );
        await tester.tap(find.byKey(root));
        await tester.pump();
        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((widget) => widget.painter)
            .whereType<PuckAnchorPainter>()
            .single;
        for (var tier = 1; tier < painter.radii.length; tier++) {
          expect(
            painter.radii[tier] - painter.radii[tier - 1],
            lessThanOrEqualTo(112 + 8 * tier + 0.001),
          );
        }
        expect(
          painter.radii[2] - painter.radii[1],
          greaterThan(painter.radii[1] - painter.radii[0]),
        );
        final arc = painter.arc!;
        expect(arc.$2, greaterThan(arc.$1));
        if (alignment == 0.5) {
          // A free menu should reach almost vertically along the dock wall.
          expect(math.cos(arc.$1).abs(), lessThan(0.1));
          expect(math.cos(arc.$2).abs(), lessThan(0.1));
        }
        var offset = 1;
        var tier = 0;
        for (final count in [3, 4, 5]) {
          final points = painter.anchors.sublist(offset, offset + count);
          for (var i = 0; i < count; i++) {
            final angle = arc.$1 + (arc.$2 - arc.$1) * i / (count - 1);
            final expected =
                painter.center +
                Offset(math.cos(angle), math.sin(angle)) * painter.radii[tier];
            expect(
              points
                  .map((point) => (point - expected).distance)
                  .reduce(math.min),
              lessThan(0.001),
            );
            expect(points[i].dx, inInclusiveRange(24, 776));
            expect(points[i].dy, inInclusiveRange(24, 976));
          }
          offset += count;
          tier++;
        }
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets('arbitrary tiers tolerate empty tiers, resizing and reversal', (
    tester,
  ) async {
    const root = ValueKey('root');
    await tester.pumpWidget(
      MaterialApp(
        home: PuckMenu.multiLevel(
          layout: const PuckMenuLayout(initialVerticalAlignment: 0),
          rootPuck: const ColoredBox(key: root, color: Colors.blue),
          puckItems: [
            const [],
            for (var tier = 0; tier < 5; tier++)
              [ColoredBox(key: ValueKey(tier), color: Colors.green)],
            const [],
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(root));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byKey(root));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byKey(root));
    await tester.pump();
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 5; i++) {
      final rect = tester.getRect(find.byKey(ValueKey(i)));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(480));
    }
    await tester.tap(find.byKey(root));
    await tester.pump();
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey(i)), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('tiers launch outside-in and close inside-out', (tester) async {
    const root = ValueKey('root');
    Key item(int i) => ValueKey(i);
    await tester.pumpWidget(
      MaterialApp(
        home: PuckMenu.multiLevel(
          rootPuck: const ColoredBox(key: root, color: Colors.blue),
          puckItems: [
            for (var i = 0; i < 3; i++)
              [ColoredBox(key: item(i), color: Colors.green)],
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(root));
    await tester.pump();
    final origin = tester.getCenter(find.byKey(root));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.getCenter(find.byKey(item(0))), origin);
    expect(tester.getCenter(find.byKey(item(1))), origin);
    expect(
      (tester.getCenter(find.byKey(item(2))) - origin).distance,
      greaterThan(0),
    );
    // Explicitly advance past timers as well as spring frames.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final centers = [
      for (var i = 0; i < 3; i++) tester.getCenter(find.byKey(item(i))),
    ];
    expect(
      (centers[0] - origin).distance,
      lessThan((centers[1] - origin).distance),
    );
    expect(
      (centers[1] - origin).distance,
      lessThan((centers[2] - origin).distance),
    );
    await tester.tap(find.byKey(root));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.getCenter(find.byKey(item(0))), isNot(centers[0]));
    expect(tester.getCenter(find.byKey(item(1))), centers[1]);
    expect(tester.getCenter(find.byKey(item(2))), centers[2]);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(item(i)), findsNothing);
    }
  });
}
