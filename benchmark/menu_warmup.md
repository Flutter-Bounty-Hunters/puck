# First-use glass warm-up — November 12, 2026

Historical experiment. The startup cover and blocking cycle described here were removed at the user's request. The current implementation uses menu-local idle offscreen preparation and leaves the app interactive immediately.

The demo now warms its real retained menu before interaction, including native GPU rendering, and returns it to closed state. This targets the first-expansion preparation cost without changing the user's spring animation.

## Implementation

1. Keep a startup cover and disable input/underlying semantics while preparing.
2. Use the caller-owned `menuExpanded` notifier to open the existing menu. No synthetic taps, item actions, or `onTap` callbacks are invoked.
3. Render at partial and full expansion. Two native-pixel-ratio `RenderRepaintBoundary.toImage` calls force the actual scene through GPU rasterization. Both images are disposed immediately; no screenshots are saved by the app.
4. Keep the cover almost opaque (254/255) so on-screen glass passes cannot be discarded as fully occluded. The cover sits outside the captured scene.
5. Close the menu and wait for a completed closed frame before removing the cover.

This moves one-time work to startup: roughly two seconds plus GPU preparation time. It reuses the same button states and glass layers afterward. Timers are canceled if the demo is removed. Unsupported readbacks are skipped safely, and software/FakeGlass test environments do not attempt native shader warm-up.

The ordinary library has no automatic warm-up: it exposes optional `menuExpanded: ValueNotifier<bool>` control, while the demo owns this startup policy. `PuckDemo(warmUpMenu: false)` and `--dart-define=PUCK_SKIP_WARMUP=true` permit diagnostic comparisons.

## Measured result

Same iPhone 17 / iOS 26.5 simulator, Flutter debug, real Impeller glass. Flutter rejects profile mode on this simulator. Every batch contains six user-style pointer taps after startup; the warm-up finishes before those taps. Successive implementations were checked after complete app termination and a fresh launch, not only hot restart.

Compared with the previous retained-glass/no-full-cycle implementation, the final first user expansion's worst raster frame decreased from **84.0ms to 27.6ms**, and its worst UI frame decreased from **71.9ms to 22.6ms**. Its framework-observed emergence time was **80.4ms**, versus 79.4ms previously: this chiefly improves smoothness, not the intended spring's emergence duration.

These are exploratory simulator comparisons, not controlled hardware benchmarks or proof that every spike is shader preparation. GPU timing remains variable and some frames still exceed a 16.7ms budget. The evidence supports reducing first-use jank, **not eliminating it**. On-device profile-mode validation is still needed.

## All warm-up experiments (first user expansion)

| Implementation | Emergence (ms) | Worst UI frame (ms) | Worst raster frame (ms) |
|---|---:|---:|---:|
| Previous retained glass, no full cycle | 79.4 | 71.9 | 84.0 |
| Covered cycle | 64.3 | 10.4 | 14.7 |
| Cycle + frame completion | 79.7 | 35.0 | 49.5 |
| Cycle + offscreen GPU renders | 70.0 | 13.1 | 36.2 |
| Final: GPU renders + near-opaque cover | 80.4 | 22.6 | 27.6 |

The first promising covered-only batch did not reproduce consistently after another cold launch. Offscreen renders plus an almost-opaque cover make the warm-up explicitly exercise both raster paths; the final implementation was measured separately rather than reporting only that promising first result.

## Final six-opening batch

| Opening | First movement (ms) | First emergence (ms) | Worst UI frame (ms) | Worst raster frame (ms) |
|---|---:|---:|---:|---:|
| 1 | 58.3 | 80.4 | 22.6 | 27.6 |
| 2 | 36.1 | 36.1 | 5.1 | 14.1 |
| 3 | 53.2 | 68.4 | 7.4 | 6.0 |
| 4 | 54.8 | 70.5 | 6.5 | 7.1 |
| 5 | 52.8 | 69.2 | 7.4 | 6.5 |
| 6 | 51.5 | 68.2 | 6.6 | 6.4 |

All timing observations are at framework post-frame geometry; actual display presentation follows rasterization. Worst-frame columns span the three-second opening observation window.

## Validation

- Full library test suite, three demo tests, and static analysis pass.
- New coverage checks programmatic control without triggering user tap callbacks, warm-up cover lifetime and closed final state, safe startup cancellation, and prompt subsequent opening.
- [Saved final frame timings and experiment summaries](results/menu_warmup_2026-11-12.json).
- Full native VM/CPU traces remain in `/tmp/puck-profile-warmup1` through `/tmp/puck-profile-warmup4`.
- [Earlier retained-glass optimization report](menu_glass_optimization.md).
