import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'puck_cables.dart';
import 'puck_opening_trace.dart';
import 'puck_tier_curves.dart';

/// Retargets a two-dimensional spring without discarding its current velocity.
class SpringPuck extends StatefulWidget {
  const SpringPuck({
    super.key,
    required this.origin,
    this.delay = Duration.zero,
    this.motionClock,
    required this.cables,
    required this.showRopes,
    this.curves,
    this.tier = 0,
    this.order = 0,
    this.dormant = false,
    required this.target,
    required this.diameter,
    required this.parentDiameter,
    required this.bounds,
    required this.horizontalInset,
    required this.expanded,
    required this.onCollapsed,
    required this.child,
  });

  final Offset origin;
  final Duration delay;

  /// Shared clock started when opening/closing is requested, before layout.
  final Stopwatch? motionClock;
  final PuckCables cables;
  final bool showRopes;
  final PuckTierCurves? curves;
  final int tier;
  final int order;

  /// Retained closed items track their parent without running a spring.
  final bool dormant;
  final Offset target;
  final double diameter;
  final double parentDiameter;
  final Size bounds;
  final double horizontalInset;
  final bool expanded;
  final VoidCallback onCollapsed;
  final Widget child;

  @override
  State<SpringPuck> createState() => _SpringPuckState();
}

class _SpringPuckState extends State<SpringPuck>
    with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 240,
    damping: 24,
  );
  late final Ticker _ticker = createTicker(_tick);
  late Offset _position = widget.origin;
  Offset _velocity = Offset.zero;
  SpringSimulation? _x;
  SpringSimulation? _y;
  _MenuRope? _rope;
  double _lastTime = 0;
  double? _settlingSince;
  Timer? _delayTimer;
  Duration _elapsedOffset = Duration.zero;
  Stopwatch? _firstTickClock;
  bool _hasAdvanced = false;
  int _traceTicks = 0;

  @override
  void initState() {
    super.initState();
    _scheduleRetarget();
  }

  void _scheduleRetarget() {
    if (widget.dormant) return;
    if (PuckOpeningTrace.representative(widget.tier, widget.order)) {
      PuckOpeningTrace.instant('spring.schedule', {
        'tier': widget.tier,
        'delay_us': widget.delay.inMicroseconds,
      });
    }
    _delayTimer?.cancel();
    _delayTimer = null;
    _ticker.stop();
    // Tier delays begin at the request, not after the layout/preparation frame.
    final remaining =
        widget.delay - (widget.motionClock?.elapsed ?? Duration.zero);
    void launch() {
      final elapsed = widget.motionClock == null
          ? Duration.zero
          : widget.motionClock!.elapsed - widget.delay;
      _retarget(elapsed: elapsed < Duration.zero ? Duration.zero : elapsed);
    }

    if (remaining <= Duration.zero) {
      launch();
    } else {
      _delayTimer = Timer(remaining, () {
        _delayTimer = null;
        if (mounted) launch();
      });
    }
  }

  void _retarget({Duration elapsed = Duration.zero}) {
    _traceTicks = 0;
    if (PuckOpeningTrace.representative(widget.tier, widget.order)) {
      PuckOpeningTrace.instant('spring.retarget', {'tier': widget.tier});
    }
    _ticker.stop();
    _x = SpringSimulation(
      _spring,
      _position.dx,
      widget.target.dx,
      _velocity.dx,
    );
    _y = SpringSimulation(
      _spring,
      _position.dy,
      widget.target.dy,
      _velocity.dy,
    );
    _lastTime = 0;
    _settlingSince = null;
    _elapsedOffset = Duration(
      microseconds: (elapsed.inMicroseconds / timeDilation).round(),
    );
    // Tickers started outside a frame establish their origin on their first
    // callback. Count that wait too, rather than delivering a zero-time tick.
    final phase = SchedulerBinding.instance.schedulerPhase;
    _firstTickClock =
        phase == SchedulerPhase.idle ||
            phase == SchedulerPhase.postFrameCallbacks
        ? (WidgetsBinding.instance.samplingClock.stopwatch()..start())
        : null;
    _ticker.start();
    if (PuckOpeningTrace.representative(widget.tier, widget.order)) {
      PuckOpeningTrace.instant('spring.ticker.started', {'tier': widget.tier});
    }
    // Layout already has the new target. Sample now so this very frame can
    // paint movement instead of waiting for the next animation callback.
    if (widget.expanded && _elapsedOffset > Duration.zero) {
      _tick(Duration.zero, eager: true);
    }
  }

  void _tick(Duration elapsed, {bool eager = false}) {
    if (!eager && _firstTickClock != null) {
      _elapsedOffset += Duration(
        microseconds: (_firstTickClock!.elapsedMicroseconds / timeDilation)
            .round(),
      );
      _firstTickClock = null;
    }
    final simulationElapsed = elapsed + _elapsedOffset;
    if (PuckOpeningTrace.enabled &&
        _traceTicks++ < 3 &&
        PuckOpeningTrace.representative(widget.tier, widget.order)) {
      PuckOpeningTrace.instant('spring.tick', {
        'tier': widget.tier,
        'tick': _traceTicks,
        'elapsed_us': simulationElapsed.inMicroseconds,
        'eager': eager,
      });
    }
    final t = simulationElapsed.inMicroseconds / Duration.microsecondsPerSecond;
    setState(() {
      _hasAdvanced = _hasAdvanced || t > 0;
      _position = Offset(_x!.x(t), _y!.x(t));
      _velocity = Offset(_x!.dx(t), _y!.dx(t));
      final arrived = _x!.isDone(t) && _y!.isDone(t);
      if (arrived) {
        _position = widget.target;
        _velocity = Offset.zero;
      }
      // A circular item is fully occluded when its outer edge fits inside
      // the parent. Do not keep its subtree alive for the spring's long tail.
      final hidden = (widget.parentDiameter - widget.diameter) / 2;
      if (!widget.expanded &&
          (arrived ||
              (hidden >= 0 &&
                  (_position - widget.origin).distance <= hidden))) {
        _ticker.stop();
        widget.onCollapsed();
        return;
      }
      if (widget.showRopes) {
        final half = Offset(widget.diameter / 2, widget.diameter / 2);
        (_rope ??= _MenuRope()).advance(
          widget.origin + half,
          _visiblePosition + half,
          math.max((widget.target - widget.origin).distance, widget.diameter),
          (t - _lastTime).clamp(0, 1 / 15),
        );
      }
      _lastTime = t;
      if (arrived) {
        _settlingSince ??= t;
        if (!widget.showRopes || _rope!.atRest || t - _settlingSince! > 3) {
          _ticker.stop();
          if (!widget.expanded) widget.onCollapsed();
        }
      }
    });
    if (widget.showRopes) widget.cables.repaint();
    widget.curves?.repaint();
  }

  @override
  void didUpdateWidget(covariant SpringPuck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.curves != widget.curves) oldWidget.curves?.remove(this);
    if (widget.dormant) {
      _delayTimer?.cancel();
      _delayTimer = null;
      _ticker.stop();
      _position = widget.origin;
      _velocity = Offset.zero;
      _hasAdvanced = false;
      _rope = null;
      widget.cables.remove(this);
      return;
    }
    if (oldWidget.showRopes != widget.showRopes) {
      _rope = null;
      if (!widget.showRopes) widget.cables.remove(this);
    }
    if (oldWidget.target != widget.target ||
        oldWidget.expanded != widget.expanded ||
        oldWidget.origin != widget.origin ||
        oldWidget.showRopes != widget.showRopes) {
      if (oldWidget.expanded != widget.expanded) {
        _scheduleRetarget();
      } else if (_delayTimer == null) {
        _retarget();
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    widget.curves?.remove(this);
    widget.cables.remove(this);
    _ticker.dispose();
    super.dispose();
  }

  // Use the same endpoint for painting and positioning, including at bounds.
  Offset get _visiblePosition => Offset(
    widget.expanded && _hasAdvanced
        ? _position.dx.clamp(
            widget.horizontalInset,
            widget.bounds.width - widget.diameter - widget.horizontalInset,
          )
        : _position.dx,
    _position.dy.clamp(0, math.max(0, widget.bounds.height - widget.diameter)),
  );

  @override
  Widget build(BuildContext context) {
    final position = _visiblePosition;
    widget.curves?.update(
      this,
      bounds: position & Size.square(widget.diameter),
      tier: widget.tier,
      order: widget.order,
    );
    if (widget.showRopes) {
      widget.cables.update(
        this,
        points: List.of(_rope?.points ?? const <Offset>[]),
        bounds: position & Size.square(widget.diameter),
      );
    }
    return Positioned(
      left: position.dx,
      top: position.dy,
      width: widget.diameter,
      height: widget.diameter,
      child: IgnorePointer(
        ignoring: !widget.expanded,
        child: ExcludeSemantics(
          excluding: !widget.expanded,
          child: Offstage(
            offstage: widget.dormant && widget.diameter > widget.parentDiameter,
            child: ClipOval(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// A fixed-length Verlet rope. Only the endpoints are pinned; the interior
/// retains momentum when the menu reverses or its parent moves.
class _MenuRope {
  static const segments = 16;
  final points = <Offset>[];
  final _previous = <Offset>[];
  bool atRest = false;

  void advance(Offset start, Offset end, double length, double elapsed) {
    if (points.isEmpty) {
      for (var i = 0; i <= segments; i++) {
        final fraction = i / segments;
        final point =
            Offset.lerp(start, end, fraction)! +
            Offset(
              -length * 0.18 * math.sin(fraction * math.pi * 2),
              length * 0.4 * math.sin(fraction * math.pi),
            );
        points.add(point);
        _previous.add(point);
      }
    }
    final steps = math.max(1, (elapsed * 120).ceil());
    final dt = elapsed / steps;
    final segmentLength = math.max(length, (end - start).distance) / segments;
    var movement = 0.0;
    for (var step = 0; step < steps; step++) {
      for (var i = 1; i < segments; i++) {
        final current = points[i];
        final velocity =
            (current - _previous[i]) * math.pow(0.08, dt).toDouble();
        _previous[i] = current;
        points[i] = current + velocity + Offset(0, 700 * dt * dt);
      }
      for (var iteration = 0; iteration < 32; iteration++) {
        points[0] = start;
        points[segments] = end;
        for (var i = 0; i < segments; i++) {
          final delta = points[i + 1] - points[i];
          final distance = delta.distance;
          if (distance < 0.00001) continue;
          final correction = delta * ((distance - segmentLength) / distance);
          if (i == 0) {
            points[i + 1] -= correction;
          } else if (i + 1 == segments) {
            points[i] += correction;
          } else {
            points[i] += correction / 2;
            points[i + 1] -= correction / 2;
          }
        }
      }
      points[0] = start;
      points[segments] = end;
    }
    for (var i = 1; i < segments; i++) {
      movement = math.max(movement, (points[i] - _previous[i]).distance);
    }
    atRest = movement < 0.025;
  }
}
