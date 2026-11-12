import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck/puck.dart';

void main() {
  const parent = ValueKey('parent');
  const item = ValueKey('item');

  for (final resize in [false, true]) {
    for (final drag in [false, true]) {
      testWidgets('keyboard restores with a spring unless dragged '
          '(resize: $resize, drag: $drag)', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 600);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              resizeToAvoidBottomInset: resize,
              appBar: AppBar(title: const Text('Keyboard return')),
              body: const PuckOverlay(
                initialVerticalAlignment: 0.9,
                puck: ColoredBox(key: parent, color: Colors.blue),
                menuItems: [ColoredBox(key: item, color: Colors.green)],
                child: SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final original = tester.getTopLeft(find.byKey(parent));
        for (final height in [150.0, 250.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: height);
          await tester.pumpAndSettle();
        }
        // Opening the menu is not a drag and must preserve the saved position.
        await tester.tap(find.byKey(parent));
        await tester.pumpAndSettle();
        if (drag) {
          await tester.drag(find.byKey(parent), const Offset(-650, -60));
          await tester.pumpAndSettle();
          // Further keyboard changes must not record a new return position.
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.pumpAndSettle();
        }
        final displaced = tester.getTopLeft(find.byKey(parent));
        tester.view.resetViewInsets();
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(parent)).dy,
          closeTo(displaced.dy, 0.01),
        );
        await tester.pump(const Duration(milliseconds: 80));
        final inFlight = tester.getTopLeft(find.byKey(parent));
        if (drag) {
          expect(inFlight.dx, closeTo(displaced.dx, 0.01));
          expect(inFlight.dy, closeTo(displaced.dy, 0.01));
        } else {
          expect(inFlight.dy, greaterThan(displaced.dy));
          expect(inFlight.dy, lessThan(original.dy));
        }
        await tester.pumpAndSettle();
        final finalPosition = tester.getTopLeft(find.byKey(parent));
        expect(
          finalPosition.dx,
          closeTo(drag ? displaced.dx : original.dx, 0.01),
        );
        expect(
          finalPosition.dy,
          closeTo(drag ? displaced.dy : original.dy, 0.01),
        );
        expect(find.byKey(item), findsOneWidget);
      });
    }

    testWidgets(
      'keyboard changes bound closed and open pucks (resize: $resize)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 600);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              resizeToAvoidBottomInset: resize,
              appBar: AppBar(title: const Text('Keyboard boundary')),
              body: const SafeArea(
                child: PuckOverlay(
                  initialVerticalAlignment: 1,
                  puck: ColoredBox(key: parent, color: Colors.blue),
                  menuItems: [ColoredBox(key: item, color: Colors.green)],
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(parent)).bottom, 600);

        // A closed parent must be pushed up on each reported height change.
        for (final height in [100.0, 180.0, 250.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: height);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(parent)).bottom,
            closeTo(600 - height, 0.01),
          );
          expect(find.byKey(item, skipOffstage: false), findsNothing);
        }

        await tester.tap(find.byKey(parent));
        await tester.pumpAndSettle();
        // Both growing and shrinking keyboards, including changes in flight.
        for (final height in [300.0, 200.0, 320.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: height);
          await tester.pump();
          for (final key in [parent, item]) {
            expect(
              tester.getRect(find.byKey(key)).bottom,
              lessThanOrEqualTo(600 - height + 0.01),
            );
          }
          await tester.pumpAndSettle();
        }
        await tester.drag(find.byKey(parent), const Offset(-80, 400));
        await tester.pumpAndSettle();
        for (final key in [parent, item]) {
          expect(
            tester.getRect(find.byKey(key)).bottom,
            lessThanOrEqualTo(280.01),
          );
        }
        await tester.tap(find.byKey(parent));
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 340);
        await tester.pumpAndSettle();
        expect(find.byKey(item, skipOffstage: false), findsNothing);
        expect(
          tester.getRect(find.byKey(parent)).bottom,
          lessThanOrEqualTo(260.01),
        );

        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.drag(find.byKey(parent), const Offset(-80, 800));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(parent)).bottom, closeTo(600, 0.01));
      },
    );
  }
}
