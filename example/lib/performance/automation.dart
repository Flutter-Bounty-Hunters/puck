// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:puck/src/spring_puck.dart';
import 'package:puck/src/puck_opening_trace.dart';

import 'frame_metrics.dart';
import 'performance_demo.dart';

class _Phase {
  _Phase(this.name, this.repetition, this.startUs, this.initial);
  final String name;
  final int repetition;
  final int startUs;
  final List<Offset> initial;
  final markers = <String, int>{};
  final inputs = <Map<String, Object?>>[];
  int? referenceUs;
  int? endUs;
  void mark(String key, int now) => markers.putIfAbsent(key, () {
    PuckOpeningTrace.instant('milestone.$key', {'observed_us': now});
    return now;
  });
}

class _ItemSensor {
  _ItemSensor(this.box, this.spring);
  final RenderBox box;
  final Element spring;
  SpringPuck get widget => spring.widget as SpringPuck;
  Offset get center =>
      (box.parentData! as StackParentData).offset +
      box.size.center(Offset.zero);
}

/// Sends timestamped events through Flutter's normal gesture pipeline. It
/// measures framework/engine behavior, not OS touch dispatch or scanout latency.
class PerformanceAutomation with WidgetsBindingObserver {
  PerformanceAutomation(
    this.config,
    this.handles, {
    required this.mainEnteredUs,
  });
  final PerformanceConfig config;
  final PerformanceHandles handles;
  final int mainEnteredUs;
  int? _firstFrameworkFrameUs;
  int? _interactiveReadyUs;
  final _frames = <FrameTiming>[];
  final _phases = <_Phase>[];
  final _items = <_ItemSensor>[];
  final _errors = <String>[];
  final _lifecycleEvents = <Map<String, Object?>>[];
  _Phase? _active;
  late RenderBox _root;
  late RenderBox _overlay;
  late Size _bounds;
  late double _displayRefreshRate;
  bool _finished = false;
  bool _pointerDown = false;
  int _pointer = 0;
  Offset _finger = Offset.zero;
  Map<String, Object?>? _report;

  static RenderBox _stackChild(GlobalKey key) {
    RenderObject node = key.currentContext!.findRenderObject()!;
    while (node.parent is! RenderStack) {
      final parent = node.parent;
      if (parent == null) {
        throw StateError('Performance fixture lost its Stack');
      }
      node = parent;
    }
    if (node is! RenderBox || node.parentData is! StackParentData) {
      throw StateError('Expected a positioned performance fixture');
    }
    return node;
  }

  Offset get _rootCenter =>
      (_root.parentData! as StackParentData).offset +
      _root.size.center(Offset.zero);
  List<Offset> _snapshot() => [
    _rootCenter,
    for (final item in _items) item.center,
  ];

  Future<void> start() async {
    if (config.openingProfile) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleEvents.add({
        'ts': developer.Timeline.now,
        'state': WidgetsBinding.instance.lifecycleState?.name,
      });
    }
    developer.registerExtension(
      'ext.puck.performance',
      (method, parameters) async => developer.ServiceExtensionResponse.result(
        jsonEncode({
          'done': _finished,
          'current': _active?.name,
          'completed': _phases.length,
          'report': _report,
          'errors': _errors,
          'photo_ready_us': handles.photoReadyUs,
        }),
      ),
    );
    final previousError = FlutterError.onError;
    FlutterError.onError = (details) {
      _errors.add(details.exceptionAsString());
      previousError?.call(details);
    };
    SchedulerBinding.instance.addTimingsCallback(_frames.addAll);
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (!_finished) SchedulerBinding.instance.addPostFrameCallback(_observe);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _firstFrameworkFrameUs = developer.Timeline.now;
      try {
        await Future<void>.delayed(Duration(milliseconds: config.startDelayMs));
        _overlay =
            handles.overlay.currentContext!.findRenderObject()! as RenderBox;
        _bounds = _overlay.size;
        _root = _stackChild(handles.root);
        _displayRefreshRate = View.of(handles.overlay.currentContext!)
            .display
            .refreshRate;
        for (final key in handles.items) {
          Element? spring;
          key.currentContext!.visitAncestorElements((element) {
            if (element.widget is SpringPuck) {
              spring = element;
              return false;
            }
            return true;
          });
          if (spring == null) throw StateError('Missing spring item');
          _items.add(_ItemSensor(_stackChild(key), spring!));
        }
        if (handles.expanded.value) {
          throw StateError('Cold opening was contaminated by an earlier open');
        }
        // Engine frames can run before iOS finishes activating the window.
        // A real user cannot tap then; keep app startup out of menu latency.
        final readinessDeadline = developer.Timeline.now + 10000000;
        while (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          if (developer.Timeline.now > readinessDeadline) {
            throw TimeoutException('App never became active for input');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await WidgetsBinding.instance.endOfFrame;
        _interactiveReadyUs = developer.Timeline.now;
        await _suite();
        // The engine delivers frame timings in batches, including when idle.
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        _report = _buildReport();
      } catch (error, stack) {
        _errors.add('$error\n$stack');
        _active?.endUs = developer.Timeline.now;
        _report = _items.isEmpty
            ? {
                'config': config.toJson(),
                'scenarios': [],
                'success': false,
                'errors': _errors,
                'mode': kProfileMode ? 'profile' : 'debug',
              }
            : _buildReport();
      } finally {
        if (config.openingProfile) WidgetsBinding.instance.removeObserver(this);
        if (_pointerDown) {
          GestureBinding.instance.handlePointerEvent(
            PointerCancelEvent(
              pointer: _pointer,
              position: _finger,
              timeStamp: _stamp(),
            ),
          );
          _pointerDown = false;
        }
        _finished = true;
        SchedulerBinding.instance.removeTimingsCallback(_frames.addAll);
        FlutterError.onError = previousError;
        stdout.writeln(
          'PUCK_PERFORMANCE_DONE ${jsonEncode({'variant': config.variant, 'success': _errors.isEmpty, 'scenarios': _phases.length})}',
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleEvents.add({'ts': developer.Timeline.now, 'state': state.name});
  }

  void _observe(Duration _) {
    final phase = _active;
    if (phase == null || _items.isEmpty) return;
    final now = developer.Timeline.now;
    PuckOpeningTrace.instant('frame.post_layout', {
      'system_frame_us':
          SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds,
    });
    final points = _snapshot();
    if ((points.first - phase.initial.first).distance > 1) {
      phase.mark('first_root_motion', now);
    }
    if (List.generate(
      _items.length,
      (i) => (points[i + 1] - phase.initial[i + 1]).distance,
    ).any((distance) => distance > .5)) {
      phase.mark('first_item_motion', now);
    }
    final hidden = (performanceRootDiameter - performanceItemDiameter) / 2;
    if (phase.name.contains('open') &&
        !phase.name.startsWith('open_') &&
        handles.expanded.value &&
        points
            .skip(1)
            .any((point) => (point - points.first).distance > hidden + .5)) {
      phase.mark('first_item_emergence', now);
      for (var i = 0; i < _items.length; i++) {
        if ((points[i + 1] - points.first).distance > hidden + .5 &&
            (!config.photos || handles.photoReadyUs.containsKey('item-$i'))) {
          phase.mark('first_content_emergence', now);
          break;
        }
      }
    }
    if (phase.name.contains('close') &&
        !phase.name.startsWith('closed_') &&
        !handles.expanded.value &&
        points
            .skip(1)
            .every((point) => (point - points.first).distance <= hidden + .5)) {
      phase.mark('fully_covered', now);
    }
    if (phase.name.endsWith('release')) {
      final expected = phase.initial.first.dx < _bounds.width / 2
          ? 25.6
          : _bounds.width - 25.6;
      if ((points.first.dx - expected).abs() <= .5) {
        phase.mark('first_wall_contact', now);
      }
    }
  }

  _Phase _begin(String name, {int repetition = 1, int? startUs}) {
    if (_active != null) throw StateError('Overlapping benchmark phases');
    final phase = _Phase(
      name,
      repetition,
      startUs ?? developer.Timeline.now,
      _snapshot(),
    );
    _phases.add(phase);
    _active = phase;
    developer.Timeline.instantSync(
      'Performance.$name.start',
      arguments: {'repetition': repetition},
    );
    return phase;
  }

  void _end() {
    _active!.endUs = developer.Timeline.now;
    developer.Timeline.instantSync('Performance.${_active!.name}.end');
    _active = null;
    PuckOpeningTrace.end();
  }

  Duration _stamp() => Duration(microseconds: developer.Timeline.now);

  void _down() {
    if (_pointerDown) throw StateError('Pointer already down');
    _pointer++;
    _finger = _overlay.localToGlobal(_rootCenter);
    _pointerDown = true;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(
        pointer: _pointer,
        position: _finger,
        timeStamp: _stamp(),
      ),
    );
  }

  void _up({String? measuredPhase, int repetition = 1}) {
    final releasedUs = developer.Timeline.now;
    if (measuredPhase != null) {
      PuckOpeningTrace.begin(measuredPhase);
      _begin(measuredPhase, repetition: repetition, startUs: releasedUs);
    }
    _active?.referenceUs = releasedUs;
    PuckOpeningTrace.instant('input.up.dispatch.begin', {
      'released_us': releasedUs,
      'lifecycle': WidgetsBinding.instance.lifecycleState?.name,
      'scheduler_phase': SchedulerBinding.instance.schedulerPhase.name,
      'frame_scheduled': SchedulerBinding.instance.hasScheduledFrame,
      'frames_enabled': SchedulerBinding.instance.framesEnabled,
    });
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(
        pointer: _pointer,
        position: _finger,
        timeStamp: Duration(microseconds: releasedUs),
      ),
    );
    PuckOpeningTrace.instant('input.up.dispatch.end');
    if (PuckOpeningTrace.enabled && measuredPhase != null) {
      SchedulerBinding.instance.scheduleFrameCallback((stamp) {
        PuckOpeningTrace.instant('frame.animation_callbacks', {
          'frame_us': stamp.inMicroseconds,
          'system_frame_us': SchedulerBinding
              .instance
              .currentSystemFrameTimeStamp
              .inMicroseconds,
        });
      });
    }
    _pointerDown = false;
  }

  Future<void> _tap({String? measuredPhase, int repetition = 1}) async {
    final wasExpanded = handles.expanded.value;
    _down();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    _up(measuredPhase: measuredPhase, repetition: repetition);
    if (handles.expanded.value == wasExpanded) {
      throw StateError('Root tap did not toggle the menu');
    }
  }

  Future<void> _settle({bool release = false}) async {
    final started = developer.Timeline.now;
    final deadline = started + 6000000;
    var last = _snapshot();
    var stableSince = developer.Timeline.now;
    while (developer.Timeline.now < deadline) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final now = developer.Timeline.now;
      final current = _snapshot();
      if (List.generate(
        current.length,
        (i) => (current[i] - last[i]).distance,
      ).any((d) => d > .1)) {
        stableSince = now;
      }
      last = current;
      final itemsReady = handles.expanded.value
          ? _items.every(
              (item) =>
                  item.widget.expanded &&
                  (item.center - (item.widget.target + const Offset(24, 24)))
                          .distance <
                      .75,
            )
          : _items.every((item) => item.widget.dormant);
      final photosReady =
          !config.photos ||
          !handles.expanded.value ||
          handles.photoReadyUs.keys
                  .where((key) => key.startsWith('item-'))
                  .length ==
              config.itemCount;
      final atWall =
          !release ||
          math.min(
                (current.first.dx - 25.6).abs(),
                (current.first.dx - (_bounds.width - 25.6)).abs(),
              ) <
              .5;
      if (itemsReady &&
          photosReady &&
          atWall &&
          now - stableSince >= 140000 &&
          (!release || now - started >= 1200000)) {
        _active?.mark('settled', now);
        return;
      }
    }
    throw TimeoutException(
      'Menu did not settle in ${_active?.name ?? 'setup'}',
    );
  }

  Future<void> _openClose(String name, int repetition) async {
    await _tap(measuredPhase: name, repetition: repetition);
    await _settle();
    _end();
  }

  Future<void> _movePath(List<Offset> localPoints, int durationMs) async {
    final points = [
      _finger,
      for (final point in localPoints) _overlay.localToGlobal(point),
    ];
    final start = developer.Timeline.now;
    _active?.referenceUs ??= start;
    final duration = durationMs * 1000;
    while (true) {
      final now = developer.Timeline.now;
      final t = ((now - start) / duration).clamp(0.0, 1.0);
      final segment = math.min(
        points.length - 2,
        (t * (points.length - 1)).floor(),
      );
      final fraction = t == 1 ? 1.0 : t * (points.length - 1) - segment;
      final position = Offset.lerp(
        points[segment],
        points[segment + 1],
        fraction,
      )!;
      final delta = position - _finger;
      _finger = position;
      _active?.inputs.add({
        'dispatched_us': now,
        'planned_progress': t,
        'x': position.dx,
        'y': position.dy,
      });
      GestureBinding.instance.handlePointerEvent(
        PointerMoveEvent(
          pointer: _pointer,
          position: position,
          delta: delta,
          timeStamp: Duration(microseconds: now),
        ),
      );
      if (t >= 1) break;
      // Nominal ~120Hz input. Motion follows elapsed wall time and coalesces
      // naturally if the UI thread stalls; it does not slow the path down.
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
  }

  Future<void> _dragSequence(bool open) async {
    if (handles.expanded.value != open) {
      await _tap();
      await _settle();
    }
    final prefix = open ? 'open' : 'closed';
    final phase = _begin('${prefix}_pull');
    _down();
    final direction = _rootCenter.dx < _bounds.width / 2 ? 1 : -1;
    await _movePath([
      _rootCenter + Offset(direction * math.min(80, _bounds.width * .2), 0),
    ], 300);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    phase.mark('pull_complete', developer.Timeline.now);
    _end();

    _begin('${prefix}_rapid_drag');
    final w = _bounds.width;
    final h = _bounds.height;
    await _movePath([
      Offset(w * .25, h * .28),
      Offset(w * .75, h * .72),
      Offset(w * .25, h * .72),
      Offset(w * .75, h * .28),
      Offset(w * .38, h * .5),
      Offset(w * .65, h * .5),
    ], 1500);
    _end();

    _begin('${prefix}_release');
    _up();
    await _settle(release: true);
    _end();
  }

  Future<void> _suite() async {
    await _openClose('first_open', 1);
    for (var i = 1; i <= config.repeats; i++) {
      await _openClose('repeat_close', i);
      await _openClose('repeat_open', i);
    }
    if (!config.openingProfile) {
      await _dragSequence(false);
      await _dragSequence(true);
    }
  }

  Map<String, Object?> _buildReport() {
    final frames = [
      for (final frame in _frames)
        <String, int>{
          'frame_number': frame.frameNumber,
          'vsync_us': frame.timestampInMicroseconds(FramePhase.vsyncStart),
          'build_start_us': frame.timestampInMicroseconds(
            FramePhase.buildStart,
          ),
          'raster_finish_us': frame.timestampInMicroseconds(
            FramePhase.rasterFinish,
          ),
          'build_us': frame.buildDuration.inMicroseconds,
          'raster_us': frame.rasterDuration.inMicroseconds,
          'total_us': frame.totalSpan.inMicroseconds,
        },
    ];
    return {
      'schema_version': 1,
      if (PuckOpeningTrace.enabled)
        'opening_trace_events': PuckOpeningTrace.events,
      if (config.openingProfile) 'lifecycle_events': _lifecycleEvents,
      if (config.openingProfile) 'diagnostic_frames': frames,
      'open_close_measurement_start': 'pointer_up',
      'interaction_readiness': 'resumed_after_frame',
      'startup': {
        'main_entered_us': mainEnteredUs,
        'first_framework_frame_us': _firstFrameworkFrameUs,
        'interactive_ready_us': _interactiveReadyUs,
        'first_request_after_main_ms': _phases.isEmpty
            ? null
            : (_phases.first.startUs - mainEnteredUs) / 1000,
      },
      'native_shader_filters_supported': ui.ImageFilter.isShaderFilterSupported,
      'success': _errors.isEmpty,
      'config': config.toJson(),
      'mode': kProfileMode
          ? 'profile'
          : kReleaseMode
          ? 'release'
          : 'debug',
      'platform': defaultTargetPlatform.name,
      'viewport': {'width': _bounds.width, 'height': _bounds.height},
      'display_refresh_rate_hz': _displayRefreshRate,
      'errors': _errors,
      'photo_ready_us': handles.photoReadyUs,
      'instrumentation':
          'Timestamped synthetic Flutter pointer events; post-frame geometry observations. '
          'No OS input or hardware scanout measurement. Startup does not auto-open/precache photos.',
      'scenarios': [
        for (final phase in _phases)
          {
            'name': phase.name,
            'repetition': phase.repetition,
            'start_us': phase.startUs,
            'end_us': phase.endUs,
            'reference_us': phase.referenceUs ?? phase.startUs,
            'duration_ms':
                ((phase.endUs ?? developer.Timeline.now) - phase.startUs) /
                1000,
            'milestones_ms': {
              for (final entry in phase.markers.entries)
                entry.key:
                    (entry.value - (phase.referenceUs ?? phase.startUs)) / 1000,
            },
            'input_sample_count': phase.inputs.length,
            'input_samples': phase.inputs,
            'metrics': summarizeFrames(
              frames
                  .where(
                    (f) =>
                        f['build_start_us']! >= phase.startUs &&
                        f['build_start_us']! <
                            (phase.endUs ?? developer.Timeline.now),
                  )
                  .toList(),
              config.budgetFps,
            ),
            'frames': frames
                .where(
                  (f) =>
                      f['build_start_us']! >= phase.startUs &&
                      f['build_start_us']! <
                          (phase.endUs ?? developer.Timeline.now),
                )
                .toList(),
          },
      ],
    };
  }
}
