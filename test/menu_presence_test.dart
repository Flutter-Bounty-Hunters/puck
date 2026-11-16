import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';

const _rootKey = ValueKey('presence-root');

Widget _menu({required bool visible, PuckMenuController? controller}) =>
    MaterialApp(
      home: PuckMenu.singleLevel(
        visible: visible,
        controller: controller,
        rootPuck: const ColoredBox(key: _rootKey, color: Colors.blue),
        puckItems: const [Icon(Icons.message)],
      ),
    );

void main() {
  testWidgets(
    'root grows while held and springs gently past normal on release',
    (tester) async {
      await tester.pumpWidget(_menu(visible: true));
      await tester.pumpAndSettle();
      final root = find.byKey(_rootKey);
      final center = tester.getCenter(root);
      final press = await tester.startGesture(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getRect(root).width, closeTo(64 * 1.08, 0.01));
      expect((tester.getCenter(root) - center).distance, lessThan(0.000001));
      await press.up();
      await tester.pump();
      var undershot = false;
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        undershot |= tester.getRect(root).width < 64;
      }
      expect(undershot, isTrue);
      await tester.pumpAndSettle();
      expect(tester.getRect(root).width, closeTo(64, 0.02));
      expect((tester.getCenter(root) - center).distance, lessThan(0.000001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelled root presses and interrupted removal settle cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(_menu(visible: true));
    await tester.pumpAndSettle();
    final root = find.byKey(_rootKey);
    final press = await tester.startGesture(tester.getCenter(root));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await press.cancel();
    await tester.pumpAndSettle();
    expect(tester.getRect(root).width, closeTo(64, 0.02));
    final second = await tester.startGesture(tester.getCenter(root));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpWidget(_menu(visible: false));
    await second.up();
    await tester.pumpAndSettle();
    expect(root, findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('root pops in, overshoots, and anticipates shrinking away', (
    tester,
  ) async {
    final root = find.byKey(_rootKey);
    await tester.pumpWidget(_menu(visible: true));
    expect(tester.getRect(root).width, 0);
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.getRect(root).width, greaterThan(64));
    await tester.pumpAndSettle();
    expect(tester.getRect(root).width, closeTo(64, 0.01));
    final center = tester.getCenter(root);

    await tester.pumpWidget(_menu(visible: false));
    expect(root, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getRect(root).width, greaterThan(64));
    expect((tester.getCenter(root) - center).distance, lessThan(0.000001));
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getRect(root).width, lessThan(64));
    await tester.pumpAndSettle();
    expect(root, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rapid visibility changes reverse continuously and retain state',
    (tester) async {
      final controller = PuckMenuController();
      addTearDown(controller.dispose);
      final root = find.byKey(_rootKey);
      await tester.pumpWidget(_menu(visible: true, controller: controller));
      await tester.pumpAndSettle();
      await tester.drag(root, const Offset(-150, -100));
      await tester.pumpAndSettle();
      final center = tester.getCenter(root);
      controller.open();
      await tester.pumpAndSettle();
      await tester.pumpWidget(_menu(visible: false, controller: controller));
      await tester.pump(const Duration(milliseconds: 160));
      final width = tester.getRect(root).width;
      await tester.pumpWidget(_menu(visible: true, controller: controller));
      expect(tester.getRect(root).width, closeTo(width, 0.01));
      await tester.pumpAndSettle();
      expect((tester.getCenter(root) - center).distance, lessThan(0.000001));
      expect(tester.getRect(root).width, closeTo(64, 0.01));
      expect(controller.status, PuckMenuStatus.collapsed);

      await tester.pumpWidget(_menu(visible: false, controller: controller));
      await tester.pumpAndSettle();
      controller.open();
      await tester.pumpAndSettle();
      expect(root, findsNothing);
      await tester.pumpWidget(_menu(visible: true, controller: controller));
      await tester.pumpAndSettle();
      expect((tester.getCenter(root) - center).distance, lessThan(0.000001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initially hidden menus and disposal leave no animation running',
    (tester) async {
      await tester.pumpWidget(_menu(visible: false));
      await tester.pumpAndSettle();
      expect(find.byKey(_rootKey), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(_menu(visible: true));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
