import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/puck_anchor_painter.dart';
import 'dart:math' as math;

void main() {
  testWidgets('obstacles compress tiers before changing end caps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const root = ValueKey('root');
    await tester.pumpWidget(
      MaterialApp(
        home: PuckOverlay(
          initialEdge: PuckEdge.left,
          showDebugAnchors: true,
          puck: const ColoredBox(key: root, color: Colors.blue),
          menuTiers: [
            for (final count in [3, 4, 5])
              [
                for (var i = 0; i < count; i++)
                  const ColoredBox(color: Colors.green),
              ],
          ],
          child: const SizedBox.expand(),
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
    final squeezed = layout();
    expect(squeezed.arc, initial.arc);
    final scale =
        (squeezed.radii.last - squeezed.radii.first) /
        (initial.radii.last - initial.radii.first);
    expect(scale, greaterThanOrEqualTo(0.5));
    expect(scale, lessThan(1));
    // Rebuilding at the same position must not repeatedly halve the gaps.
    await tester.pump(const Duration(milliseconds: 16));
    expect(layout().radii, squeezed.radii);
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump();
    final rearranged = layout();
    expect(rearranged.arc, isNot(initial.arc));
    for (var tier = 1; tier < initial.radii.length; tier++) {
      expect(
        rearranged.radii[tier] - rearranged.radii[tier - 1],
        closeTo((initial.radii[tier] - initial.radii[tier - 1]) * 0.5, 0.001),
      );
    }
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
          home: PuckOverlay(
            initialEdge: PuckEdge.left,
            showDebugAnchors: true,
            puck: const ColoredBox(key: root, color: Colors.blue),
            menuTiers: [
              for (final count in [3, 4, 5])
                [
                  for (var i = 0; i < count; i++)
                    const ColoredBox(color: Colors.green),
                ],
            ],
            child: const SizedBox.expand(),
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
          home: PuckOverlay(
            menuRadius: 80,
            showDebugAnchors: true,
            puck: const ColoredBox(key: root, color: Colors.blue),
            menuTiers: [
              for (final count in [3, 4, 5])
                [
                  for (var i = 0; i < count; i++)
                    const ColoredBox(color: Colors.green),
                ],
            ],
            child: const SizedBox.expand(),
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
      expect(span(), greaterThanOrEqualTo(wider));
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
          home: PuckOverlay(
            menuRadius: 80,
            initialEdge: edge,
            showDebugAnchors: true,
            puck: const ColoredBox(key: root, color: Colors.blue),
            menuTiers: [
              for (final count in [3, 4, 5])
                [
                  for (var i = 0; i < count; i++)
                    const ColoredBox(color: Colors.green),
                ],
            ],
            child: const SizedBox.expand(),
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
            home: PuckOverlay(
              initialEdge: edge,
              initialVerticalAlignment: alignment,
              showDebugAnchors: true,
              puck: const ColoredBox(key: root, color: Colors.blue),
              menuTiers: [
                for (final count in [3, 4, 5])
                  [
                    for (var i = 0; i < count; i++)
                      const ColoredBox(color: Colors.green),
                  ],
              ],
              child: const SizedBox.expand(),
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
            expect((points[i] - expected).distance, lessThan(0.001));
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
        home: PuckOverlay(
          initialVerticalAlignment: 0,
          puck: const ColoredBox(key: root, color: Colors.blue),
          menuTiers: [
            const [],
            for (var tier = 0; tier < 5; tier++)
              [ColoredBox(key: ValueKey(tier), color: Colors.green)],
            const [],
          ],
          child: const SizedBox.expand(),
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
        home: PuckOverlay(
          puck: const ColoredBox(key: root, color: Colors.blue),
          menuTiers: [
            for (var i = 0; i < 3; i++)
              [ColoredBox(key: item(i), color: Colors.green)],
          ],
          child: const SizedBox.expand(),
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
