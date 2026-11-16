import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck_example/main.dart';
import 'package:puck_example/performance_monitor_menu.dart';
import 'package:puck_example/menu_root_puck.dart';
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

Future<void> mountMenus(WidgetTester tester) async {
  await tester.pumpWidget(const PuckDemo());
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Show messenger menu'));
  await tester.tap(find.byTooltip('Show massive menu'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    PuckAnchorStorage.resetCache();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'activation buttons pop in clockwise once and keep the bubble visible',
    (tester) async {
      await tester.pumpWidget(const PuckDemo());
      final buttons = [
        find.byKey(const ValueKey('messenger-menu-toggle')),
        find.byKey(const ValueKey('art-menu-toggle')),
        find.byKey(const ValueKey('massive-menu-toggle')),
        find.byKey(const ValueKey('performance-menu-toggle')),
        find.byKey(const ValueKey('dev-menu-toggle')),
      ];
      expect(find.bySemanticsLabel('Three menu circles'), findsOneWidget);
      for (final button in buttons) {
        expect(button, findsNothing);
      }
      await tester.pump(const Duration(milliseconds: 180));
      for (var index = 0; index < buttons.length; index++) {
        for (var other = 0; other < buttons.length; other++) {
          expect(
            buttons[other],
            other <= index ? findsOneWidget : findsNothing,
          );
        }
        if (index == 1) {
          expect(tester.getRect(buttons.first).width, greaterThan(56));
        }
        await tester.pump(const Duration(milliseconds: 140));
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-root')), findsNothing);
      await tester.tap(tab('Layout'));
      await tester.pumpAndSettle();
      await tester.tap(tab('Puck'));
      await tester.pump();
      for (final button in buttons) {
        expect(button, findsOneWidget);
        expect(tester.getRect(button).width, closeTo(56, 0.01));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fresh launch demonstrates one collapsed Messenger activation', (
    tester,
  ) async {
    await tester.pumpWidget(const PuckDemo());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-root')), findsNothing);
    expect(find.byKey(const ValueKey('art-root')), findsNothing);
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.byTooltip('Show messenger menu'), findsOneWidget);
    expect(find.byTooltip('Show art menu'), findsOneWidget);
    expect(find.byTooltip('Show massive menu'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('messenger-tap-demo')), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('messenger-tap-demo')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-root')), findsNothing);
    await tester.pump();
    final pointer = find.byKey(const ValueKey('messenger-tap-demo'));
    final start = tester.getTopLeft(pointer);
    await tester.pump(const Duration(milliseconds: 160));
    final fastPosition = tester.getTopLeft(pointer);
    await tester.pump(const Duration(milliseconds: 160));
    final nearPosition = tester.getTopLeft(pointer);
    await tester.pump(const Duration(milliseconds: 280));
    final target = tester.getTopLeft(pointer);
    expect((start - target).distance, greaterThan(90));
    expect((fastPosition - target).distance, lessThan(35));
    expect((nearPosition - target).distance, lessThan(15));
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getTopLeft(pointer), target);
    expect(find.byKey(const ValueKey('chat-root')), findsNothing);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 120));
    final button = find.descendant(
      of: find.byKey(const ValueKey('messenger-menu-toggle')),
      matching: find.byType(IconButton),
    );
    expect(tester.getRect(button).width, lessThan(56));
    expect(find.byKey(const ValueKey('chat-root')), findsNothing);
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.byKey(const ValueKey('chat-root')), findsOneWidget);
    expect(tester.widget<Opacity>(pointer).opacity, 1);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getRect(button).width, closeTo(56, 0.01));
    expect(tester.widget<Opacity>(pointer).opacity, lessThan(1));
    await tester.pumpAndSettle();
    expect(pointer, findsNothing);
    expect(find.byKey(const ValueKey('chat-root')), findsOneWidget);
    expect(find.byTooltip('Chat with Maya'), findsNothing);
    expect(find.byKey(const ValueKey('art-root')), findsNothing);
    expect(find.byIcon(Icons.menu), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byTooltip('Hide messenger menu'), findsOneWidget);
  });

  testWidgets('manual activation cancels the launch demonstration', (
    tester,
  ) async {
    await tester.pumpWidget(const PuckDemo());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show art menu'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('messenger-tap-demo')), findsNothing);
    expect(find.byKey(const ValueKey('chat-root')), findsNothing);
    expect(find.byKey(const ValueKey('art-root')), findsOneWidget);
    expect(find.byTooltip('Red theme'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a real tap interrupts the moving pointer without a second activation',
    (tester) async {
      await tester.pumpWidget(const PuckDemo());
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('messenger-tap-demo')), findsOneWidget);
      await tester.tap(find.byTooltip('Show messenger menu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('messenger-tap-demo')), findsNothing);
      await tester.tap(find.byTooltip('Hide messenger menu'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('chat-root')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving Puck or disposing cancels a pending demonstration', (
    tester,
  ) async {
    await tester.pumpWidget(const PuckDemo());
    await tester.pumpAndSettle();
    await tester.tap(tab('Layout'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(tab('Puck'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-root')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const PuckDemo());
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('messenger-tap-demo')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bottom tabs respect safe areas without moving pucks for a fitting keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.reset);
      await mountMenus(tester);
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

  testWidgets('radial messenger toggle hides and restores the chat menu', (
    tester,
  ) async {
    await mountMenus(tester);
    await tester.pumpAndSettle();
    final bubble = find.bySemanticsLabel('Three menu circles');
    final center = tester.getCenter(bubble);
    final messenger = find.byTooltip('Hide messenger menu');
    final top = tester.getCenter(messenger);
    expect(top.dx, closeTo(center.dx, 0.01));
    expect(top.dy, closeTo(center.dy - 88, 0.01));
    expect(
      (tester.getCenter(find.byKey(const ValueKey('dev-menu-toggle'))) - center)
          .distance,
      closeTo(88, 0.01),
    );
    await tester.tap(find.byKey(const ValueKey('chat-root')));
    await tester.pumpAndSettle();
    await tester.tap(messenger);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-root')), findsNothing);
    expect(find.byTooltip('Chat with Maya'), findsNothing);
    expect(find.byKey(const ValueKey('example-menu')), findsOneWidget);
    expect(tester.getCenter(bubble), center);
    await tester.tap(tab('Layout'));
    await tester.pumpAndSettle();
    await tester.tap(tab('Puck'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-root')), findsNothing);
    await tester.tap(find.byTooltip('Show messenger menu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-root')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-root')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Chat with Maya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'activation buttons show active state and compress while pressed',
    (tester) async {
      await mountMenus(tester);
      await tester.pumpAndSettle();
      for (final id in [
        'messenger-menu-toggle',
        'art-menu-toggle',
        'massive-menu-toggle',
        'performance-menu-toggle',
        'dev-menu-toggle',
      ]) {
        final button = find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.byType(IconButton),
        );
        IconButton current() => tester.widget<IconButton>(button);
        Color fill() => current().style!.backgroundColor!.resolve(
          current().statesController!.value,
        )!;
        final active = current().isSelected;
        final restingFill = fill();
        final restingSize = tester.getRect(button).size;
        final press = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 120));
        expect(
          current().statesController!.value,
          contains(WidgetState.pressed),
        );
        expect(fill(), isNot(restingFill));
        expect(
          tester.getRect(button).width,
          lessThan(restingSize.width * 0.95),
        );
        expect(current().isSelected, active);
        await press.up();
        await tester.pumpAndSettle();
        expect(current().isSelected, !active!);
        expect(
          find.descendant(
            of: find.byKey(ValueKey(id)),
            matching: find.byKey(const ValueKey('active-menu-ring')),
          ),
          !active ? findsOneWidget : findsNothing,
        );
        expect(tester.getRect(button).size, restingSize);
        expect(
          current().statesController!.value,
          isNot(contains(WidgetState.pressed)),
        );

        final cancel = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 120));
        await cancel.cancel();
        await tester.pumpAndSettle();
        expect(current().isSelected, !active);
        expect(tester.getRect(button).size, restingSize);
      }
      expect(find.byKey(const ValueKey('art-root')), findsOneWidget);
      expect(find.byTooltip('Red theme'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'active rings have a gap and follow brightness and accent color',
    (tester) async {
      await mountMenus(tester);
      final rings = find.byKey(const ValueKey('active-menu-ring'));
      void expectRingColors(Color color) {
        for (final box in tester.widgetList<DecoratedBox>(rings)) {
          final border = (box.decoration as BoxDecoration).border! as Border;
          expect(border.top.color, color);
        }
      }

      expect(rings, findsNWidgets(2));
      expectRingColors(const Color(0xFFD1D5DB));
      for (final id in ['messenger-menu-toggle', 'massive-menu-toggle']) {
        final parent = find.byKey(ValueKey(id));
        final ring = find.descendant(of: parent, matching: rings);
        final button = find.descendant(
          of: parent,
          matching: find.byType(IconButton),
        );
        final ringRect = tester.getRect(ring);
        final buttonRect = tester.getRect(button);
        expect(ringRect.center, buttonRect.center);
        expect((ringRect.width - buttonRect.width) / 2 - 2, closeTo(4, 0.01));
      }
      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pumpAndSettle();
      expectRingColors(const Color(0xFFD1D5DB));
      await tester.tap(find.byTooltip('Show art menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('art-root')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Blue theme'));
      await tester.pumpAndSettle();
      expect(rings, findsNWidgets(3));
      expectRingColors(const Color(0xFF3485FF));
      await tester.tap(find.byTooltip('Blue theme'));
      await tester.pumpAndSettle();
      expectRingColors(const Color(0xFFD1D5DB));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'activation colors fade through intermediate colors in both modes',
    (tester) async {
      await mountMenus(tester);
      final parent = find.byKey(const ValueKey('performance-menu-toggle'));
      Color fill() => tester
          .widget<IconButton>(
            find.descendant(of: parent, matching: find.byType(IconButton)),
          )
          .style!
          .backgroundColor!
          .resolve({})!;
      Color icon() => tester
          .widget<Icon>(
            find.descendant(
              of: parent,
              matching: find.byIcon(Icons.speed_rounded),
            ),
          )
          .color!;
      const light = Color(0xFFE5E7EB);
      const dark = Color(0xFF29292E);
      for (final toDark in [true, false]) {
        final before = fill();
        final beforeIcon = icon();
        final target = toDark ? dark : light;
        final targetIcon = toDark
            ? const Color(0xFFD1D5DB)
            : performancePuckColor;
        await tester.tap(
          find.byTooltip(
            toDark ? 'Switch to dark mode' : 'Switch to light mode',
          ),
        );
        final fills = <Color>[];
        final icons = <Color>[];
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 40));
          fills.add(fill());
          icons.add(icon());
        }
        await tester.pumpAndSettle();
        expect(fills.any((c) => c != before && c != target), isTrue);
        expect(icons.any((c) => c != beforeIcon && c != targetIcon), isTrue);
        expect(fill(), target);
        expect(icon(), targetIcon);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'art menu selects one tint and restores monochrome in both modes',
    (tester) async {
      await mountMenus(tester);
      await tester.pumpAndSettle();
      Color background() => tester
          .widget<Scaffold>(find.byKey(const ValueKey('example-page')))
          .backgroundColor!;
      ThemeData theme() =>
          Theme.of(tester.element(find.byKey(const ValueKey('example-page'))));
      final originalPrimary = theme().colorScheme.primary;
      expect(background(), Colors.white);
      expect(find.byKey(const ValueKey('art-root')), findsNothing);
      final bubbleCenter = tester.getCenter(
        find.bySemanticsLabel('Three menu circles'),
      );
      final artCenter = tester.getCenter(find.byTooltip('Show art menu'));
      expect(artCenter.dx, greaterThan(bubbleCenter.dx));
      expect(artCenter.dy, lessThan(bubbleCenter.dy));
      expect((artCenter - bubbleCenter).distance, closeTo(88, 0.01));
      await tester.tap(find.byTooltip('Show art menu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('art-root')), findsOneWidget);
      expect(find.byTooltip('Red theme'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('art-root')));
      await tester.pumpAndSettle();
      final artMenu = tester.widget<PuckMenu>(
        find.byKey(const ValueKey('art-menu')),
      );
      expect(
        artMenu.puckItems.single.first.key,
        const ValueKey('art-brightness'),
      );
      expect(artMenu.puckItems.single, hasLength(8));
      IconButton swatch(String name) => tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(ValueKey('theme-$name')),
          matching: find.byType(IconButton),
        ),
      );
      LiquidGlass swatchGlass(String name) => tester.widget<LiquidGlass>(
        find
            .descendant(
              of: find.byKey(ValueKey('theme-$name')),
              matching: find.byType(LiquidGlass),
            )
            .first,
      );
      final inactiveAlpha = swatchGlass('Red').appearance!.tint.a;
      await tester.tap(find.byTooltip('Red theme'));
      await tester.pumpAndSettle();
      expect(swatch('Red').isSelected, isTrue);
      expect(swatchGlass('Red').appearance!.tint.a, greaterThan(inactiveAlpha));
      expect(theme().colorScheme.primary, isNot(originalPrimary));
      expect(background(), isNot(Colors.white));
      final redPrimary = theme().colorScheme.primary;
      await tester.tap(find.byTooltip('Blue theme'));
      await tester.pumpAndSettle();
      expect(swatch('Red').isSelected, isFalse);
      expect(swatch('Blue').isSelected, isTrue);
      expect(theme().colorScheme.primary, isNot(redPrimary));
      await tester.tap(find.byTooltip('Blue theme'));
      await tester.pumpAndSettle();
      expect(swatch('Blue').isSelected, isFalse);
      expect(background(), Colors.white);
      expect(theme().colorScheme.primary, originalPrimary);
      await tester.tap(find.byTooltip('Art: switch to dark mode'));
      await tester.pumpAndSettle();
      expect(theme().brightness, Brightness.dark);
      expect(background(), const Color(0xFF111114));
      await tester.tap(find.byTooltip('Violet theme'));
      await tester.pumpAndSettle();
      expect(background(), isNot(const Color(0xFF111114)));
      await tester.tap(find.byTooltip('Hide art menu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('art-root')), findsNothing);
      final tintedBackground = background();
      await tester.tap(tab('Layout'));
      await tester.pumpAndSettle();
      await tester.tap(tab('Puck'));
      await tester.pumpAndSettle();
      expect(background(), tintedBackground);
      await tester.tap(find.byTooltip('Show art menu'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Violet theme'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('art-root')));
      await tester.pumpAndSettle();
      expect(swatch('Violet').isSelected, isTrue);
      await tester.tap(find.byTooltip('Violet theme'));
      await tester.pumpAndSettle();
      expect(background(), const Color(0xFF111114));
      await tester.tap(find.byTooltip('Art: switch to light mode'));
      await tester.pumpAndSettle();
      expect(background(), Colors.white);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'third radial button toggles the massive menu without opening it',
    (tester) async {
      await mountMenus(tester);
      await tester.pumpAndSettle();
      final center = tester.getCenter(
        find.bySemanticsLabel('Three menu circles'),
      );
      final button = find.byTooltip('Hide massive menu');
      final position = tester.getCenter(button);
      expect(position.dx, greaterThan(center.dx));
      expect(position.dy, greaterThan(center.dy));
      expect((position - center).distance, closeTo(88, 0.01));
      expect(find.byIcon(Icons.account_tree_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Home'), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.byTooltip('Home'), findsNothing);
      expect(find.byKey(const ValueKey('chat-root')), findsOneWidget);
      await tester.tap(find.byTooltip('Show massive menu'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byTooltip('Home'), findsNothing);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fourth button shows dark performance meters and massive root is orange',
    (tester) async {
      await mountMenus(tester);
      final center = tester.getCenter(
        find.bySemanticsLabel('Three menu circles'),
      );
      final button = find.byTooltip('Show performance menu');
      final position = tester.getCenter(button);
      expect(position.dx, lessThan(center.dx));
      expect(position.dy, greaterThan(center.dy));
      expect((position - center).distance, closeTo(88, 0.01));
      final massive = tester.widget<PuckMenu>(
        find.byKey(const ValueKey('example-menu')),
      );
      expect(
        ((massive.rootPuck as MenuRootPuck).child as Material).color,
        const Color(0xFFFF8500),
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('performance-root')), findsOneWidget);
      expect(find.byKey(const ValueKey('performance-ui')), findsNothing);
      expect(find.byIcon(Icons.speed_rounded), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('performance-root')));
      await tester.pumpAndSettle();
      for (final id in [
        'ui',
        'raster',
        'latency',
        'vsync',
        'jank',
        'memory',
        'images',
      ]) {
        final puck = find.byKey(ValueKey('performance-$id'));
        expect(puck, findsOneWidget);
        final material = tester.widget<Material>(
          find.descendant(of: puck, matching: find.byType(Material)),
        );
        expect(material.color, performancePuckColor);
        expect(
          find.descendant(
            of: puck,
            matching: find.byKey(const ValueKey('performance-meter')),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(tab('Layout'));
      await tester.pumpAndSettle();
      await tester.tap(tab('Puck'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('performance-ui')), findsOneWidget);
      await tester.tap(find.byTooltip('Hide performance menu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('performance-root')), findsNothing);
      expect(find.byKey(const ValueKey('performance-ui')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dev menu shares light mode, keyboard, and layout guide controls',
    (tester) async {
      await mountMenus(tester);
      final center = tester.getCenter(
        find.bySemanticsLabel('Three menu circles'),
      );
      final button = find.byTooltip('Show dev menu');
      final position = tester.getCenter(button);
      expect(position.dx, lessThan(center.dx));
      expect(position.dy, lessThan(center.dy));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dev-root')), findsOneWidget);
      expect(find.byKey(const ValueKey('dev-brightness')), findsNothing);
      expect(
        tester
            .widget<Material>(
              find.descendant(
                of: find.byKey(const ValueKey('dev-root')),
                matching: find.byType(Material),
              ),
            )
            .color,
        const Color(0xFFB6FF00),
      );
      await tester.tap(find.byKey(const ValueKey('dev-root')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dev: switch to dark mode'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
      final modePuck = find.byKey(const ValueKey('dev-brightness'));
      expect(
        tester
            .widget<Material>(
              find
                  .descendant(of: modePuck, matching: find.byType(Material))
                  .first,
            )
            .color,
        const Color(0xFFB6FF00),
      );
      final modeButton = tester.widget<IconButton>(
        find.descendant(of: modePuck, matching: find.byType(IconButton)),
      );
      expect(
        modeButton.style!.backgroundColor!.resolve({WidgetState.selected}),
        Colors.transparent,
      );
      final perfIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('performance-menu-toggle')),
          matching: find.byIcon(Icons.speed_rounded),
        ),
      );
      expect(perfIcon.color, const Color(0xFFD1D5DB));
      final bubble = find.descendant(
        of: find.bySemanticsLabel('Three menu circles'),
        matching: find.byIcon(Icons.bubble_chart),
      );
      expect(
        tester.widget<Icon>(bubble).color,
        Theme.of(tester.element(bubble)).colorScheme.primary,
      );

      await tester.tap(find.byTooltip('Dev: show keyboard'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.byTooltip('Hide keyboard'), findsOneWidget);
      await tester.tap(find.byTooltip('Dev: hide keyboard'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byTooltip('Dev: show layout guides'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide debug visuals'), findsOneWidget);
      expect(
        tester
            .widgetList<PuckMenu>(find.byType(PuckMenu))
            .every((menu) => menu.debug.showAnchors),
        isTrue,
      );
      await tester.tap(find.byTooltip('Hide debug visuals'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Dev: show layout guides'), findsOneWidget);
      await tester.tap(find.byTooltip('Dev: switch to light mode'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
      await tester.tap(find.byTooltip('Hide dev menu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dev-root')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'revised default column has equal gaps despite legacy saved anchors',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.reset);
      for (final (index, id) in [
        'demo-chat',
        'demo-art',
        'demo-puck',
        'demo-performance',
        'demo-dev',
      ].indexed) {
        PuckAnchorStorage.save(id, (
          edge: PuckEdge.left,
          verticalAlignment: [0.1, 0.7, 0.4, 0.95, 0.2][index],
        ));
      }
      await mountMenus(tester);
      for (final name in ['art', 'performance', 'dev']) {
        await tester.tap(find.byTooltip('Show $name menu'));
        await tester.pumpAndSettle();
      }
      final roots = [
        find.byKey(const ValueKey('chat-root')),
        find.byKey(const ValueKey('art-root')),
        find.byIcon(Icons.menu),
        find.byKey(const ValueKey('performance-root')),
        find.byKey(const ValueKey('dev-root')),
      ];
      final centers = roots.map(tester.getCenter).toList();
      final gap = centers[1].dy - centers[0].dy;
      expect(gap, greaterThan(0));
      final bounds = tester.getRect(find.byKey(const ValueKey('chat-menu')));
      expect(gap, closeTo((bounds.height - 64) * 0.15, 0.01));
      expect(
        centers.first.dy,
        closeTo(bounds.top + 32 + (bounds.height - 64) * 0.25, 0.01),
      );
      for (var index = 0; index < centers.length; index++) {
        expect(centers[index].dx, closeTo(centers.first.dx, 0.01));
        expect(centers[index].dx, greaterThan(350));
        expect(
          centers[index].dy,
          closeTo(centers.first.dy + index * gap, 0.01),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'theme glass shares one on-demand layer and survives overlapping movement',
    (tester) async {
      await mountMenus(tester);
      expect(find.byType(LiquidGlassLayer), findsNothing);
      await tester.tap(find.byTooltip('Show art menu'));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidGlassLayer), findsNothing);
      await tester.tap(find.byKey(const ValueKey('art-root')));
      await tester.pump();
      expect(find.byType(LiquidGlassLayer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 32));
      expect(find.byType(LiquidGlassLayer), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidGlass), findsNWidgets(8));
      await tester.tap(find.byTooltip('Pink theme'));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidGlassLayer), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('art-root')));
      await tester.pump();
      expect(find.byType(LiquidGlassLayer), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidGlassLayer), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'most recently activated or opened menu paints above the others',
    (tester) async {
      await mountMenus(tester);
      Stack overlays() => tester.widget<Stack>(
        find.byKey(const ValueKey('puck-menu-overlays')),
      );
      expect(overlays().children.last.key, const ValueKey('example-menu'));
      await tester.tap(find.byKey(const ValueKey('chat-root')));
      await tester.pumpAndSettle();
      expect(overlays().children.last.key, const ValueKey('chat-menu'));
      final chatState = tester.state(find.byKey(const ValueKey('chat-menu')));
      tester
          .widget<PuckMenu>(find.byKey(const ValueKey('example-menu')))
          .controller!
          .open();
      await tester.pumpAndSettle();
      expect(overlays().children.last.key, const ValueKey('example-menu'));
      expect(
        tester.state(find.byKey(const ValueKey('chat-menu'))),
        same(chatState),
      );
      await tester.tap(find.byTooltip('Show art menu'));
      await tester.pumpAndSettle();
      expect(overlays().children.last.key, const ValueKey('art-menu'));
      await tester.tap(find.byKey(const ValueKey('art-root')));
      await tester.pumpAndSettle();
      expect(overlays().children.last.key, const ValueKey('art-menu'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('chat heads coexist with the leveled menu and Layout tab', (
    tester,
  ) async {
    await mountMenus(tester);
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
    await mountMenus(tester);
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
      await mountMenus(tester);
      expect(find.byType(MenuLayoutDemo, skipOffstage: false), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('menu-warmup-cover')), findsNothing);
      expect(
        tester
            .widget<PuckMenu>(find.byKey(const ValueKey('example-menu')))
            .controller,
        isNotNull,
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
    await mountMenus(tester);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump(const Duration(milliseconds: 8));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'massive menu uses solid colors per level and keeps required ancestors',
    (tester) async {
      await mountMenus(tester);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.byType(LiquidGlassLayer, skipOffstage: false), findsNothing);
      final rootCenter = tester.getCenter(find.byIcon(Icons.menu));
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      expect(find.byType(LiquidGlassLayer), findsNothing);
      final menu = tester.widget<PuckMenu>(
        find.byKey(const ValueKey('example-menu')),
      );
      final colors = <Color>{};
      for (final level in menu.puckItems) {
        final materials = level.cast<Material>();
        final color = materials.first.color!;
        expect(color.a, 1);
        expect(materials.every((puck) => puck.color == color), isTrue);
        colors.add(color);
      }
      expect(colors, hasLength(menu.puckItems.length));
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
