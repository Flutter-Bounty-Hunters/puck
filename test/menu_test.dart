import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';

const _main = ValueKey('main');
Key _item(int index) => ValueKey('item-$index');

Future<void> _mount(
  WidgetTester tester, {
  double alignment = 0.5,
  int itemCount = 3,
  PuckEdge edge = PuckEdge.right,
  VoidCallback? onItemTap,
}) => tester.pumpWidget(
  MaterialApp(
    home: PuckOverlay(
      initialEdge: edge,
      initialVerticalAlignment: alignment,
      puck: const ColoredBox(key: _main, color: Colors.blue),
      menuItems: [
        for (var i = 0; i < itemCount; i++)
          GestureDetector(
            key: _item(i),
            onTap: onItemTap,
            child: const ColoredBox(color: Colors.green),
          ),
      ],
      child: const SizedBox.expand(),
    ),
  ),
);

void main() {
  for (final edge in PuckEdge.values) {
    testWidgets('children paint under $edge parent before moving', (
      tester,
    ) async {
      await _mount(tester, edge: edge);
      await tester.tap(find.byKey(_main));
      await tester.pump();
      final origin = tester.getCenter(find.byKey(_main));
      for (var i = 0; i < 3; i++) {
        expect(
          (tester.getCenter(find.byKey(_item(i))) - origin).distance,
          lessThan(0.000001),
        );
      }
      // The ticker's first frame establishes its time origin.
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        (tester.getCenter(find.byKey(_item(1))) - origin).distance,
        lessThan(0.000001),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        (tester.getCenter(find.byKey(_item(1))) - origin).distance,
        greaterThan(0),
      );
      await tester.pumpAndSettle();
    });
  }

  testWidgets('collapse disposes children as soon as the parent covers them', (
    tester,
  ) async {
    await _mount(tester, itemCount: 1);
    await tester.tap(find.byKey(_main));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_main));
    await tester.pump();
    final origin = tester.getCenter(find.byKey(_main));
    var elapsed = Duration.zero;
    while (find.byKey(_item(0)).evaluate().isNotEmpty &&
        elapsed < const Duration(seconds: 1)) {
      // The previous visible frame must still protrude past the parent.
      expect(
        (tester.getCenter(find.byKey(_item(0))) - origin).distance,
        greaterThan(8),
      );
      await tester.pump(const Duration(milliseconds: 16));
      elapsed += const Duration(milliseconds: 16);
    }
    expect(find.byKey(_item(0), skipOffstage: false), findsNothing);
    expect(elapsed, lessThan(const Duration(milliseconds: 600)));
    await tester.pumpAndSettle();
  });

  testWidgets('closing during the preparation frame cancels expansion', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.byKey(_main));
    await tester.pump();
    await tester.tap(find.byKey(_main));
    await tester.pumpAndSettle();
    expect(find.byKey(_item(0), skipOffstage: false), findsNothing);
    await tester.tap(find.byKey(_main));
    await tester.pump();
    expect(
      tester.getCenter(find.byKey(_item(0))),
      tester.getCenter(find.byKey(_main)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_item(0)).hitTestable(), findsOneWidget);
  });

  for (final edge in PuckEdge.values) {
    for (final count in [2, 3, 4]) {
      // At corners, three or more items cannot fit equal 24px clear gaps on
      // the fixed 112px radius. The existing corner tests verify the inset.
      for (final alignment in count == 2 ? [0.0, 0.5, 1.0] : [0.5]) {
        testWidgets(
          '$count items at $edge/$alignment have equal visible edge gaps',
          (tester) async {
            await _mount(
              tester,
              edge: edge,
              itemCount: count,
              alignment: alignment,
            );
            await tester.tap(find.byKey(_main));
            await tester.pumpAndSettle();
            final rects = [
              for (var i = 0; i < count; i++)
                tester.getRect(find.byKey(_item(i))),
            ];
            final clearGaps = [
              for (var i = 1; i < count; i++)
                (rects[i].center - rects[i - 1].center).distance - 48,
            ];
            // Compare actual circle-edge distances, not angles between centers.
            double boundaryGap(Rect rect) => [
              rect.left,
              800 - rect.right,
              rect.top,
              600 - rect.bottom,
            ].reduce(math.min);
            final gap = clearGaps.first;
            expect(gap, greaterThanOrEqualTo(24));
            for (final actual in [
              boundaryGap(rects.first),
              ...clearGaps,
              boundaryGap(rects.last),
            ]) {
              expect(actual, closeTo(gap, 0.1));
            }
          },
        );
      }
    }
  }

  testWidgets(
    'closed menu never mounts items, including after rebuilds and repeated toggles',
    (tester) async {
      var mounts = 0;
      var disposals = 0;
      var count = 3;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return PuckOverlay(
                puck: const ColoredBox(key: _main, color: Colors.blue),
                menuItems: [
                  for (var i = 0; i < count; i++)
                    _LifecyclePuck(
                      key: _item(i),
                      onMount: () => mounts++,
                      onDispose: () => disposals++,
                    ),
                ],
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(_LifecyclePuck, skipOffstage: false), findsNothing);
      expect(mounts, 0);
      await tester.drag(find.byKey(_main), const Offset(-100, 30));
      await tester.pumpAndSettle();
      expect(mounts, 0);
      for (var cycle = 0; cycle < 3; cycle++) {
        final before = mounts;
        await tester.tap(find.byKey(_main));
        await tester.pumpAndSettle();
        expect(mounts - before, count);
        expect(find.byType(_LifecyclePuck), findsNWidgets(count));
        await tester.tap(find.byKey(_main));
        await tester.pump();
        expect(find.byType(_LifecyclePuck), findsNWidgets(count));
        await tester.pumpAndSettle();
        expect(find.byType(_LifecyclePuck, skipOffstage: false), findsNothing);
        expect(disposals, mounts);
        rebuild(() => count++);
        await tester.pumpAndSettle();
        await tester.drag(find.byKey(_main), const Offset(-30, 10));
        await tester.pumpAndSettle();
        expect(mounts, before + count - 1);
        expect(find.byType(_LifecyclePuck, skipOffstage: false), findsNothing);
      }
    },
  );

  testWidgets('menu springs out, accepts taps, and returns beneath main puck', (
    tester,
  ) async {
    var taps = 0;
    await _mount(tester, onItemTap: () => taps++);
    await tester.pumpAndSettle();
    final origin = tester.getCenter(find.byKey(_main));
    expect(find.byKey(_item(1)), findsNothing);

    await tester.tap(find.byKey(_main));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final inFlight = tester.getCenter(find.byKey(_item(1)));
    await tester.pumpAndSettle();
    final expanded = tester.getCenter(find.byKey(_item(1)));
    expect((inFlight - expanded).distance, greaterThan(1));
    expect((expanded - origin).distance, closeTo(112, 0.1));
    await tester.tap(find.byKey(_item(1)));
    expect(taps, 1);

    await tester.tap(find.byKey(_main));
    await tester.pump();
    expect(find.byKey(_item(1)), findsOneWidget);
    expect(find.byKey(_item(1)).hitTestable(), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(_item(1)), findsNothing);
  });

  for (final edge in PuckEdge.values) {
    for (final alignment in [0.0, 1.0]) {
      testWidgets('menu stays visible at $edge, alignment $alignment', (
        tester,
      ) async {
        await _mount(tester, edge: edge, alignment: alignment);
        await tester.tap(find.byKey(_main));
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          final rect = tester.getRect(find.byKey(_item(i)));
          expect(rect.left, greaterThanOrEqualTo(24));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(776));
          expect(rect.bottom, lessThanOrEqualTo(600));
        }
      });
    }
  }

  testWidgets('open menu follows dragging and docking to the opposite edge', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.byKey(_main));
    await tester.pumpAndSettle();
    final before = tester.getCenter(find.byKey(_item(1)));
    await tester.drag(find.byKey(_main), const Offset(-650, -180));
    await tester.pumpAndSettle();
    final main = tester.getCenter(find.byKey(_main));
    final item = tester.getCenter(find.byKey(_item(1)));
    expect(main.dx, lessThan(50));
    expect(item.dx, greaterThan(main.dx));
    expect((item - main).distance, closeTo(112, 0.1));
    expect((item - before).distance, greaterThan(400));
  });

  testWidgets('reversing an in-flight menu settles without jumping', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.byKey(_main));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final before = tester.getCenter(find.byKey(_item(1)));
    await tester.tap(find.byKey(_main));
    await tester.pump();
    expect(tester.getCenter(find.byKey(_item(1))), before);
    await tester.pumpAndSettle();
    expect(find.byKey(_item(1)), findsNothing);
    await tester.tap(find.byKey(_main));
    await tester.pumpAndSettle();
    expect(find.byKey(_item(1)).hitTestable(), findsOneWidget);
  });
}

class _LifecyclePuck extends StatefulWidget {
  const _LifecyclePuck({
    super.key,
    required this.onMount,
    required this.onDispose,
  });
  final VoidCallback onMount;
  final VoidCallback onDispose;

  @override
  State<_LifecyclePuck> createState() => _LifecyclePuckState();
}

class _LifecyclePuckState extends State<_LifecyclePuck> {
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
