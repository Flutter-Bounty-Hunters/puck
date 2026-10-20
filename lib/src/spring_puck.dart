import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Retargets a two-dimensional spring without discarding its current velocity.
class SpringPuck extends StatefulWidget {
  const SpringPuck({
    super.key,
    required this.origin,
    required this.target,
    required this.diameter,
    required this.bounds,
    required this.horizontalInset,
    required this.expanded,
    required this.onCollapsed,
    required this.child,
  });

  final Offset origin;
  final Offset target;
  final double diameter;
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

  @override
  void initState() {
    super.initState();
    _retarget();
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
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    setState(() {
      _position = Offset(_x!.x(t), _y!.x(t));
      _velocity = Offset(_x!.dx(t), _y!.dx(t));
      if (_x!.isDone(t) && _y!.isDone(t)) {
        _position = widget.target;
        _velocity = Offset.zero;
        _ticker.stop();
        if (!widget.expanded) widget.onCollapsed();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SpringPuck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target ||
        oldWidget.expanded != widget.expanded) {
      _retarget();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Expanded pucks stay visible even when a spring overshoots its anchor.
    final position = widget.expanded
        ? Offset(
            _position.dx.clamp(
              widget.horizontalInset,
              widget.bounds.width - widget.diameter - widget.horizontalInset,
            ),
            _position.dy.clamp(0, widget.bounds.height - widget.diameter),
          )
        : _position;
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
