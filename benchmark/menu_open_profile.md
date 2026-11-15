# Menu opening profile — November 12, 2026

This is the baseline captured before glass setup optimization. See the [follow-up measurements](menu_glass_optimization.md) for the implemented changes and updated timings.

Repeated opening lag is reproduced on the running iPhone simulator. The arcs are not the large CPU cost in the measured opening frames.

## Environment and method

- iPhone 17 simulator, iOS 26.5, Flutter 3.47.7, Impeller/Metal.
- Flutter rejected `--profile` on this simulator. These are **debug-mode VM CPU profiles and real engine frame timings**, not release/profile-mode hardware measurements.
- The actual demo was launched using `example/tool/profile_menu.dart`, including its real LiquidGlass menu widgets and 4/7/12 item tiers. No widget-test renderer or FakeGlass was used.
- Six repetitions: wait for startup, press/release root, leave open three seconds, close, wait two seconds. Pointer events follow the normal Flutter gesture pipeline. Tap release is time zero.
- A persistent frame observer records the first mounted child, first movement >0.5px, and first emergence >8.5px from the root center. Coordinates are converted into the overlay's SafeArea coordinate system. A 48px item fits inside a 64px root until its center moves 8px.
- The observations are framework post-frame geometry timestamps. Actual screen presentation follows rasterization; these are not video-derived pixel latency measurements. Frame timings are captured separately from the engine.
- A preliminary batch had a coordinate mismatch for movement; its motion/visibility results were discarded. The table below is the corrected primary batch. A further six-opening batch added temporary timeline markers around layout, target generation, and arc painting, then those markers were removed.

## Primary six-opening results

All durations below are milliseconds after tap release, except the two frame-duration columns.

| Opening | Mounted beneath root | First movement | First emergence | Worst UI frame | Worst raster frame |
|---|---:|---:|---:|---:|---:|
| 1 | 90.2 | 117.8 | 147.9 | 68.5 | 19.1 |
| 2 | 71.4 | 120.6 | 120.6 | 58.6 | 3.5 |
| 3 | 74.2 | 110.2 | 126.2 | 58.8 | 20.5 |
| 4 | 69.8 | 110.7 | 110.7 | 57.7 | 3.6 |
| 5 | 73.5 | 116.7 | 116.7 | 56.2 | 3.6 |
| 6 | 67.7 | 116.3 | 116.3 | 51.5 | 21.6 |

Median mount delay: 72.5ms. Median emergence delay: 118.7ms.

The slow opening frame recurs even on later taps. UI-frame times of 51.5–68.5ms exceed the 16.7ms budget for 60fps; this is not merely the initial shader warmup or the tier stagger. Raster spikes also occur intermittently.

## CPU/timeline evidence

The diagnostic batch captured 2,010 CPU samples. The retained part of its timeline includes:

- `Puck.menuLayout`: 1.719ms and 2.219ms for the two retained opening calculations.
- `Puck.menuTargets`: 0.061ms and 0.096ms for those same openings.
- `Puck.paintTierArcs`: 256 captured paints; median **0.044ms**, maximum **0.694ms**. The first arc paint for those two openings was 0.029ms and 0.016ms.

The timeline ring buffer overwrote earlier events in that diagnostic batch; these numbers deliberately describe only the retained events, not all six initial layouts. The complete per-opening frame timings remain in the saved JSON.

CPU samples show work in widget construction/mounting, render-object layout, and the LiquidGlass rendering/compositing path (`_paintGlass`, `paintFrame`, `_buildGpuGeometryImage`, and native geometry submission). The evidence points to the menu widget/glass pipeline as the next profiling target. It does **not** prove that any single one of those functions is the sole cause, or that arc GPU raster cost is zero.

## Additional concrete rendering failure

Every run logged:

> liquid_glass_renderer: a LiquidGlassLayer has more than 16 glass shapes; the extra shapes are not drawn. Split the glass across several layers.

The demo currently puts all **23 menu shapes** into one shared glass layer (the root uses its own layer). This is a separate correctness issue: some menu items' glass surfaces are omitted. It must be accounted for when diagnosing apparent late/missing items. It does not by itself establish the cause of the 50–70ms UI-frame stalls.

## Saved evidence

- Summary and all primary per-frame timings: [JSON](results/menu_open_profile_2026-11-12.json).
- Primary VM CPU samples: `/tmp/puck-profile-evidence-run2/cpu-samples.json`.
- Diagnostic VM timeline (Chrome/DevTools trace JSON): `/tmp/puck-profile-evidence-run3/timeline.json`.
- Diagnostic per-opening timings: `/tmp/puck-profile-evidence-run3/trials.json`.
- Simulator recording: `/tmp/puck-menu-profile.mp4`.

## Reproduce

From `example`, run:

```sh
flutter run -d E8A6B758-88BE-4D7E-935F-05A5F66043D8 -t tool/profile_menu.dart
```

The diagnostic harness automatically performs six opens/closes. Its `ext.puck.profileResults` VM-service extension exposes complete results without console truncation. The normal `lib/main.dart` entrypoint is unchanged. On a physical device, repeat with `--profile` to remove debug/JIT overhead and obtain representative performance numbers.

## Can all pucks share one glass layer?

Architecturally yes, but the installed renderer caps each layer at 16 shapes
(`LiquidGlassBlendGroup.maxShapesPerLayer = 16`). With 23 menu items plus the
root, the demo cannot place all 24 into one supported layer without changing the
renderer. There is no public constructor setting to raise that constant.

The package supports sharing a backdrop capture between multiple layers through
`BackdropGroup` / `BackdropKey` and `useBackdropGroup`. That can reduce repeated
screen readbacks while retaining multiple geometry layers. Its documentation
warns that overlapping effects must not share a key, and this menu deliberately
overlaps during spring animations. A shared-capture solution therefore needs
measurement and overlap handling rather than blindly applying the same key.
