![Puck](https://gist.githubusercontent.com/matthew-carroll/404783cc39137527233a0b2c9d256040/raw/6f0fc1921fa44a40b5a74a43c3b476ad3b9b3a88/puck-banner.png)

# puck

A Flutter widget for floating, draggable circular menus inspired by chat heads.
Tap the main puck to spring a circular menu open or closed.

```dart
import 'package:puck/puck.dart';

SafeArea(
  child: PuckOverlay(
    diameter: 64,
    menuItems: [
      GestureDetector(
        onTap: () {},
        child: const ColoredBox(
          color: Colors.indigo,
          child: Icon(Icons.home, color: Colors.white),
        ),
      ),
    ],
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
its docking edge within the new vertical bounds. Keyboard height changes also
update the collision boundary: the parent and menu items stay above the keyboard,
including when it opens beneath a closed parent. This works whether or not the
surrounding Scaffold resizes its body for the keyboard. When the keyboard closes,
the parent springs back to its position before it was pushed upward. Dragging the
parent while the keyboard is open discards that saved position.

## Expanding menus

Supply `menuItems` with the widgets for each circular item. Items enter the
widget tree only when the main puck is tapped and are removed after their
collapse springs settle. Tapping the main
puck toggles the menu and also calls `onTap`, if provided. Item widgets handle
their own actions; selecting an item leaves the menu open.

`menuRadius` defaults to 112 logical pixels from the main puck center, and
`menuItemDiameter` defaults to 48. Expanded items occupy the visible arc of an
inward-facing circle. They pack closer together near corners and spread out
where more space is available. Items balance the visible clear space between their circular edges with the
clear space between the end items and the screen boundaries. In tight corners,
the 24px horizontal inset takes priority when equal gaps cannot fit at the
configured radius. Very dense menus or small containers may cause
items to overlap; choose an appropriate radius, diameter, and item count.

Every menu item uses a two-dimensional spring. Moving the main puck, resizing
the overlay, or reversing expansion retargets the springs while preserving their
velocity. Expanded items keep a 24px horizontal gap from the overlay edges (reduced
only when the container is too narrow). They are constrained to these bounds during
spring overshoot. Collapsing items return underneath the main puck and stop
receiving taps. Give items stable keys if their order or membership changes.

## Ropes

Ropes are optional and disabled by default. Enable them with `showRopes: true`.
When disabled, rope physics and painting are skipped. Customize the two-tone
stroke with a const style:

```dart
showRopes: true,
ropeStyle: const PuckRopeStyle(
  thickness: 3,
  brightColor: Color(0xFF89939E),
  darkColor: Color(0x66000000),
),
```

These are the default style values. Thickness is the total width in logical
pixels; the bright inner stroke is half that width. Ropes are masked beneath
all puck circles so other content remains visible through translucent pucks.

## Debug anchors

Set `showDebugAnchors: true` to paint small red dots at puck anchor centers.
Menu dots mark their current spring targets; the main dot shows its docking
destination during a release and follows the main puck while dragging.
The visualizer is off by default and does not intercept touches. Use
`onLongPress` to handle long presses on the main puck. The example uses it to
toggle the dots.

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
