# Puck example

A playground for dragging, flinging, and docking the main puck.

Use the **Example** and **Layout** tabs to switch between the glass menu demo
and the layout explorer. Each tab keeps its puck position while you switch.
The Layout tab shows three tiers with
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
