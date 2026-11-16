import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;
import 'package:puck/puck.dart';
import 'package:puck/src/puck_anchor_storage.dart';
import 'package:puck_example/main.dart';
import 'package:puck_example/puck_root_light.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FirstRasterBinding extends AutomatedTestWidgetsFlutterBinding {
  Completer<void>? firstRaster;

  @override
  bool get firstFrameRasterized => firstRaster?.isCompleted ?? false;

  @override
  Future<void> get waitUntilFirstFrameRasterized =>
      (firstRaster ??= Completer<void>()).future;
}

void main() {
  final binding = _FirstRasterBinding();
  setUp(() {
    PuckAnchorStorage.resetCache();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Puck opens with one glass menu and Gallery follows it', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PuckDemo());
    // No renderer is created until an actual rasterized frame is reported.
    expect(find.byType(LiquidGlassLayer), findsNothing);
    final initialMenuState = tester.state(find.byType(PuckMenu));
    expect(find.byKey(const ValueKey('puck-controls-root')), findsOneWidget);
    binding.firstRaster!.complete();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(PuckMenu)), same(initialMenuState));
    final tabs = tester.widget<glass.GlassTabBar>(
      find.byType(glass.GlassTabBar),
    );
    expect(tabs.tabs.map((tab) => tab.label), [
      'Puck',
      'Gallery',
      'Layout',
      'Performance',
    ]);
    expect(find.text('PUCK'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('PUCK'))).brightness,
      Brightness.dark,
    );
    expect(find.byType(PuckMenu), findsOneWidget);
    final menu = tester.widget<PuckMenu>(find.byType(PuckMenu));
    expect(menu.layout.initialEdge, PuckEdge.right);
    expect(menu.layout.initialVerticalAlignment, 0.30);
    expect(find.byType(LiquidGlassLayer), findsOneWidget);
    expect(menu.puckItems.single, hasLength(9));
    expect(find.byType(Image), findsNothing);
    final lighting = tester.widget<PuckRootLight>(find.byType(PuckRootLight));
    final bubbleLight =
        lighting.primaryLightKey!.currentContext!.findRenderObject()!
            as RenderBox;
    expect(
      bubbleLight.localToGlobal(bubbleLight.size.center(Offset.zero)),
      tester.getCenter(find.byKey(const ValueKey('center-bubble-icon'))),
    );

    final anchored = lighting.additionalLights
        .map((anchor) => anchor.source)
        .toList();
    expect(anchored, hasLength(5));
    expect(anchored.every((source) => source != null), isTrue);
    expect(anchored.map((source) => source!.position).toSet(), hasLength(5));
    expect(anchored.first!.position, tester.getCenter(find.text('PUCK')));
    expect(
      anchored.skip(1).every((source) => source!.position.dy > 700),
      isTrue,
    );
    expect(anchored.every((source) => source!.intensity < 1), isTrue);

    final root = find.byKey(const ValueKey('puck-controls-root'));
    final bounds = tester.getRect(find.byType(PuckMenu));
    final center = tester.getCenter(root);
    expect(center.dx, greaterThan(bounds.center.dx));
    expect(
      center.dy,
      closeTo(bounds.top + 32 + (bounds.height - 64) * 0.30, 0.01),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('center-bubble-icon'))).dx,
      201,
    );
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('messenger-tap-demo')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass controls work and share settings with Gallery', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PuckDemo());
    await tester.pumpAndSettle();
    final root = find.byKey(const ValueKey('puck-controls-root'));
    await tester.tap(root);
    await tester.pumpAndSettle();
    for (final color in [
      'Red',
      'Orange',
      'Yellow',
      'Green',
      'Blue',
      'Violet',
      'Pink',
    ]) {
      expect(find.byTooltip('$color theme'), findsOneWidget);
    }
    expect(find.byTooltip('Switch to light mode'), findsNothing);
    expect(find.byTooltip('Switch to dark mode'), findsNothing);
    await tester.tap(find.byTooltip('Show debug visuals'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PuckMenu>(find.byType(PuckMenu)).debug.showAnchors,
      isTrue,
    );
    await tester.tap(find.byTooltip('Show keyboard'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.byTooltip('Hide keyboard'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.byTooltip('Blue theme'));
    await tester.pumpAndSettle();
    final page = find.byKey(const ValueKey('puck-page'));
    final background = tester.widget<Scaffold>(page).backgroundColor;
    await tester.drag(root, const Offset(-300, 120));
    await tester.pumpAndSettle();
    final position = tester.getCenter(root);
    Finder tab(String label) => find
        .descendant(
          of: find.byType(glass.GlassTabBar),
          matching: find.text(label),
        )
        .first;
    await tester.tap(tab('Gallery'));
    await tester.pumpAndSettle();
    expect(find.text('GALLERY'), findsOneWidget);
    expect(find.byTooltip('Switch to light mode'), findsOneWidget);
    expect(find.byTooltip('Hide debug visuals'), findsOneWidget);
    expect(
      tester
          .widget<Scaffold>(find.byKey(const ValueKey('example-page')))
          .backgroundColor,
      background,
    );
    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('GALLERY'))).brightness,
      Brightness.light,
    );
    await tester.tap(tab('Puck'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('PUCK'))).brightness,
      Brightness.dark,
    );
    expect(find.byTooltip('Switch to light mode'), findsNothing);
    expect(find.byTooltip('Switch to dark mode'), findsNothing);
    expect(tester.getCenter(root), position);
    expect(find.byTooltip('Blue theme'), findsOneWidget);
    await tester.tap(find.byTooltip('Blue theme'));
    await tester.pumpAndSettle();
    expect(tester.widget<Scaffold>(page).backgroundColor, isNot(background));
    expect(tester.takeException(), isNull);
  });
}
