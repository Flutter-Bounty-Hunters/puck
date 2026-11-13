import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck_example/main.dart';
import 'package:puck/puck.dart';
import 'package:puck/src/spring_puck.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

void main() {
  testWidgets(
    'the app is interactive immediately and never opens the menu for preparation',
    (tester) async {
      await tester.pumpWidget(const PuckDemo());
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('menu-warmup-cover')), findsNothing);
      expect(
        tester.widget<PuckOverlay>(find.byType(PuckOverlay)).menuExpanded,
        isNull,
      );
      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pump();
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
      await tester.tap(find.byTooltip('Show debug visuals'));
      await tester.pump();
      expect(find.byTooltip('Hide debug visuals'), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Ready immediately');
      expect(find.text('Ready immediately'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester
            .widgetList<SpringPuck>(find.byType(SpringPuck))
            .every((puck) => !puck.expanded && puck.dormant),
        isTrue,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('menu preparation cancels cleanly when the app is removed', (
    tester,
  ) async {
    await tester.pumpWidget(const PuckDemo());
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
      // Three bounded tier layers plus the root; no layer exceeds 16 shapes.
      expect(find.byType(LiquidGlassLayer), findsNWidgets(4));
      final rootCenter = tester.getCenter(find.byIcon(Icons.menu));
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
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
