# Puck example

A playground for dragging, flinging, and docking the main puck.

The bottom tabs are **Puck**, **Gallery**, **Layout**, and **Performance**.
The iOS-style floating tabs come from
[liquid_glass_widgets](https://pub.dev/packages/liquid_glass_widgets), with shaders
loaded on demand. Each tab has its own app bar and preserves its menu positions.

The Puck page has a centered **PUCK** title, a small bubble icon, and one glass
menu starting on the right edge, 30% down. Its root is plain glass with a subtle translucent gray tint. The root uses a
lightweight surface until Flutter has rasterized its first frame, so cold glass
renderer setup cannot hold the launch screen open. Open
it for keyboard, debug visuals, and the seven theme colors. Puck always uses dark
mode.
Tap the selected color again to restore the monochrome theme.

The Gallery page has the **GALLERY** title and the original collection of menus.
Gallery keeps its own light/dark toggle. Accent colors, keyboard, and debug
settings are shared with Puck.
Menus avoid the keyboard; roots that already fit above it keep their position.
The Messenger activation demonstration runs on the first visit to Gallery.
The Messenger menu and multi-level glass menu use the same arc solver, including
continuous rotation around barriers and full rings when enough space is available.
The Layout tab shows three levels with
4 / 7 / 12 items, shown as radius circles, 48px-wide bands, and filled sectors
for the calculated arc. Drag the root to inspect the existing layout rules;
no menu items or item springs are created. Tap to hide/show guides, or reset to
the initial anchor. Run it directly with `flutter run -t lib/layout_demo.dart`.
The end caps rebalance their wall clearance as space returns. Guides stay centered
on the moving root during docking, independently of its fixed landing anchor.

From this directory, run:

```sh
flutter pub get
flutter run
```

The app depends on the parent `puck` package through a local path dependency,
so edits to the package can be hot reloaded in this app.

The six rendering fixtures and cold-launch benchmark runner are documented in
[lib/performance/README.md](lib/performance/README.md).
