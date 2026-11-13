# Transparent menu preparation — November 12, 2026

The earlier app-wide startup cover and hidden live-menu cycle were removed at the user's request. The app now calls `runApp` immediately and never awaits menu preparation before accepting input.

## Current behavior

- No spinner, global cover, app-wide semantics suppression, startup timer, or readiness gate.
- No automatic open/close commands to the user's menu. It remains closed until tapped.
- Real menu item widgets remain prepared beneath the root, as in the retained-glass optimization.
- Each `PreparedMenuGlassLayer` can queue a disposable glass-only scene at scheduler idle priority. The scene contains no user button widgets or callbacks, ignores pointers, excludes semantics, and contributes zero screen pixels.
- Preparation explicitly paints its isolated repaint boundary for an offscreen GPU readback. Images and temporary layers are disposed. Jobs are serialized rather than submitting three large readbacks concurrently.
- Pointer-down/scroll input cancels pending jobs immediately. User gestures do not await any preparation future. An already-submitted GPU render cannot be revoked, but it does not control the menu's expanded state or block event routing.
- All four normal glass layers remain independent to preserve overlapping-surface correctness and respect the 16-shape renderer limit.

## Validation

Native iPhone 17 simulator / real Impeller checks confirmed:

1. With an idle startup, all three preparation jobs (4, 7, 12 shapes) logged successful offscreen completion before the first tap. No preparation errors were logged.
2. With `PUCK_PROFILE_START_DELAY_MS=200`, first input canceled all three queued jobs. The first menu expansion emerged 64.4ms after tap release, without waiting for preparation.
3. The ordinary six-tap probe still completed in both scenarios. This is debug simulator evidence, not a claim that all GPU jank is eliminated or that background GPU work is free.

Tests verify that theme/debug controls and text entry work immediately, the menu stays closed over time without a tap, immediate menu opening works, and removing the app cleans up safely. Library tests and static analysis also pass.

[Complete timing and lifecycle evidence](results/menu_transparent_preparation_2026-11-12.json).

Diagnostics (from `example`):

```sh
flutter run -d <device> -t tool/profile_menu.dart --dart-define=PUCK_TRACE_PREPARATION=true
flutter run -d <device> -t tool/profile_menu.dart --dart-define=PUCK_TRACE_PREPARATION=true --dart-define=PUCK_PROFILE_START_DELAY_MS=200
```

`PUCK_SKIP_WARMUP=true` disables only the idle offscreen jobs for comparison. It does not change app interactivity or create a loading state.
