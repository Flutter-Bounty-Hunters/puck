import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/spring_puck.dart';

class _Tracked extends StatefulWidget {
  const _Tracked({super.key, required this.onMount, required this.onDispose});
  final VoidCallback onMount;
  final VoidCallback onDispose;
  @override
  State<_Tracked> createState() => _TrackedState();
}

class _TrackedState extends State<_Tracked> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.green);
}

void main() {
  for (final diameter in [48.0, 64.0, 80.0]) {
    testWidgets('retained ${diameter}px items are hidden while closed', (
      tester,
    ) async {
      const root = ValueKey('root');
      const item = ValueKey('large');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckOverlay(
            maintainMenuState: true,
            menuItemDiameter: diameter,
            puck: const ColoredBox(key: root, color: Colors.blue),
            menuItems: const [ColoredBox(key: item, color: Colors.green)],
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(item), findsNothing);
      expect(find.byKey(item, skipOffstage: false), findsOneWidget);
      await tester.tap(find.byKey(root));
      await tester.pumpAndSettle();
      expect(find.byKey(item), findsOneWidget);
      await tester.tap(find.byKey(root));
      await tester.pumpAndSettle();
      expect(find.byKey(item), findsNothing);
    });
  }

  testWidgets(
    'maintained tier layers reuse prepared item state and stay inert when closed',
    (tester) async {
      var mounts = 0;
      var disposals = 0;
      const root = ValueKey('root');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckOverlay(
            maintainMenuState: true,
            menuTierBuilder: (context, tier, child) =>
                RepaintBoundary(key: ValueKey('tier-$tier'), child: child),
            puck: const ColoredBox(key: root, color: Colors.blue),
            menuTiers: [
              for (var tier = 0; tier < 2; tier++)
                [
                  for (var item = 0; item < 2; item++)
                    _Tracked(
                      key: ValueKey(tier * 2 + item),
                      onMount: () => mounts++,
                      onDispose: () => disposals++,
                    ),
                ],
            ],
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mounts, 4);
      expect(disposals, 0);
      expect(find.byKey(const ValueKey('tier-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('tier-1')), findsOneWidget);
      for (var round = 0; round < 3; round++) {
        expect(
          tester
              .widgetList<SpringPuck>(find.byType(SpringPuck))
              .every((puck) => !puck.expanded),
          isTrue,
        );
        final states = [
          for (var i = 0; i < 4; i++)
            tester.state(find.byKey(ValueKey(i), skipOffstage: false)),
        ];
        await tester.tap(find.byKey(root));
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<SpringPuck>(find.byType(SpringPuck))
              .every((puck) => puck.expanded),
          isTrue,
        );
        await tester.tap(find.byKey(root));
        await tester.pumpAndSettle();
        for (var i = 0; i < 4; i++) {
          expect(
            tester.state(find.byKey(ValueKey(i), skipOffstage: false)),
            same(states[i]),
          );
          expect(
            (tester.getCenter(find.byKey(ValueKey(i), skipOffstage: false)) -
                    tester.getCenter(find.byKey(root)))
                .distance,
            lessThan(8.001),
          );
        }
        expect(mounts, 4);
        expect(disposals, 0);
      }
      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(root)),
      );
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump();
      for (var step = 0; step < 5; step++) {
        await drag.moveBy(const Offset(-20, 10));
        await tester.pump(const Duration(milliseconds: 16));
        for (var i = 0; i < 4; i++) {
          expect(
            (tester.getCenter(find.byKey(ValueKey(i), skipOffstage: false)) -
                    tester.getCenter(find.byKey(root)))
                .distance,
            lessThan(0.001),
          );
        }
      }
      await drag.up();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(disposals, 4);
      expect(tester.takeException(), isNull);
    },
  );
}
