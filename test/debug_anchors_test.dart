import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/puck_anchor_painter.dart';

final _visualizer = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is PuckAnchorPainter,
);

PuckAnchorPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_visualizer).painter! as PuckAnchorPainter;

void main() {
  testWidgets('anchor visualizer is disabled by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PuckOverlay(
          puck: ColoredBox(color: Colors.blue),
          child: SizedBox(),
        ),
      ),
    );
    expect(_visualizer, findsNothing);
  });

  testWidgets('dots mark spring targets and exclude unmounted menu items', (
    tester,
  ) async {
    const mainKey = ValueKey('main');
    const itemKey = ValueKey('item');
    await tester.pumpWidget(
      const MaterialApp(
        home: PuckOverlay(
          showDebugAnchors: true,
          puck: ColoredBox(key: mainKey, color: Colors.blue),
          menuItems: [ColoredBox(key: itemKey, color: Colors.green)],
          child: SizedBox(),
        ),
      ),
    );
    expect(_painter(tester).anchors, [tester.getCenter(find.byKey(mainKey))]);
    expect(
      _visualizer,
      paints..circle(radius: 3, color: const Color(0xFFFF0000)),
    );
    await tester.tap(find.byKey(mainKey));
    await tester.pump();
    final targets = _painter(tester).anchors;
    expect(targets, hasLength(2));
    // The dot immediately marks the destination, rather than following the
    // item during its spring animation.
    expect(
      (targets[1] - tester.getCenter(find.byKey(itemKey))).distance,
      greaterThan(50),
    );
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byKey(itemKey)), targets[1]);
    await tester.drag(find.byKey(mainKey), const Offset(-600, -100));
    await tester.pump();
    final moved = _painter(tester).anchors;
    expect(moved, isNot(targets));
    await tester.pumpAndSettle();
    final settled = _painter(tester).anchors;
    expect(settled[0], tester.getCenter(find.byKey(mainKey)));
    expect(settled[1], tester.getCenter(find.byKey(itemKey)));
    await tester.tap(find.byKey(mainKey));
    await tester.pumpAndSettle();
    expect(_painter(tester).anchors, hasLength(1));
  });
}
