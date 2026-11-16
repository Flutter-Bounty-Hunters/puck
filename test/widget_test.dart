import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';

void main() {
  testWidgets(
    'unclipped root decoration keeps circular touch target and drag',
    (tester) async {
      var backgroundTaps = 0;
      final controller = PuckMenuController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => backgroundTaps++,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
              PuckMenu.singleLevel(
                controller: controller,
                rootClipBehavior: Clip.none,
                rootPuck: const DecoratedBox(
                  key: ValueKey('decorated-root'),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white,
                        blurRadius: 20,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
                puckItems: const [ColoredBox(color: Colors.blue)],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final root = find.byKey(const ValueKey('decorated-root'));
      final initial = tester.getRect(root);
      await tester.tapAt(initial.topLeft + const Offset(3, 3));
      await tester.tapAt(initial.center - const Offset(70, 0));
      await tester.pumpAndSettle();
      expect(backgroundTaps, 2);
      expect(controller.status, PuckMenuStatus.collapsed);
      await tester.tap(root);
      await tester.pumpAndSettle();
      expect(controller.status, PuckMenuStatus.expanded);
      await tester.drag(root, const Offset(-250, 100));
      await tester.pumpAndSettle();
      expect(tester.getCenter(root).dy, greaterThan(initial.center.dy));
      expect(backgroundTaps, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('independent menu layers pass background touches through', (
    tester,
  ) async {
    var pageTaps = 0;
    var itemTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => pageTaps++,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
            for (final edge in PuckEdge.values)
              Positioned.fill(
                child: PuckMenu.singleLevel(
                  key: ValueKey(edge),
                  layout: PuckMenuLayout(initialEdge: edge),
                  rootPuck: ColoredBox(
                    key: ValueKey('root-$edge'),
                    color: Colors.blue,
                  ),
                  puckItems: [
                    GestureDetector(
                      key: ValueKey('item-$edge'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => itemTaps++,
                      child: const ColoredBox(color: Colors.green),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(400, 100));
    expect(pageTaps, 1);
    for (final edge in PuckEdge.values) {
      expect(
        find.ancestor(
          of: find.byKey(ValueKey(edge)),
          matching: find.byType(PuckMenu),
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(ValueKey('root-$edge')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('item-$edge')));
    }
    expect(itemTaps, 2);
    expect(pageTaps, 1);
    await tester.tapAt(const Offset(400, 100));
    expect(pageTaps, 2);
  });

  const puckKey = ValueKey('puck');
  Future<void> mount(
    WidgetTester tester, {
    PuckMenuController? controller,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PuckMenu.singleLevel(
          puckItems: const [],
          controller: controller,
          rootPuck: const ColoredBox(key: puckKey, color: Colors.blue),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts 10 percent offscreen and root taps toggle the menu', (
    tester,
  ) async {
    final controller = PuckMenuController();
    addTearDown(controller.dispose);
    await mount(tester, controller: controller);
    expect(tester.getTopLeft(find.byKey(puckKey)).dx, closeTo(742.4, 0.01));
    await tester.tap(find.byKey(puckKey));
    await tester.pumpAndSettle();
    expect(controller.status, PuckMenuStatus.expanded);
    await tester.tap(find.byKey(puckKey));
    await tester.pumpAndSettle();
    expect(controller.status, PuckMenuStatus.collapsed);
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
