import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/puck_anchor_painter.dart';

void main() {
  testWidgets('single-level puckItems unfold continuously to a full ring', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = PuckMenuController()..open();
    addTearDown(controller.dispose);
    const root = ValueKey('root');
    await tester.pumpWidget(
      MaterialApp(
        home: PuckMenu.singleLevel(
          controller: controller,
          debug: const PuckMenuDebug(showAnchors: true),
          rootPuck: const ColoredBox(key: root, color: Colors.blue),
          puckItems: List.generate(8, (_) => const SizedBox()),
          layout: const PuckMenuLayout(levelRadius: 156),
        ),
      ),
    );
    await tester.pumpAndSettle();
    PuckAnchorPainter layout() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<PuckAnchorPainter>()
        .single;
    expect(layout().arc, isNotNull);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(root)),
    );
    await gesture.moveBy(const Offset(-25, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-25, 0));
    await tester.pump();
    await gesture.moveBy(Offset(201 - layout().center.dx, 0));
    await tester.pumpAndSettle();
    final ring = layout();
    expect(ring.center.dx, closeTo(201, 1e-6));
    expect(ring.radii, [156]);
    expect(ring.arc!.$2 - ring.arc!.$1, closeTo(2 * math.pi, 1e-7));
    final angles =
        ring.anchors
            .skip(1)
            .map((point) => (point - ring.center).direction)
            .toList()
          ..sort();
    for (var i = 0; i < angles.length; i++) {
      expect(
        (angles[(i + 1) % angles.length] - angles[i]) % (2 * math.pi),
        closeTo(2 * math.pi / 8, 1e-6),
      );
    }
    // No side-switch or seam rotation as the root crosses the midpoint.
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
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
