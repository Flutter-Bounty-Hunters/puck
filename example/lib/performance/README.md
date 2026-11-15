# Floating-menu performance suite

Six independent, manually runnable fixtures:

| Entry point under `lib/performance/` | Circle contents | Level counts |
|---|---|---|
| `solid_single.dart` | Solid colors + icons | 4 |
| `solid_three_level.dart` | Solid colors + icons | 4 / 7 / 12 |
| `photos_single.dart` | Bundled photographs | 4 |
| `photos_three_level.dart` | Bundled photographs | 4 / 7 / 12 |
| `glass_single.dart` | Real glass + icons | 4 |
| `glass_three_level.dart` | Real glass + icons | 4 / 7 / 12 |

The root uses the same material category as its menu. Every fixture uses the same
64px root, 48px items, 80px preferred inner radius, right/mid-screen starting
anchor, static patterned background, safe-area bounds, and item disposal on close.
The three-level variants share the same spacing/obstacle solver. Curves and ropes
are off by default to isolate circle content. Photos are distinct local NASA JPEG fixtures
with credits in `assets/performance/sources.json`; no network requests occur at
runtime. Photo decoding is not explicitly prewarmed. The single-level fixture uses five
distinct photos including its root; the three-level fixture uses 24.
Menu items mount on opening and are disposed after collapse; closed menus do
not build hidden photo or glass widgets. Root content mounts at startup. Later
opens may still benefit from Flutter's image cache and renderer resource caches.
Startup and per-image readiness timestamps are saved to make this visible.
Glass uses an independent rendering layer for every item and the root, matching
the demo. Reports record this policy and whether native shader filters are supported; platforms
without them use the glass package's fallback and should not be compared as real
glass performance.

Run a fixture manually from `example`:

```sh
flutter run -d <device-id> -t lib/performance/glass_three_level.dart
```

## Run everything

From `example`:

```sh
dart run tool/performance/run.dart --device <device-id>
```

## Review the latest run

```sh
dart run tool/performance/review.dart --device <device-id>
```

Each menu configuration has one compact profile showing all nine interaction
windows together: first/repeated opening, closing, and open/closed pull, drag,
and docking. Profiles use the same scales and column positions, in a phone list
or two-column desktop layout. There is no scenario dropdown.

Thick bands span median to p95 frame work; thin whiskers show the worst frame.
Directly labeled **16.67 ms (60 FPS budget)** and **8.33 ms (120 FPS budget)**
guides make crossings visible without mistaking them for measured FPS. The
chart title is **Avg Frame Time Across Animation**. All charts share a vertical scale equal
to the largest captured frame time across the run, or 16.7 ms, whichever is
larger. This includes worst-frame spikes, not just p95 values. Tap any column
for exact values and individual frame timelines.

Two small first/repeat meters beneath each profile show median time from tap
release to the first observed puck movement, on a separate shared scale. Time
to visible content remains available in measurement details. Closing duration and docking observation time
are not treated as input latency. Different capture settings stay in separate
comparison groups, and missing measurements are gaps.

Frame work is `max(UI, raster)`, never their sum. The 120 FPS guide evaluates
work-budget **headroom**, not measured 120 Hz presentation. The chart guide,
configuration, failures, and logs are available on demand. The bubbles button
opens a demo, with a back button to return. Flutter's
[performance profiling guide](https://docs.flutter.dev/perf/ui-performance) and
[DevTools frame view](https://docs.flutter.dev/tools/devtools/performance)
describe the underlying frame budgets and engine measurements.
The compact profiles follow the distribution/tail emphasis in
[Google's monitoring guidance](https://sre.google/workbook/monitoring/) and direct
threshold/separate-unit conventions in
[Grafana's chart documentation](https://grafana.com/docs/grafana/latest/visualizations/panels-visualizations/visualizations/time-series/).

The review command reads the newest consolidated JSON run from
`build/performance_runs`, ranked by its measurement date. Refresh reads the newest
saved checkpoint again.
Focused `--profile-opening` diagnostic captures are excluded from automatic
latest-run selection; open those using an explicit results file.

To review a specific file or another results directory:

```sh
dart run tool/performance/review.dart --device <id> --results <file-or-directory>
```

Keep the command running while reviewing. It serves the saved file to the app
through a temporary local endpoint, so simulators and phones can read the
computer's results without copying extra run files or adding assets to the app.
Physical devices need to share the computer's local network. Desktop launches
can also discover files directly from the project directory. Debug and glass
fallback results are labeled; failed launches are excluded from comparisons.
Large optional traces remain in the original file; the app displays their count.

## Fresh launches

This runs all six fixtures, rebuilding incrementally as needed. **Each fixture
gets a new app process**, and the runner checks the VM PID/start-time identity.
It quits the app before the next launch; it never uses hot reload/restart to
claim a cold result. Repeating cold launches is supported:

```sh
dart run tool/performance/run.dart --device <physical-device-id> --mode profile --cold-runs 3 --repeats 5
```

For a USB-connected device, add `--device-connection attached` to keep Flutter
from choosing wireless discovery. This also avoids relying on macOS local-network
permission for Wi-Fi discovery.

Measurements require a physical device in profile mode. `--mode auto` selects
profile mode; simulator, emulator, web, and debug-mode measurements are rejected.
Simulators may still display saved hardware results in the review app. Older
debug captures remain readable and are clearly labeled.

Useful controls:

```sh
# Raw glass cold path, with first input soon after the first app frame:
dart run tool/performance/run.dart --device <id> --start-delay-ms 0

# Glass only; test against a 120Hz frame-work budget:
dart run tool/performance/run.dart --device <id> --variants glass_single,glass_three_level --budget-fps 120

# Add arcs consistently across all variants, and save incremental VM traces:
dart run tool/performance/run.dart --device <id> --curves --trace

# List the exact commands without launching:
dart run tool/performance/run.dart --device <id> --dry-run
```

The fixtures perform no explicit glass warm-up or hidden open/close cycle.
`first_open` is always the first actual menu opening in that new process. The
default first tap is requested 250ms after the first framework frame; change it
with `--start-delay-ms`. Fresh process does **not** mean clearing OS file caches
or GPU-driver caches. These policies are recorded in each result.

`--budget-fps` sets the measurement threshold only; it does not change the device
refresh rate. The actual display refresh rate is recorded separately.
`--binary <path>` optionally reuses an app already built from
`lib/performance/main.dart` in the selected mode, avoiding incremental builds.
Do not pass the ordinary demo's binary.

## Scenarios

The automation waits for the app lifecycle to be `resumed` and a framework frame
to complete before the first tap. iOS can execute engine frames while the app is
still inactive; injecting a tap then incorrectly mixes window startup into the
menu's first opening. This wait opens no menus and applies only to automation.
Reports record `interaction_readiness: "resumed_after_frame"` and readiness time.

For first-opening investigation on a physical device:

```sh
dart run tool/performance/run.dart --device <id> --device-connection attached --profile-opening --variants glass_three_level --cold-runs 3 --repeats 1
```

This keeps the first opening genuinely first, followed by close/open controls.
It captures CPU stacks from VM startup, full engine timeline events, and opt-in
markers for pointer dispatch, tap callback, layout solving, spring activation,
first ticks, and observed movement. No hidden warm-up opens or profiler-attachment
gate precede the first tap. Each launch embeds `cpu_profiles`, `opening_timeline`,
and report `opening_trace_events`/`lifecycle_events`/`diagnostic_frames` in the
single run file. CPU symbol tables drop only unreferenced functions and remap
stack indices; every sampled stack is retained. Profiling adds overhead, so use
these captures for attribution rather than mixing them with baseline scores.

Each launch executes these categories in order:

Opening and closing measurement windows start at pointer-up. The preceding
40 ms press is excluded from phase durations and frame statistics. Reports mark
this policy with `open_close_measurement_start: "pointer_up"`; older saved runs
retain their original measurement windows.

1. **First opening:** genuine pointer down/up, first item motion, first geometric
   emergence, first content-ready emergence, and settling time.
2. **Repeated closing/opening:** separate `repeat_close` and `repeat_open`
   measurements, five pairs by default.
3. **Closed pull:** grab the root and pull it 80px (or 20% of viewport width) off
   its wall over 300ms; measure root response and frames.
4. **Closed rapid drag:** the same held pointer follows a reproducible zigzag
   across the viewport over 1.5 seconds.
5. **Closed release:** lift the pointer and observe return to the nearest wall,
   including first wall contact and settling.
6. **Open pull:** open/settle the menu, then perform the same pull.
7. **Open rapid drag:** the same zigzag with the levels expanded.
8. **Open release:** lift the pointer and observe the root and items settling.

Pull/rapid/release are separate windows within one continuous gesture, preserving
release velocity. Events have real monotonic timestamps and movement deltas.
Input is nominally 120Hz and follows elapsed wall time, so a UI stall coalesces
input rather than stretching the commanded motion. Actual input sample counts
and dispatch timestamps are saved. Pull latency includes Flutter's drag
recognition threshold and intentional spring response; it is not solely render
latency.

Visual settling means items within 0.75px of their targets and positions stable
within 0.1px for at least 140ms. Releases observe at least 1.2 seconds to include
wall contact/overshoot instead of ending at the first contact. Photo openings
also wait for decoded item frames. A six-second settle timeout fails the case.

## Output

Each run creates **one self-contained JSON file** at
`example/build/performance_runs/<UTC-time>.json`. Choose another file with
`--output <new-file.json>`.

The file contains:

- `schema_version`, `status`, `started_utc`, `finished_utc`: format and run state.
- `device`, `mode`, `parameters`: the complete run configuration.
- `summary.markdown`: comparison table by variant/scenario and failure list.
- `summary.samples`: one structured row per successful measurement window,
  including response/settling times and frame metrics.
- `cases`: every variant/launch, each containing `command`, `process`,
  `flutter_log`, and `report` with raw frames, inputs, milestones, image readiness,
  and verified fresh-process identity. Failed launches retain their available
  diagnostics and raw reports plus an `error` field.
- `cases[].traces`: optional VM timeline chunks with `--trace`, embedded in the
  same file. Each chunk contains `completed_scenarios` and `timeline`; the latter
  is the standard DevTools/Chrome trace object.

There are no separate CSV, log, report, or trace files. The file is created when
measurement starts, updated after every launch, and finalized on completion or
Ctrl+C. Completed launches remain available if later launches fail. Failed
launches are listed in the summary and excluded from its aggregate measurements.
Existing result files are never overwritten.

Reports include UI/raster mean, p50/p90/p95/p99/max, pipeline latency, counts and
percentages of over-budget frames, and estimated missed refresh intervals. A
frame is over budget when **either** UI work or raster work exceeds the chosen
budget (16.67ms at 60Hz), not when their sum or queued pipeline duration does.
These are jank indicators, **not hardware presentation/drop counters**.

Timings come from the real Flutter engine running the actual app. The automation
injects events into Flutter's normal gesture pipeline and samples laid-out
geometry after framework frames. It does not measure OS touch delivery or panel
scanout. There is no widget-test renderer in the performance runs. Probe work is
small and identical across fixtures; optional tracing adds overhead.

The runner saves failures, continues other fixtures, and returns nonzero if any
case fails, times out, lacks frame data, uses the wrong mode/variant, or omits a
required scenario/visible opening. Closing a menu is not treated as a process
restart.

## Tests

```sh
flutter test test/performance_test.dart
flutter test test/performance_runner_test.dart
```
