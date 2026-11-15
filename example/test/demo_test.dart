import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck_example/main.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/spring_puck.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:puck_example/layout_demo.dart';
import 'package:puck/src/puck_layout_preview_painter.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;
import 'package:puck/src/puck_anchor_storage.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Finder tab(String label) => find
    .descendant(of: find.byType(glass.GlassTabBar), matching: find.text(label))
    .first;

void main() {
  setUp(() {
    PuckAnchorStorage.resetCache();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'bottom tabs respect safe areas without moving pucks for a fitting keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const PuckDemo());
      await tester.pumpAndSettle();
      final bar = tester.getRect(find.byType(glass.GlassTabBar));
      expect(bar.center.dx, 201);
      expect(bar.bottom, lessThanOrEqualTo(840));
      expect(bar.width, lessThanOrEqualTo(320));
      final title = tester.widget<Text>(find.text('PUCK'));
      expect(title.style!.fontWeight, FontWeight.w900);
      expect(tester.getCenter(find.text('PUCK')).dx, 201);
      final contentIcon = find.descendant(
        of: find.bySemanticsLabel('Three menu circles'),
        matching: find.byIcon(Icons.bubble_chart),
      );
      expect(tester.widget<Icon>(contentIcon).size, 36);
      final root = tester.getCenter(find.byIcon(Icons.menu));
      final chat = tester.getCenter(find.byKey(const ValueKey('chat-root')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 335);
      tester.view.padding = const FakeViewPadding(top: 62);
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.byIcon(Icons.menu)), root);
      expect(tester.getCenter(find.byKey(const ValueKey('chat-root'))), chat);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.byIcon(Icons.menu)), root);
      for (final item in find.byType(SpringPuck).evaluate()) {
        expect(
          tester.getRect(find.byWidget(item.widget)).bottom,
          lessThanOrEqualTo(539.01),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('chat heads coexist with the tiered menu and Layout tab', (
    tester,
  ) async {
    await tester.pumpWidget(const PuckDemo());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('example-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-menu')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-root')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Chat with Maya'), findsOneWidget);
    await tester.tap(find.byTooltip('Chat with Maya'));
    await tester.pumpAndSettle();
    expect(find.text('Chatting with Maya'), findsOneWidget);
    await tester.tap(find.byTooltip('More conversations'));
    await tester.pumpAndSettle();
    expect(find.text('More conversations'), findsOneWidget);
    await tester.tap(find.byTooltip('Show debug visuals'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<PuckMenu>(find.byType(PuckMenu))
          .every((overlay) => overlay.debug.showAnchors),
      isTrue,
    );
    await tester.tap(tab('Layout'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-root')), findsNothing);
    expect(find.byType(MenuLayoutDemo), findsOneWidget);
    await tester.tap(tab('Puck'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Chat with Maya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout tab opens, preserves position, resets, and returns', (
    tester,
  ) async {
    await tester.pumpWidget(const PuckDemo());
    expect(find.byType(glass.GlassTabBar), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.bySemanticsLabel('Three menu circles'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(tab('Layout'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuLayoutDemo), findsOneWidget);
    expect(find.text('Menu layout'), findsOneWidget);
    expect(find.text('PUCK'), findsNothing);
    expect(find.byTooltip('Show keyboard'), findsNothing);
    expect(find.byType(SpringPuck), findsNothing);
    expect(find.byType(LiquidGlassLayer), findsNothing);
    PuckLayoutPreviewPainter layout() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<PuckLayoutPreviewPainter>()
        .single;
    final initial = layout().center;
    expect(layout().radii, hasLength(3));
    expect(layout().arc, isNotNull);
    await tester.drag(
      find.byKey(const ValueKey('layout-root')),
      const Offset(-500, -100),
    );
    await tester.pumpAndSettle();
    expect(layout().center.dx, lessThan(initial.dx));
    final dragged = layout().center;
    await tester.tap(tab('Puck'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuLayoutDemo), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Show keyboard'), findsOneWidget);
    expect(find.byTooltip('Reset layout'), findsNothing);
    await tester.tap(tab('Layout'));
    await tester.pumpAndSettle();
    expect(layout().center, dragged);
    await tester.tap(find.byTooltip('Reset layout'));
    await tester.pumpAndSettle();
    expect(layout().center, initial);
    await tester.tap(tab('Puck'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuLayoutDemo), findsNothing);
    expect(find.text('PUCK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the app is interactive immediately and never opens the menu for preparation',
    (tester) async {
      await tester.pumpWidget(const PuckDemo());
      expect(find.byType(MenuLayoutDemo, skipOffstage: false), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('menu-warmup-cover')), findsNothing);
      expect(
        tester
            .widget<PuckMenu>(find.byKey(const ValueKey('example-menu')))
            .controller,
        isNull,
      );
      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pump();
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
      await tester.tap(find.byTooltip('Show debug visuals'));
      await tester.pump();
      expect(find.byTooltip('Hide debug visuals'), findsOneWidget);
      expect(
        tester.getCenter(find.byTooltip('Show keyboard')).dx,
        lessThan(tester.getCenter(find.byTooltip('Hide debug visuals')).dx),
      );
      await tester.tap(find.byTooltip('Show keyboard'));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.byTooltip('Hide keyboard'));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byTooltip('Show keyboard'));
      await tester.pump();
      await tester.tap(tab('Layout'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(tab('Puck'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(SpringPuck, skipOffstage: false), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('removing an opening menu disposes its animations cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(const PuckDemo());
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump(const Duration(milliseconds: 8));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'floating menu builds above the app bar with required ancestors',
    (tester) async {
      await tester.pumpWidget(const PuckDemo());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      // Only the root layer exists while the menu is closed.
      expect(
        find.byType(LiquidGlassLayer, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(LiquidGlassLayer), findsOneWidget);
      final rootCenter = tester.getCenter(find.byIcon(Icons.menu));
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      // Each glass puck owns its layer, including the root.
      expect(find.byType(LiquidGlassLayer), findsNWidgets(24));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        (tester.getCenter(find.byKey(const ValueKey('Videos'))) - rootCenter)
            .distance,
        greaterThan(1),
      );
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Home'), findsOneWidget);
      final home = tester.element(find.byTooltip('Home'));
      expect(Overlay.maybeOf(home), isNotNull);
      expect(Material.maybeOf(home), isNotNull);
    },
  );
}
