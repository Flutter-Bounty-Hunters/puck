# Glass setup optimization — November 12, 2026

The demo now mounts its expensive glass menu once at startup and retains it between opens. Across the final six-opening run, median time to first emergence dropped from **118.7ms to 65.6ms**, a **45% reduction**. The median of the worst UI-frame duration for each opening dropped from **58.2ms to 6.8ms**, an **88% reduction**.

## Changes

- The demo enables `maintainMenuState`. Item states, glass render objects, and their layers stay prepared beneath the root while closed. Tapping changes spring targets without mounting 23 new button/glass trees.
- Retained closed items ignore pointers and semantics and track the root directly. Their spring tickers do not run. This avoids both hidden work and trailing items when dragging the closed root.
- `menuTierBuilder` groups each tier's positioned Stack inside its own glass layer. The demo uses 4, 7, and 12 shapes in those layers, plus the root's own layer. The 16-shape-limit warning disappeared, and all 24 puck surfaces are rendered.
- Default library behavior remains disposal on collapse; retaining state is an explicit option. The extra startup work and retained memory are intentional demo tradeoffs.
- Real glass effects remain enabled. Four captures stay independent to preserve correct rendering where surfaces overlap during motion. The optimization does not substitute FakeGlass or skip menu items.

## Repeated measurements

Same booted iPhone 17 simulator, iOS 26.5, debug-mode VM profiling, Impeller/Metal, same 4/7/12 item menu and geometry. Profile mode is unsupported by this simulator. Each batch includes six real pointer taps with three seconds open and two seconds closed. These are framework-observed geometry timestamps after tap release, not video scanout measurements.

| Batch | Median first emergence (ms) | Median worst UI frame per opening (ms) | First opening emergence (ms) |
|---|---:|---:|---:|
| Baseline | 118.7 | 58.2 | 147.9 |
| Optimized 1 | 64.1 | 13.6 | 65.5 |
| Optimized 2 | 55.0 | 11.1 | 149.9 |
| Optimized 3 | 65.6 | 6.8 | 79.4 |

The first optimized batch overlapped some test execution. Batches 2 and 3 had no concurrent tests. Batch 3 includes the final dormant-item behavior. Minor subsequent lifecycle/oversized-item safeguards were validated by tests; they do not change the demo's 48px-item policy.

The raw `mountedUs` probe field has a different interpretation after retention: all items are already mounted before the tap. It is now the first observed post-tap geometry frame, not a new item mounting delay. Movement and emergence remain directly comparable.

## Final measured six-opening batch

| Opening | First movement (ms) | First emergence (ms) | Worst UI frame (ms) | Worst raster frame (ms) |
|---|---:|---:|---:|---:|
| 1 | 55.3 | 79.4 | 71.9 | 84.0 |
| 2 | 55.4 | 71.7 | 7.7 | 7.1 |
| 3 | 59.0 | 75.3 | 7.3 | 6.5 |
| 4 | 42.2 | 57.6 | 6.3 | 6.0 |
| 5 | 42.2 | 59.5 | 6.2 | 6.0 |
| 6 | 39.6 | 56.9 | 5.5 | 6.8 |

Median first movement: 116.5ms baseline → 48.8ms optimized.

## Remaining limits

Cold/first-open GPU spikes are **not eliminated**: first emergence ranged from 65–150ms across optimized batches, and the final batch contained an 84ms raster spike during the first opening's three-second observation window. The result is a much faster typical opening, not a claim of zero jank. Splitting the old over-capacity glass layer fixes missing rendering but increases independent backdrop captures; sharing them blindly would be unsafe for overlapping glass. Further GPU tuning should be validated on a physical device in profile mode.

## Validation and evidence

- 61 library tests, the demo test, and static analysis pass.
- New tests verify state reuse through repeated opens/closes, inactive closed items, closed-root dragging without trailing items, safe hiding of oversized retained items, and the demo's four glass layers.
- [Saved summaries and final per-frame measurements](results/menu_glass_optimized_2026-11-12.json).
- [Baseline report](menu_open_profile.md).
- Full optimized CPU samples/timelines remain in `/tmp/puck-profile-optimized1`, `/tmp/puck-profile-optimized2`, and `/tmp/puck-profile-optimized3`.
- Reproduce from `example` with `flutter run -d <device> -t tool/profile_menu.dart`. Use `--profile` on supported physical hardware.
