import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/src/puck_anchor_painter.dart';
import 'package:puck_example/main.dart';

final _visualizer = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is PuckAnchorPainter,
);

PuckAnchorPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_visualizer).painter! as PuckAnchorPainter;

void main() {
  testWidgets('example long press toggles dots without opening menu', (
    tester,
  ) async {
    await tester.pumpWidget(const PuckDemo());
    expect(_visualizer, findsNothing);
    await tester.longPress(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(_painter(tester).anchors, hasLength(1));
    expect(find.byIcon(Icons.home), findsNothing);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(_painter(tester).anchors, hasLength(4));
    await tester.longPress(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(_visualizer, findsNothing);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });
}
