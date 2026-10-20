## Unreleased

- Add optional red anchor dots and a main-puck long-press callback; long-press the example puck to toggle the dots.

- Keep closed menu subtrees unmounted and dispose items after collapse.
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
