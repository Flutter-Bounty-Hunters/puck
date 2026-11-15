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
    testWidgets('$diameter px items mount on open and dispose after collapse', (
      tester,
    ) async {
      var mounts = 0;
      var disposals = 0;
      const root = ValueKey('root');
      const item = ValueKey('item');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckMenu.singleLevel(
            rootPuck: const ColoredBox(key: root, color: Colors.blue),
            puckItems: [
              _Tracked(
                key: item,
                onMount: () => mounts++,
                onDispose: () => disposals++,
              ),
            ],

            layout: PuckMenuLayout(puckDiameter: diameter),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mounts, 0);
      for (var round = 1; round <= 2; round++) {
        expect(find.byKey(item, skipOffstage: false), findsNothing);
        await tester.tap(find.byKey(root));
        await tester.pumpAndSettle();
        expect(mounts, round);
        expect(disposals, round - 1);
        expect(find.byKey(item), findsOneWidget);
        await tester.tap(find.byKey(root));
        await tester.pumpAndSettle();
        expect(find.byKey(item, skipOffstage: false), findsNothing);
        expect(disposals, round);
      }
    });
  }

  testWidgets(
    'multi-level items are absent while closed and recreated on open',
    (tester) async {
      var itemMounts = 0;
      var itemDisposals = 0;
      const root = ValueKey('root');
      await tester.pumpWidget(
        MaterialApp(
          home: PuckMenu.multiLevel(
            rootPuck: const ColoredBox(key: root, color: Colors.blue),
            puckItems: [
              for (var tier = 0; tier < 2; tier++)
                [
                  for (var item = 0; item < 2; item++)
                    _Tracked(
                      key: ValueKey(tier * 2 + item),
                      onMount: () => itemMounts++,
                      onDispose: () => itemDisposals++,
                    ),
                ],
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(itemMounts, 0);
      for (var round = 1; round <= 3; round++) {
        await tester.tap(find.byKey(root));
        await tester.pumpAndSettle();
        expect(itemMounts, 4 * round);
        expect(find.byType(SpringPuck), findsNWidgets(4));
        await tester.tap(find.byKey(root));
        await tester.pumpAndSettle();
        expect(itemDisposals, 4 * round);
        expect(find.byType(_Tracked, skipOffstage: false), findsNothing);
        expect(find.byType(SpringPuck, skipOffstage: false), findsNothing);
      }
      await tester.drag(find.byKey(root), const Offset(-200, -100));
      await tester.pumpAndSettle();
      expect(itemMounts, 12);
      expect(find.byType(_Tracked, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
