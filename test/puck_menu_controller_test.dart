import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';

class _Listener implements PuckMenuListener {
  final calls = <String>[];
  final states = <PuckMenuStatus>[];
  void record(String call, PuckMenuController controller) {
    calls.add(call);
    states.add(controller.status);
  }

  @override
  void onExpanding(PuckMenuController c) => record('expanding', c);
  @override
  void onExpanded(PuckMenuController c) => record('expanded', c);
  @override
  void onCollapsing(PuckMenuController c) => record('collapsing', c);
  @override
  void onCollapsed(PuckMenuController c) => record('collapsed', c);
  @override
  void onDragStarted(PuckMenuController c) {
    expect(c.isDragging, isTrue);
    expect(c.isSettled, isFalse);
    record('dragStarted', c);
  }

  @override
  void onDragReleased(PuckMenuController c) {
    expect(c.isDragging, isFalse);
    expect(c.isSettled, isFalse);
    record('dragReleased', c);
  }

  @override
  void onSettled(PuckMenuController c) {
    expect(c.isDragging, isFalse);
    expect(c.isSettled, isTrue);
    record('settled', c);
  }
}

Widget _menu(PuckMenuController controller, {List<List<Widget>>? levels}) =>
    MaterialApp(
      home: PuckMenu.multiLevel(
        controller: controller,

        rootPuck: const ColoredBox(key: ValueKey('root'), color: Colors.blue),
        puckItems:
            levels ??
            [
              for (var level = 0; level < 3; level++)
                [ColoredBox(key: ValueKey(level), color: Colors.green)],
            ],
      ),
    );

void main() {
  testWidgets('resize finishes interrupted docking exactly once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = PuckMenuController();
    addTearDown(controller.dispose);
    final listener = _Listener();
    controller.addListener(listener);
    await tester.pumpWidget(_menu(controller));
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('root'))),
    );
    await drag.moveBy(const Offset(-30, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-120, 0));
    await tester.pump();
    await drag.up();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.binding.setSurfaceSize(const Size(600, 600));
    await tester.pumpAndSettle();
    expect(listener.calls, ['dragStarted', 'dragReleased', 'settled']);
    expect(controller.isSettled, isTrue);
  });

  testWidgets('commands and completion follow springs', (tester) async {
    final controller = PuckMenuController();
    addTearDown(controller.dispose);
    final listener = _Listener();
    controller.addListener(listener);
    await tester.pumpWidget(_menu(controller));
    await tester.pumpAndSettle();
    expect(controller.isAttached, isTrue);
    expect(controller.status, PuckMenuStatus.collapsed);
    expect(listener.calls, isEmpty);
    controller.open();
    controller.open();
    expect(listener.calls, ['expanding']);
    expect(controller.status, PuckMenuStatus.expanding);
    await tester.pump(const Duration(milliseconds: 80));
    expect(listener.calls, ['expanding']);
    await tester.pumpAndSettle();
    expect(listener.calls, ['expanding', 'expanded']);
    listener.calls.clear();
    controller.close();
    controller.open();
    await tester.pumpAndSettle();
    expect(listener.calls, ['collapsing', 'expanding', 'expanded']);
    listener.calls.clear();
    listener.states.clear();
    controller.close();
    controller.close();
    expect(controller.status, PuckMenuStatus.collapsing);
    await tester.pumpAndSettle();
    expect(listener.calls, ['collapsing', 'collapsed']);
    expect(listener.states, [
      PuckMenuStatus.collapsing,
      PuckMenuStatus.collapsed,
    ]);
    await tester.tap(find.byKey(const ValueKey('root')));
    await tester.pumpAndSettle();
    expect(listener.calls.skip(2), ['expanding', 'expanded']);
    controller.close();
    await tester.pumpAndSettle();
    listener.calls.clear();
    controller.open();
    controller.close();
    await tester.pumpAndSettle();
    expect(listener.calls, ['expanding', 'collapsing', 'collapsed']);
    await tester.pumpWidget(const SizedBox());
    expect(controller.isAttached, isFalse);
  });

  testWidgets('reversal cancels obsolete completion callbacks', (tester) async {
    final controller = PuckMenuController();
    addTearDown(controller.dispose);
    final listener = _Listener();
    controller.addListener(listener);
    await tester.pumpWidget(_menu(controller));
    controller.open();
    await tester.pump(const Duration(milliseconds: 70));
    controller.close();
    await tester.pump(const Duration(milliseconds: 16));
    controller.open();
    await tester.pumpAndSettle();
    expect(listener.calls, [
      'expanding',
      'collapsing',
      'expanding',
      'expanded',
    ]);
    listener.calls.clear();
    controller.close();
    await tester.pumpAndSettle();
    expect(listener.calls, ['collapsing', 'collapsed']);
  });

  testWidgets(
    'drag events distinguish taps, release, cancellation and settling',
    (tester) async {
      final controller = PuckMenuController();
      addTearDown(controller.dispose);
      final listener = _Listener();
      controller.addListener(listener);
      await tester.pumpWidget(_menu(controller));
      await tester.pumpAndSettle();
      final root = find.byKey(const ValueKey('root'));
      await tester.tap(root);
      await tester.pumpAndSettle();
      expect(listener.calls, ['expanding', 'expanded']);
      for (final cancel in [false, true]) {
        listener.calls.clear();
        final drag = await tester.startGesture(tester.getCenter(root));
        await drag.moveBy(const Offset(-30, 0));
        await tester.pump();
        await drag.moveBy(const Offset(-120, -40));
        await tester.pump();
        expect(listener.calls, ['dragStarted']);
        if (cancel) {
          await drag.cancel();
        } else {
          await drag.up();
        }
        expect(listener.calls, ['dragStarted', 'dragReleased']);
        await tester.pumpAndSettle();
        expect(listener.calls, ['dragStarted', 'dragReleased', 'settled']);
      }
    },
  );

  testWidgets('pre-attachment commands, replacement and listener removal', (
    tester,
  ) async {
    final first = PuckMenuController()..open();
    final second = PuckMenuController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final a = _Listener();
    final b = _Listener();
    first.addListener(a);
    second.addListener(b);
    await tester.pumpWidget(_menu(first));
    await tester.pumpAndSettle();
    expect(a.calls, ['expanding', 'expanded']);
    await tester.pumpWidget(_menu(second));
    await tester.pumpAndSettle();
    expect(first.isAttached, isFalse);
    expect(second.isAttached, isTrue);
    expect(b.calls, ['collapsing', 'collapsed']);
    first.close();
    second.removeListener(b);
    second.open();
    await tester.pumpAndSettle();
    expect(b.calls, ['collapsing', 'collapsed']);
    expect(second.status, PuckMenuStatus.expanded);
    await tester.pumpWidget(const SizedBox());
    second.close();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty menus complete exactly once; removed items cannot stall', (
    tester,
  ) async {
    final controller = PuckMenuController();
    addTearDown(controller.dispose);
    final listener = _Listener();
    controller.addListener(listener);
    await tester.pumpWidget(_menu(controller, levels: []));
    controller.open();
    controller.close();
    expect(listener.calls, [
      'expanding',
      'expanded',
      'collapsing',
      'collapsed',
    ]);
    listener.calls.clear();
    await tester.pumpWidget(_menu(controller));
    controller.open();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpWidget(_menu(controller, levels: []));
    await tester.pumpAndSettle();
    expect(listener.calls, ['expanding', 'expanded']);
    controller.close();
    await tester.pumpAndSettle();
    expect(listener.calls, [
      'expanding',
      'expanded',
      'collapsing',
      'collapsed',
    ]);
  });
}
