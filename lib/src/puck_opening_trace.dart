import 'dart:developer' as developer;

/// Opt-in diagnostics. Ordinary builds erase these branches at compile time.
class PuckOpeningTrace {
  static const enabled = bool.fromEnvironment('PUCK_TRACE_OPENING');
  static final events = <Map<String, Object?>>[];
  static final _representatives = <int, int>{};
  static bool _active = false;
  static String? _phase;

  static void begin(String phase) {
    if (!enabled) return;
    _phase = phase;
    _active = true;
    _representatives.clear();
  }

  static void end() {
    if (enabled) _active = false;
  }

  static bool representative(int tier, int order) =>
      enabled &&
      _active &&
      _representatives.putIfAbsent(tier, () => order) == order;

  static void instant(String name, [Map<String, Object?> args = const {}]) {
    if (!enabled || !_active) return;
    final now = developer.Timeline.now;
    events.add({'name': name, 'ts': now, 'phase': _phase, ...args});
    developer.Timeline.instantSync(
      'Puck.$name',
      arguments: {'phase': _phase, ...args},
    );
  }

  static T measure<T>(String name, T Function() action) {
    if (!enabled || !_active) return action();
    final start = developer.Timeline.now;
    developer.Timeline.startSync('Puck.$name');
    try {
      return action();
    } finally {
      developer.Timeline.finishSync();
      events.add({
        'name': name,
        'ts': start,
        'dur': developer.Timeline.now - start,
        'phase': _phase,
      });
    }
  }
}
