import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'puck_cables.dart';

/// Retargets a two-dimensional spring without discarding its current velocity.
class SpringPuck extends StatefulWidget {
  const SpringPuck({
    super.key,
    required this.origin,
    required this.cables,
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
  final PuckCables cables;
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
  final _rope = _MenuRope();
  double _lastTime = 0;
  double? _settlingSince;
  bool _prepared = false;
  bool _hasAdvanced = false;

  @override
  void initState() {
    super.initState();
    // Build, lay out, and paint the child under its parent before starting
    // its ticker. Keep the latest target if the menu changes in this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prepared = true;
      _retarget();
    });
  }

  void _retarget() {
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
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
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
      final half = Offset(widget.diameter / 2, widget.diameter / 2);
      _rope.advance(
        widget.origin + half,
        _visiblePosition + half,
        math.max((widget.target - widget.origin).distance, widget.diameter),
        (t - _lastTime).clamp(0, 1 / 15),
      );
      _lastTime = t;
      if (arrived) {
        _settlingSince ??= t;
        if (!widget.expanded || _rope.atRest || t - _settlingSince! > 3) {
          _ticker.stop();
          if (!widget.expanded) widget.onCollapsed();
        }
      }
    });
    widget.cables.repaint();
  }

  @override
  void didUpdateWidget(covariant SpringPuck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_prepared &&
        (oldWidget.target != widget.target ||
            oldWidget.expanded != widget.expanded ||
            oldWidget.origin != widget.origin)) {
      _retarget();
    }
  }

  @override
  void dispose() {
    widget.cables.remove(this);
    _ticker.dispose();
    super.dispose();
  }

  // Use the same endpoint for painting and positioning, including at bounds.
  Offset get _visiblePosition => widget.expanded && _hasAdvanced
      ? Offset(
          _position.dx.clamp(
            widget.horizontalInset,
            widget.bounds.width - widget.diameter - widget.horizontalInset,
          ),
          _position.dy.clamp(0, widget.bounds.height - widget.diameter),
        )
      : _position;

  @override
  Widget build(BuildContext context) {
    final position = _visiblePosition;
    widget.cables.update(
      this,
      points: List.of(_rope.points),
      bounds: position & Size.square(widget.diameter),
    );
    return Positioned(
      left: position.dx,
      top: position.dy,
      width: widget.diameter,
      height: widget.diameter,
      child: IgnorePointer(
        ignoring: !widget.expanded,
        child: ExcludeSemantics(
          excluding: !widget.expanded,
          child: ClipOval(child: widget.child),
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
