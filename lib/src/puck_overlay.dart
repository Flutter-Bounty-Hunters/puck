import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The horizontal edge to which a puck docks.
enum PuckEdge { left, right }

/// Places a draggable circular [puck] above [child].
///
/// Requires bounded constraints. Wrap this widget in [SafeArea] to make safe
/// area insets collision boundaries. Only the puck intercepts pointer events.
/// Ten percent of its diameter extends beyond the horizontal edge when docked.
class PuckOverlay extends StatefulWidget {
  const PuckOverlay({
    super.key,
    required this.puck,
    required this.child,
    this.diameter = 64,
    this.offscreenFraction = 0.1,
    this.initialEdge = PuckEdge.right,
    this.initialVerticalAlignment = 0.5,
    this.onTap,
  }) : assert(diameter > 0 && diameter < double.infinity),
       assert(offscreenFraction >= 0 && offscreenFraction <= 0.5),
       assert(initialVerticalAlignment >= 0 && initialVerticalAlignment <= 1);

  /// Developer-provided content, clipped to a circle of [diameter].
  final Widget puck;
  final Widget child;
  final double diameter;

  /// Fraction of the diameter hidden beyond the docking edge.
  final double offscreenFraction;
  final PuckEdge initialEdge;

  /// Initial vertical position: zero is the top, one is the bottom.
  final double initialVerticalAlignment;
  final VoidCallback? onTap;

  @override
  State<PuckOverlay> createState() => _PuckOverlayState();
}

class _PuckOverlayState extends State<PuckOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Size? _size;
  bool _geometryChanged = false;
  Offset _position = Offset.zero;
  Offset? _grabOffset;
  SpringSimulation? _horizontal;
  FrictionSimulation? _vertical;
  late PuckEdge _edge = widget.initialEdge;
  double _targetX = 0;

  double get _left => -widget.diameter * widget.offscreenFraction;
  double get _right => math.max(_left, _size!.width - widget.diameter - _left);
  double get _bottom => math.max(0, _size!.height - widget.diameter);

  Offset _bounded(Offset position) =>
      Offset(position.dx.clamp(_left, _right), position.dy.clamp(0, _bottom));

  void _tick(Duration elapsed) {
    final time = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final x = _horizontal!;
    final y = _vertical!;
    setState(() {
      _position = _bounded(Offset(x.x(time), y.x(time)));
      // Contact with a vertical boundary absorbs vertical momentum.
      final hitBoundary = y.x(time) <= 0 || y.x(time) >= _bottom;
      if (x.isDone(time) && (y.isDone(time) || hitBoundary)) {
        _position = Offset(_targetX, _position.dy);
        _ticker.stop();
      }
    });
  }

  void _dock(Offset velocity) {
    _ticker.stop();
    // Momentum carries the puck vertically, while the nearest horizontal edge
    // attracts it. Horizontal release velocity feeds directly into the spring.
    _edge = (_position.dx + widget.diameter / 2 < _size!.width / 2)
        ? PuckEdge.left
        : PuckEdge.right;
    _targetX = _edge == PuckEdge.left ? _left : _right;
    _horizontal = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 220, damping: 26),
      _position.dx,
      _targetX,
      velocity.dx,
    );
    // Strong drag keeps incidental vertical motion from becoming a long glide.
    // FrictionSimulation uses exponential decay: a smaller factor stops sooner.
    _vertical = FrictionSimulation(0.0001, _position.dy, velocity.dy);
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant PuckOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _geometryChanged =
        oldWidget.diameter != widget.diameter ||
        oldWidget.offscreenFraction != widget.offscreenFraction;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth && constraints.hasBoundedHeight,
          'PuckOverlay requires bounded width and height.',
        );
        final size = constraints.biggest;
        final firstLayout = _size == null;
        if (_size != size || _geometryChanged) {
          _geometryChanged = false;
          _ticker.stop();
          _size = size;
          _position = Offset(
            _edge == PuckEdge.left ? _left : _right,
            firstLayout
                ? _bottom * widget.initialVerticalAlignment
                : _position.dy.clamp(0, _bottom),
          );
        }
        _position = _bounded(_position);
        return Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            widget.child,
            Positioned(
              left: _position.dx,
              top: _position.dy,
              width: widget.diameter,
              height: widget.diameter,
              child: ClipOval(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  onPanDown: (details) {
                    _ticker.stop();
                    _grabOffset = details.localPosition;
                  },
                  onPanUpdate: (details) {
                    final box = context.findRenderObject()! as RenderBox;
                    setState(() {
                      _position = _bounded(
                        box.globalToLocal(details.globalPosition) -
                            _grabOffset!,
                      );
                    });
                  },
                  onPanEnd: (details) =>
                      _dock(details.velocity.pixelsPerSecond),
                  onPanCancel: () => _dock(Offset.zero),
                  onTapUp: (_) => _dock(Offset.zero),
                  child: widget.puck,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
