import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/puck_anchor_painter.dart';
import 'package:puck/src/puck_layout_preview_painter.dart';
import 'package:puck/src/spring_puck.dart';

void main() {
  for (final edge in PuckEdge.values) {
    testWidgets('compressed preview stays continuous when released at $edge', (
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
            layout: PuckMenuLayout(initialEdge: edge, levelRadius: 80),
            debug: const PuckMenuDebug(layoutPreview: true),
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
      PuckLayoutPreviewPainter guides() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<PuckLayoutPreviewPainter>()
          .single;
      final dock = guides();
      final direction = edge == PuckEdge.right ? -1.0 : 1.0;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(root)),
      );
      await gesture.moveBy(Offset(20 * direction, 0));
      await tester.pump();
      await gesture.moveBy(Offset(80 * direction, 0));
      await tester.pump();
      var previous = guides();
      expect(previous.radii.last, lessThan(dock.radii.last));
      await gesture.up();
      await tester.pump();
      expect(guides().center, previous.center);
      expect(guides().radii, previous.radii);
      expect(guides().arc, previous.arc);
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final current = guides();
        expect(current.center, tester.getCenter(find.byKey(root)));
        final movement = (current.center - previous.center).distance;
        for (var level = 0; level < current.radii.length; level++) {
          expect(
            (current.radii[level] - previous.radii[level]).abs(),
            lessThanOrEqualTo(movement + .0001),
            reason: 'docking frame $frame',
          );
        }
        // Docking can overshoot the side wall slightly. Any narrowing must
        // track that real motion, not a release-triggered layout reset.
        final span = current.arc!.$2 - current.arc!.$1;
        final previousSpan = previous.arc!.$2 - previous.arc!.$1;
        expect(
          (span - previousSpan).abs(),
          lessThanOrEqualTo(2.1 * movement / current.radii.first + .0001),
        );
        previous = current;
      }
      await tester.pumpAndSettle();
      expect(guides().radii, dock.radii);
      expect(guides().center, dock.center);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('guides follow the moving root while its anchor stays docked', (
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
    PuckLayoutPreviewPainter guides() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<PuckLayoutPreviewPainter>()
        .single;
    PuckAnchorPainter anchors() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<PuckAnchorPainter>()
        .single;
    final dock = tester.getCenter(find.byKey(root));
    final gesture = await tester.startGesture(dock);
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    final released = tester.getCenter(find.byKey(root));
    await gesture.up();
    await tester.pump();
    expect(guides().center, tester.getCenter(find.byKey(root)));
    expect(anchors().anchors.first, dock);
    var moved = false;
    for (var frame = 0; frame < 45; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final current = tester.getCenter(find.byKey(root));
      expect(
        (guides().center - current).distance,
        lessThan(0.000001),
        reason: 'docking frame $frame',
      );
      moved = moved || (current - released).distance > 1;
    }
    expect(moved, isTrue);
    await tester.pumpAndSettle();
    expect(guides().center, dock);
  });

  testWidgets('preview uses normal layout without mounting item springs', (
    tester,
  ) async {
    var preview = false;
    late StateSetter rebuild;
    final controller = PuckMenuController()..open();
    addTearDown(controller.dispose);
    const root = ValueKey('root');
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return PuckMenu.multiLevel(
              debug: PuckMenuDebug(layoutPreview: preview, showAnchors: true),
              controller: controller,
              rootPuck: const ColoredBox(key: root, color: Colors.blue),
              puckItems: [
                for (final count in [4, 7, 12])
                  List.generate(count, (_) => const Text('Menu item')),
              ],
              layout: const PuckMenuLayout(levelRadius: 80),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final normal = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<PuckAnchorPainter>()
        .single;
    expect(find.byType(SpringPuck), findsNWidgets(23));
    rebuild(() => preview = true);
    await tester.pump();
    PuckLayoutPreviewPainter layout() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<PuckLayoutPreviewPainter>()
        .single;
    expect(layout().radii, normal.radii);
    expect(layout().arc, normal.arc);
    expect(layout().center, normal.center);
    expect(layout().itemDiameter, 48);
    expect(find.byType(SpringPuck), findsNothing);
    expect(find.text('Menu item'), findsNothing);

    final before = layout().center;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(root)),
    );
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-450, -100));
    await tester.pump();
    expect(layout().center.dx, lessThan(before.dx - 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(layout().center.dx, lessThan(40));
    expect(find.byType(SpringPuck), findsNothing);

    await tester.tap(find.byKey(root));
    await tester.pumpAndSettle();
    expect(controller.status, PuckMenuStatus.collapsed);
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter is PuckLayoutPreviewPainter),
      isEmpty,
    );
    await tester.tap(find.byKey(root));
    await tester.pumpAndSettle();
    expect(layout().radii, hasLength(3));
    expect(find.byType(SpringPuck), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
