import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'spring_puck.dart';
import 'puck_anchor_painter.dart';

/// The horizontal edge to which a puck docks.
enum PuckEdge { left, right }

enum _MenuPhase { closed, expanded, collapsing }

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
    this.onLongPress,
    this.showDebugAnchors = false,
    this.menuItems = const [],
    this.menuRadius = 112,
    this.menuItemDiameter = 48,
  }) : assert(diameter > 0 && diameter < double.infinity),
       assert(offscreenFraction >= 0 && offscreenFraction <= 0.5),
       assert(initialVerticalAlignment >= 0 && initialVerticalAlignment <= 1),
       assert(menuRadius > 0 && menuRadius < double.infinity),
       assert(menuItemDiameter > 0 && menuItemDiameter < double.infinity);

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

  /// Called when the main puck is long-pressed.
  final VoidCallback? onLongPress;

  /// Paint small red dots at current spring destinations. During dragging the
  /// main anchor follows the puck; during docking it shows its final position.
  /// Menu anchors appear only while their pucks are mounted.
  final bool showDebugAnchors;

  /// Circular menu contents, painted below the main puck. Supply interactive
  /// widgets (for example, buttons) to handle individual item selections.
  /// Give items stable keys when inserting or reordering them.
  final List<Widget> menuItems;

  /// Distance from the main puck center to the expanded menu item centers.
  final double menuRadius;
  final double menuItemDiameter;

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
  _MenuPhase _menuPhase = _MenuPhase.closed;
  bool get _expanded => _menuPhase == _MenuPhase.expanded;
  final Set<Object> _pendingCollapse = {};
  int _menuGeneration = 0;

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

  void _toggleMenu() {
    setState(() {
      _menuGeneration++;
      _pendingCollapse.clear();
      if (_expanded) {
        _pendingCollapse.addAll([
          for (var i = 0; i < widget.menuItems.length; i++)
            widget.menuItems[i].key ?? i,
        ]);
        _menuPhase = _pendingCollapse.isEmpty
            ? _MenuPhase.closed
            : _MenuPhase.collapsing;
      } else {
        _menuPhase = _MenuPhase.expanded;
      }
    });
    widget.onTap?.call();
  }

  void _itemCollapsed(Object identity, int generation) {
    if (_menuPhase != _MenuPhase.collapsing || generation != _menuGeneration) {
      return;
    }
    setState(() {
      _pendingCollapse.remove(identity);
      if (_pendingCollapse.isEmpty) _menuPhase = _MenuPhase.closed;
    });
  }

  // Reduce the inset only when the container cannot fit the item plus 48px.
  double _menuInset(double itemDiameter) =>
      math.min(24, math.max(0, (_size!.width - itemDiameter) / 2));

  // Exact visible arc on the inward semicircle for a given clear edge gap.
  // Splitting at circle/rectangle intersections also handles narrow containers.
  (double, double)? _menuArc(Offset center, double half, double gap) {
    final radius = widget.menuRadius;
    final inset = math.max(_menuInset(half * 2), gap);
    final left = half + inset;
    final right = _size!.width - half - inset;
    final top = half + gap;
    final bottom = _size!.height - half - gap;
    if (left > right || top > bottom) return null;
    final inward = center.dx < _size!.width / 2 ? 0.0 : math.pi;
    final start = inward - math.pi / 2;
    final end = inward + math.pi / 2;
    final cuts = <double>[start, end];
    void add(double angle) {
      for (final shift in [-2 * math.pi, 0.0, 2 * math.pi]) {
        final value = angle + shift;
        if (value > start && value < end) cuts.add(value);
      }
    }

    for (final x in [left, right]) {
      final ratio = (x - center.dx) / radius;
      if (ratio.abs() <= 1) {
        final angle = math.acos(ratio);
        add(angle);
        add(-angle);
      }
    }
    for (final y in [top, bottom]) {
      final ratio = (y - center.dy) / radius;
      if (ratio.abs() <= 1) {
        final angle = math.asin(ratio);
        add(angle);
        add(math.pi - angle);
      }
    }
    cuts.sort();
    (double, double)? best;
    double? runStart;
    for (var i = 0; i < cuts.length - 1; i++) {
      if (cuts[i + 1] - cuts[i] < 1e-10) continue;
      final middle = (cuts[i] + cuts[i + 1]) / 2;
      final point =
          center + Offset(math.cos(middle), math.sin(middle)) * radius;
      if (point.dx >= left &&
          point.dx <= right &&
          point.dy >= top &&
          point.dy <= bottom) {
        runStart ??= cuts[i];
        if (best == null || cuts[i + 1] - runStart > best.$2 - best.$1) {
          best = (runStart, cuts[i + 1]);
        }
      } else {
        runStart = null;
      }
    }
    return best;
  }

  List<Offset> _menuTargets(double itemDiameter) {
    final center = _position + Offset(widget.diameter / 2, widget.diameter / 2);
    final radius = widget.menuRadius;
    final half = itemDiameter / 2;
    final count = widget.menuItems.length;
    if (count == 0) return const [];
    // Maximize a shared clear gap: between circular item edges (chord distance)
    // and between the end items and the actual screen boundaries.
    var low = 0.0;
    var high = math.max(_size!.width, _size!.height);
    var arc = _menuArc(center, half, 0);
    for (var step = 0; step < 40; step++) {
      final gap = (low + high) / 2;
      final candidate = _menuArc(center, half, gap);
      final ratio = (itemDiameter + gap) / (2 * radius);
      final spacing = count == 1
          ? 0.0
          : ratio <= 1
          ? 2 * math.asin(ratio)
          : double.infinity;
      if (candidate != null &&
          candidate.$2 - candidate.$1 >= (count - 1) * spacing) {
        low = gap;
        arc = candidate;
      } else {
        high = gap;
      }
    }
    final start = arc?.$1 ?? 0.0;
    final end = arc?.$2 ?? start;
    return List.generate(count, (index) {
      final fraction = count == 1 ? 0.5 : index / (count - 1);
      final angle = start + (end - start) * fraction;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      // If the requested perimeter cannot fit, prioritize visibility.
      final inset = _menuInset(itemDiameter);
      return Offset(
        (point.dx - half).clamp(inset, _size!.width - itemDiameter - inset),
        (point.dy - half).clamp(0, _size!.height - itemDiameter),
      );
    });
  }

  @override
  void didUpdateWidget(covariant PuckOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_menuPhase == _MenuPhase.collapsing) {
      final identities = {
        for (var i = 0; i < widget.menuItems.length; i++)
          widget.menuItems[i].key ?? i,
      };
      _pendingCollapse.retainAll(identities);
      if (_pendingCollapse.isEmpty) _menuPhase = _MenuPhase.closed;
    }
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
        final itemDiameter = math.min(
          widget.menuItemDiameter,
          math.min(size.width, size.height),
        );
        final origin =
            _position +
            Offset(
              (widget.diameter - itemDiameter) / 2,
              (widget.diameter - itemDiameter) / 2,
            );
        final items = widget.menuItems;
        final generation = _menuGeneration;
        final targets = _expanded
            ? _menuTargets(itemDiameter)
            : const <Offset>[];
        return Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            widget.child,
            for (var i = 0; i < widget.menuItems.length; i++)
              if (_menuPhase != _MenuPhase.closed &&
                  (_expanded || _pendingCollapse.contains(items[i].key ?? i)))
                SpringPuck(
                  key: ValueKey(widget.menuItems[i].key ?? i),
                  origin: origin,
                  target: _expanded ? targets[i] : origin,
                  diameter: itemDiameter,
                  bounds: size,
                  horizontalInset: _menuInset(itemDiameter),
                  expanded: _expanded,
                  onCollapsed: () =>
                      _itemCollapsed(items[i].key ?? i, generation),
                  child: widget.menuItems[i],
                ),
            Positioned(
              left: _position.dx,
              top: _position.dy,
              width: widget.diameter,
              height: widget.diameter,
              child: ClipOval(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleMenu,
                  onLongPress: widget.onLongPress,
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
            if (widget.showDebugAnchors)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: PuckAnchorPainter([
                      (_ticker.isActive
                              ? Offset(
                                  _targetX,
                                  _vertical!.finalX.clamp(0, _bottom),
                                )
                              : _position) +
                          Offset(widget.diameter / 2, widget.diameter / 2),
                      for (var i = 0; i < items.length; i++)
                        if (_menuPhase != _MenuPhase.closed &&
                            (_expanded ||
                                _pendingCollapse.contains(items[i].key ?? i)))
                          (_expanded ? targets[i] : origin) +
                              Offset(itemDiameter / 2, itemDiameter / 2),
                    ]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
