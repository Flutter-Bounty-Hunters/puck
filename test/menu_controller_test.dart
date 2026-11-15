import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/spring_puck.dart';

void main() {
  testWidgets('first layout advances the spring', (tester) async {
    final controller = PuckMenuController();
    addTearDown(controller.dispose);
    const root = ValueKey('root');
    const item = ValueKey('item');
    await tester.pumpWidget(
      MaterialApp(
        home: PuckMenu.singleLevel(
          // Keep the early trajectory clear of the wall inset clamp.
          layout: const PuckMenuLayout(diameter: 128),
          controller: controller,
          rootPuck: const ColoredBox(key: root, color: Colors.blue),
          puckItems: const [ColoredBox(key: item, color: Colors.green)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var opening = 0; opening < 2; opening++) {
      final origin = tester.getCenter(find.byKey(root));
      controller.open();
      // Advance to the first layout after the request, without giving a
      // newly created ticker a subsequent frame to run in.
      await tester.pump(const Duration(milliseconds: 8));
      expect(
        (tester.getCenter(find.byKey(item)) - origin).distance,
        greaterThan(0.01),
      );
      final spring = tester.widget<SpringPuck>(find.byType(SpringPuck));
      final travel = (spring.target - spring.origin).distance;
      final simulation = SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 240, damping: 24),
        0,
        travel,
        0,
      );
      expect(
        (tester.getCenter(find.byKey(item)) - origin).distance,
        closeTo(simulation.x(0.008), 0.000001),
      );
      await tester.pump(const Duration(milliseconds: 16));
      // The ticker continues the same timeline, without counting the
      // initial catch-up twice or resetting to a zero-time first tick.
      expect(
        (tester.getCenter(find.byKey(item)) - origin).distance,
        closeTo(simulation.x(0.024), 0.000001),
      );
      await tester.pumpAndSettle();
      controller.close();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('level delays start at the request and cancel on reversal', (
    tester,
  ) async {
    final controller = PuckMenuController();
    addTearDown(controller.dispose);
    const root = ValueKey('root');
    await tester.pumpWidget(
      MaterialApp(
        home: PuckMenu.multiLevel(
          controller: controller,
          rootPuck: const ColoredBox(key: root, color: Colors.blue),
          puckItems: [
            for (var level = 0; level < 3; level++)
              [ColoredBox(key: ValueKey('level-$level'), color: Colors.green)],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final origin = tester.getCenter(find.byKey(root));
    double distance(int level) =>
        (tester.getCenter(
                  find.byKey(ValueKey('level-$level'), skipOffstage: false),
                ) -
                origin)
            .distance;
    controller.open();
    await tester.pump(const Duration(milliseconds: 16));
    expect(distance(2), greaterThan(0));
    expect(distance(1), 0);
    expect(distance(0), 0);
    await tester.pump(const Duration(milliseconds: 42));
    expect(distance(1), greaterThan(0));
    expect(distance(0), 0);
    controller.close();
    await tester.pumpAndSettle();
    for (var level = 0; level < 3; level++) {
      expect(
        find.byKey(ValueKey('level-$level'), skipOffstage: false),
        findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'controller commands reverse springs and root taps reopen the menu',
    (tester) async {
      final controller = PuckMenuController();
      addTearDown(controller.dispose);
      const root = ValueKey('root');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckMenu.singleLevel(
            controller: controller,
            rootPuck: const ColoredBox(key: root, color: Colors.blue),
            puckItems: const [ColoredBox(color: Colors.green)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<SpringPuck>(find.byType(SpringPuck)).expanded,
        isTrue,
      );
      controller.close();
      await tester.pumpAndSettle();
      expect(find.byType(SpringPuck, skipOffstage: false), findsNothing);
      await tester.tap(find.byKey(root));
      await tester.pumpAndSettle();
      expect(controller.status, PuckMenuStatus.expanded);
      await tester.pumpWidget(const SizedBox());
      controller.close();
      expect(tester.takeException(), isNull);
    },
  );
}
