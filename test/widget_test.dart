import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';

void main() {
  const puckKey = ValueKey('puck');
  Future<void> mount(WidgetTester tester, {VoidCallback? onTap}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PuckOverlay(
          onTap: onTap,
          puck: const ColoredBox(key: puckKey, color: Colors.blue),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  testWidgets('starts 10 percent offscreen and handles taps', (tester) async {
    var taps = 0;
    await mount(tester, onTap: () => taps++);
    expect(tester.getTopLeft(find.byKey(puckKey)).dx, closeTo(742.4, 0.01));
    await tester.tap(find.byKey(puckKey));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('drag releases to nearest left edge', (tester) async {
    await mount(tester);
    await tester.drag(find.byKey(puckKey), const Offset(-600, -100));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(puckKey)).dx, closeTo(-6.4, 0.01));
  });

  testWidgets('fling preserves vertical momentum and respects bottom', (
    tester,
  ) async {
    await mount(tester);
    await tester.fling(find.byKey(puckKey), const Offset(-100, 100), 1500);
    await tester.pump(const Duration(milliseconds: 16));
    final released = tester.getTopLeft(find.byKey(puckKey));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(find.byKey(puckKey)).dy, greaterThan(released.dy));
    await tester.pumpAndSettle();
    final position = tester.getTopLeft(find.byKey(puckKey));
    expect(position.dy, lessThanOrEqualTo(536));
    expect(position.dx, closeTo(742.4, 0.01));
  });

  testWidgets('top is a collision boundary during dragging', (tester) async {
    await mount(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(puckKey)),
    );
    await gesture.moveBy(const Offset(-20, -20));
    await gesture.moveBy(const Offset(-50, -1000));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(puckKey)).dy, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(puckKey)).dy, 0);
  });
}
