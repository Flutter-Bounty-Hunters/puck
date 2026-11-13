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
velocity. Opening starts the spring clock at the request and samples it during
the first layout, so items can move without waiting for another animation frame.
Expanded items keep a 24px horizontal gap from the overlay edges (reduced
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

### Multiple menu tiers

Supply `menuTiers` instead of `menuItems`, with lists ordered nearest to farthest:

```dart
menuTiers: [
  [favoriteButton, searchButton],
  [shareButton, downloadButton, settingsButton],
  [helpButton, profileButton],
],
```

Any number of tiers is supported; empty lists are ignored. `menuRadius` is the
preferred inner radius. Additional tiers spread into the available space and
compress when needed, respecting the same viewport, safe-area, and keyboard
boundaries as single-tier menus. Extremely crowded menus may overlap when the
available space cannot fit all items. Give items unique stable keys to preserve
state across updates. Tiers start 50 milliseconds apart, farthest first when
opening and nearest first when closing.

Multi-tier menus share two end-cap directions. Each tier's first and last items
align with those directions, and its other items use equal angular steps along
the arc between them. A tier with one item uses the arc midpoint. The shared
arc adjusts to keep every tier within the available boundaries. Debug visuals
show both end-cap lines, tier arcs, and item anchor dots.

Tier spacing increases outward: each step adds the larger of `menuRadius` and
one item diameter, plus 8 pixels for each successive tier. For the demo's 80px
inner radius, the next gaps are 88px, 96px, and so on. Available viewport space
may compress these distances further.

While an open menu moves against a boundary, it preserves its end-cap angles
and first squeezes the radial gaps between tiers, down to 50% of their resting
spacing. Only when that no longer fits does it choose a new arc. The tiers
spread back out when space becomes available again. While dragging, the shared
arc also widens immediately as soon as its end caps have room to move outward.
When room returns, widening the arc takes priority over restoring radial gaps.

On release, the menu restores its resting tier distances and chooses its arc at
the root's final docking destination. The root's spring motion does not trigger
repeated menu rearrangements while it settles against the wall.

Set `showTierCurves: true` to connect each tier's items with a 6px circular arc.
The curves track the live spring positions, fade near the root during opening
and closing, and are clipped out of every puck, including translucent ones.
The demo enables these curves independently of debug visuals.

Tier arcs use direct canvas arc strokes and analytic circular cutouts, without
boolean clipping paths or offscreen layers. The arc layer has its own repaint
boundary, caches tier ordering, and coalesces item notifications once per frame.
Run `flutter test benchmark/tier_curve_benchmark_test.dart` to measure CPU paint
recording time for the demo's 23 items (this excludes GPU raster time).

### Preparing expensive menu content

`maintainMenuState: true` keeps item subtrees ready beneath the root between
opens. This trades some startup work and retained memory for lower tap latency.
Closed items ignore input and semantics, and track the root without running
springs. The default remains `false`, disposing items when they collapse.

`menuTierBuilder: (context, tier, child) => ...` wraps one tier's positioned
Stack in a rendering layer. Keep the wrapper at the overlay's full size so
coordinates stay consistent. The demo uses one `LiquidGlassLayer` per tier
(4/7/12 shapes), plus the root's separate layer, to respect the renderer's
16-shape limit. It deliberately keeps those captures independent because glass
surfaces overlap while animating.

### Transparent first-use preparation

The demo starts immediately with its menu closed. It has no startup cover,
spinner, scripted open/close cycle, or readiness gate for input. Real item states
remain prepared beneath the root with `maintainMenuState`.

Each menu glass layer also queues a disposable, glass-only offscreen scene during
idle time. Preparation is serialized, uses no user item widgets or callbacks,
and never contributes visible pixels or semantics. Any pointer input cancels
unfinished jobs; opening the menu never waits for them. Images and temporary
layers are released afterward. Shader loading also runs asynchronously.

For diagnostics, `PUCK_SKIP_WARMUP=true` skips those idle jobs and
`PUCK_TRACE_PREPARATION=true` logs their lifecycle. The profiler's
`PUCK_PROFILE_START_DELAY_MS=200` option exercises early interaction.

`PuckOverlay.menuExpanded` remains an optional caller-owned `ValueNotifier<bool>`
for explicit programmatic control. The demo does not use it for preparation.

The example includes [six isolated performance fixtures and a cold-launch
benchmark runner](example/lib/performance/README.md), covering solid, photo,
and glass menus through first/repeated openings and open/closed drag/release.
