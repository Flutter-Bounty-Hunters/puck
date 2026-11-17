## 0.1.0
### Nov 16, 2026
- Give root pucks a small press expansion and playful spring release.
- Animate root pucks in and out with a playful scale overshoot; use `PuckMenu.visible` to animate menu visibility while retaining its position.
- Add `ArcStyle` to customize menu arc colors and thickness.
- Add optional menu IDs to automatically save and restore docked positions across navigation and app restarts.
- Add multi-level menus with staggered opening and closing animations and adaptive arcs that can expand into full circles.
- Add `PuckMenuController` for external control and lifecycle callbacks for expansion, collapse, dragging, release, and docking.
- Fix abrupt arc flips, radius jumps, and unstable level spacing while dragging or docking near boundaries.
- **Breaking:** Replace `PuckOverlay` with self-contained `PuckMenu.singleLevel` and `PuckMenu.multiLevel` layers, using `rootPuck` and `puckItems`. Move geometry and diagnostic options into `PuckMenuLayout` and `PuckMenuDebug`, and remove the root tap and long-press callbacks.

## 0.0.2
- Add optional red anchor dots and a main-puck long-press callback; long-press the example puck to toggle the dots.
- Balance visible circle-edge gaps against screen boundaries instead of center angles.
- Add menu items that spring out from beneath the main puck and collapse on a second tap.
- Retarget menu springs as the main puck moves, preserving velocity during interruptions.
- Adapt the visible menu arc near screen edges and corners.
- Add configurable menu radius and item diameter, with an interactive example.

## 0.0.1

- Introduce `PuckOverlay` for floating, draggable circular widgets.
- Add spring docking to the nearest left or right edge, with 10% of the puck offscreen by default.
- Preserve fling momentum with vertical friction and top/bottom collision boundaries.
- Support custom puck content, tap callbacks, diameter, initial placement, and offscreen fraction.
- Include an Android and iOS example app.
- License the package under the MIT license.
