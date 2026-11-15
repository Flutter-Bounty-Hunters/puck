import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/puck_anchor_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const root = ValueKey('root');
const storageKey = 'puck.anchor.v1.menu';
String saved(PuckEdge edge, double alignment) =>
    jsonEncode({'edge': edge.name, 'verticalAlignment': alignment});

final class DelayedPreferences extends InMemorySharedPreferencesAsync {
  DelayedPreferences() : super.empty();
  final read = Completer<String?>();
  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) =>
      read.future;
}

final class ControlledWrites extends InMemorySharedPreferencesAsync {
  ControlledWrites() : super.empty();
  final firstWrite = Completer<void>();
  int writes = 0;

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    if (++writes == 1) await firstWrite.future;
    return super.setString(key, value, options);
  }
}

final class FailingPreferences extends InMemorySharedPreferencesAsync {
  FailingPreferences() : super.empty();

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async => throw StateError('Storage unavailable');

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async => throw StateError('Storage unavailable');
}

void main() {
  setUp(() {
    PuckAnchorStorage.resetCache();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> mount(
    WidgetTester tester, {
    String? id = 'menu',
    bool multi = false,
  }) async {
    final menu = multi
        ? PuckMenu.multiLevel(
            id: id,
            rootPuck: const ColoredBox(key: root, color: Colors.blue),
            puckItems: const [[], []],
          )
        : PuckMenu.singleLevel(
            id: id,
            rootPuck: const ColoredBox(key: root, color: Colors.blue),
            puckItems: const [],
          );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(resizeToAvoidBottomInset: false, body: menu)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> move(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(root)),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-500, -100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('no ID never accesses preferences', (tester) async {
    SharedPreferencesAsyncPlatform.instance = null;
    await mount(tester, id: null);
    await move(tester);
    expect(tester.takeException(), isNull);
    expect(PuckAnchorStorage.cached('menu'), isNull);
  });

  for (final multi in [false, true]) {
    testWidgets('restores wall and proportional height (multi: $multi)', (
      tester,
    ) async {
      await SharedPreferencesAsync().setString(
        storageKey,
        saved(PuckEdge.left, .25),
      );
      await mount(tester, multi: multi);
      expect(tester.getTopLeft(find.byKey(root)), const Offset(-6.4, 134));
      expect(PuckAnchorStorage.cached('menu')!.verticalAlignment, .25);
    });
  }

  testWidgets('release persists the landing position before docking finishes', (
    tester,
  ) async {
    await mount(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(root)),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-500, -100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    final landing = PuckAnchorStorage.cached('menu')!;
    expect(landing.edge, PuckEdge.left);
    await tester.pumpWidget(const SizedBox());
    await mount(tester);
    expect(tester.getTopLeft(find.byKey(root)).dx, -6.4);
    expect(
      tester.getTopLeft(find.byKey(root)).dy,
      closeTo(536 * landing.verticalAlignment, .001),
    );

    await tester.pumpWidget(const SizedBox());
    final stored = await SharedPreferencesAsync().getString(storageKey);
    expect(jsonDecode(stored!)['edge'], 'left');
    PuckAnchorStorage.resetCache(); // Simulate losing process memory.
    await mount(tester);
    expect(
      tester.getTopLeft(find.byKey(root)).dy,
      closeTo(536 * landing.verticalAlignment, .001),
    );
  });

  testWidgets('restores proportionally into a different viewport', (
    tester,
  ) async {
    await SharedPreferencesAsync().setString(
      storageKey,
      saved(PuckEdge.left, .75),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.reset);
    await mount(tester);
    expect(tester.getTopLeft(find.byKey(root)).dy, (900 - 64) * .75);
  });

  for (final value in [
    'not json',
    '{}',
    '{"edge":"top","verticalAlignment":0.2}',
    '{"edge":"left","verticalAlignment":2}',
    '{"edge":"left","verticalAlignment":"0.2"}',
  ]) {
    testWidgets('invalid saved anchor falls back: $value', (tester) async {
      await SharedPreferencesAsync().setString(storageKey, value);
      await mount(tester);
      expect(tester.getTopLeft(find.byKey(root)), const Offset(742.4, 268));
      expect(await SharedPreferencesAsync().getString(storageKey), value);
    });
  }

  testWidgets('changing IDs restores the new anchor or its default', (
    tester,
  ) async {
    await SharedPreferencesAsync().setString(
      storageKey,
      saved(PuckEdge.left, .2),
    );
    await mount(tester);
    await mount(tester, id: 'other');
    expect(tester.getTopLeft(find.byKey(root)), const Offset(742.4, 268));
    await mount(tester);
    expect(tester.getTopLeft(find.byKey(root)).dx, -6.4);
    await mount(tester, id: null);
    expect(tester.getTopLeft(find.byKey(root)), const Offset(742.4, 268));
  });

  testWidgets('late storage cannot move a touched menu', (tester) async {
    final delayed = DelayedPreferences();
    SharedPreferencesAsyncPlatform.instance = delayed;
    await mount(tester);
    await tester.tap(find.byKey(root));
    await tester.pumpAndSettle();
    final position = tester.getTopLeft(find.byKey(root));
    delayed.read.complete(saved(PuckEdge.left, .1));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(root)), position);
  });

  testWidgets('late storage cannot override a different ID or disposed menu', (
    tester,
  ) async {
    final delayed = DelayedPreferences();
    SharedPreferencesAsyncPlatform.instance = delayed;
    await mount(tester);
    await mount(tester, id: null);
    delayed.read.complete(saved(PuckEdge.left, .1));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(root)).dx, 742.4);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard displacement never overwrites the user anchor', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final value = saved(PuckEdge.right, .9);
    await SharedPreferencesAsync().setString(storageKey, value);
    await mount(tester);
    final position = tester.getTopLeft(find.byKey(root));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(root)).dy, lessThan(position.dy));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(root)), position);
    expect(await SharedPreferencesAsync().getString(storageKey), value);
  });

  test('a save made during a read wins over old disk data', () async {
    final delayed = DelayedPreferences();
    SharedPreferencesAsyncPlatform.instance = delayed;
    final read = PuckAnchorStorage.read('menu');
    const newer = (edge: PuckEdge.right, verticalAlignment: .8);
    PuckAnchorStorage.save('menu', newer);
    delayed.read.complete(saved(PuckEdge.left, .1));
    expect(await read, newer);
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'writes are serialized so older saves cannot overwrite newer ones',
    () async {
      final preferences = ControlledWrites();
      SharedPreferencesAsyncPlatform.instance = preferences;
      PuckAnchorStorage.save('menu', (
        edge: PuckEdge.left,
        verticalAlignment: .1,
      ));
      PuckAnchorStorage.save('menu', (
        edge: PuckEdge.right,
        verticalAlignment: .8,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(preferences.writes, 1);
      preferences.firstWrite.complete();
      await Future<void>.delayed(Duration.zero);
      expect(preferences.writes, 2);
      PuckAnchorStorage.resetCache();
      expect(await PuckAnchorStorage.read('menu'), (
        edge: PuckEdge.right,
        verticalAlignment: .8,
      ));
    },
  );

  testWidgets('storage failures leave the menu usable', (tester) async {
    SharedPreferencesAsyncPlatform.instance = FailingPreferences();
    await mount(tester);
    await move(tester);
    expect(tester.getTopLeft(find.byKey(root)).dx, -6.4);
    expect(PuckAnchorStorage.cached('menu')!.edge, PuckEdge.left);
    expect(tester.takeException(), isNull);
  });
}
