# puck

A Flutter widget for floating, draggable circular menus inspired by chat heads.
The first implementation provides the main puck; expanding menu items will come
later.

```dart
import 'package:puck/puck.dart';

SafeArea(
  child: PuckOverlay(
    diameter: 64,
    onTap: () {},
    puck: const ColoredBox(
      color: Colors.indigo,
      child: Icon(Icons.menu, color: Colors.white),
    ),
    child: yourPageContent,
  ),
)
```

Give `PuckOverlay` a bounded area at least as large as the puck, such as a
Scaffold body. The developer supplies both the page content and the puck widget;
the puck is sized and clipped to a circle. Other parts of the page continue to
receive pointer events.

The puck starts halfway down the right edge. Drag it anywhere in the available
area; release it to spring toward the nearest left or right edge. Fling velocity
feeds into the horizontal spring and carries the puck vertically with friction.
The top and bottom absorb vertical movement without allowing the puck to escape.
Docking hides 10% of the puck's diameter beyond the edge, leaving 90% visible.

Use `initialEdge`, `initialVerticalAlignment` (0–1), `diameter`, and
`offscreenFraction` to customize placement and size. Wrap the overlay in
`SafeArea` to respect system insets. Bounds are relative to the overlay, so it
can also live in a smaller panel. Resizing the area repositions the puck against
its docking edge within the new vertical bounds.

## Development

The root project is the reusable Flutter package:

```text
lib/puck.dart                 Public package entry point
lib/src/                     Package implementation
test/                        Package tests
example/lib/main.dart        Playground app
example/pubspec.yaml         Local dependency on puck via path: ../
example/android/             Android app runner
example/ios/                 iOS app runner
```

Run package checks from the root:

```sh
flutter pub get
flutter test
flutter analyze
```

Run the playground from its own app directory:

```sh
cd example
flutter pub get
flutter run
```

The package does not require native platform runners. Android and iOS runners
belong to the example app, which consumes the same public API as any other app.
