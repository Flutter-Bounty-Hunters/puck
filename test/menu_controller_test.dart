import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/spring_puck.dart';

void main() {
  for (final maintained in [false, true]) {
    testWidgets('first layout advances the spring (maintained: $maintained)', (
      tester,
    ) async {
      final expanded = ValueNotifier(false);
      addTearDown(expanded.dispose);
      const root = ValueKey('root');
      const item = ValueKey('item');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckOverlay(
            maintainMenuState: maintained,
            // Keep the early trajectory clear of the wall inset clamp.
            diameter: 128,
            menuExpanded: expanded,
            puck: const ColoredBox(key: root, color: Colors.blue),
            menuItems: const [ColoredBox(key: item, color: Colors.green)],
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var opening = 0; opening < 2; opening++) {
        final origin = tester.getCenter(find.byKey(root));
        expanded.value = true;
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
        expanded.value = false;
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tier delays start at the request and cancel on reversal', (
    tester,
  ) async {
    final expanded = ValueNotifier(false);
    addTearDown(expanded.dispose);
    const root = ValueKey('root');
    await tester.pumpWidget(
      MaterialApp(
        home: PuckOverlay(
          maintainMenuState: true,
          menuExpanded: expanded,
          puck: const ColoredBox(key: root, color: Colors.blue),
          menuTiers: [
            for (var tier = 0; tier < 3; tier++)
              [ColoredBox(key: ValueKey('tier-$tier'), color: Colors.green)],
          ],
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final origin = tester.getCenter(find.byKey(root));
    double distance(int tier) =>
        (tester.getCenter(
                  find.byKey(ValueKey('tier-$tier'), skipOffstage: false),
                ) -
                origin)
            .distance;
    expanded.value = true;
    await tester.pump(const Duration(milliseconds: 16));
    expect(distance(2), greaterThan(0));
    expect(distance(1), 0);
    expect(distance(0), 0);
    await tester.pump(const Duration(milliseconds: 42));
    expect(distance(1), greaterThan(0));
    expect(distance(0), 0);
    expanded.value = false;
    await tester.pumpAndSettle();
    for (var tier = 0; tier < 3; tier++) {
      expect(distance(tier), lessThan(8.001));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'programmatic expansion preserves tap semantics and can reverse a spring',
    (tester) async {
      final expanded = ValueNotifier(false);
      addTearDown(expanded.dispose);
      var taps = 0;
      const root = ValueKey('root');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckOverlay(
            maintainMenuState: true,
            menuExpanded: expanded,
            onTap: () => taps++,
            puck: const ColoredBox(key: root, color: Colors.blue),
            menuItems: const [ColoredBox(color: Colors.green)],
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expanded.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<SpringPuck>(find.byType(SpringPuck)).expanded,
        isTrue,
      );
      expect(taps, 0);
      expanded.value = false;
      await tester.pumpAndSettle();
      expect(
        tester.widget<SpringPuck>(find.byType(SpringPuck)).dormant,
        isTrue,
      );
      expect(taps, 0);
      await tester.tap(find.byKey(root));
      await tester.pumpAndSettle();
      expect(expanded.value, isTrue);
      expect(taps, 1);
      await tester.pumpWidget(const SizedBox());
      expanded.value = false;
      expect(tester.takeException(), isNull);
    },
  );
}
