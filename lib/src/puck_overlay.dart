import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'spring_puck.dart';
import 'puck_opening_trace.dart';
import 'puck_tier_curves.dart';
import 'puck_cables.dart';
import 'puck_rope_style.dart';
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
    this.showRopes = false,
    this.showTierCurves = false,
    this.ropeStyle = const PuckRopeStyle(),
    this.menuItems = const [],
    this.menuTiers = const [],
    this.menuRadius = 112,
    this.menuItemDiameter = 48,
    this.maintainMenuState = false,
    this.menuTierBuilder,
    this.menuExpanded,
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

  /// Paint menu tier perimeters, their shared end caps, and red destination dots. During dragging the
  /// main anchor follows the puck; during docking it shows its final position.
  /// Menu anchors appear only while their pucks are mounted.
  final bool showDebugAnchors;

  /// Connect menu items to their parent with animated ropes. Off by default.
  /// Disabled ropes are neither painted nor simulated.
  final bool showRopes;

  /// Draw thick curves through each tier's live item centers, clipped around
  /// all pucks. Curves follow the springs and fade near the root. Off by default.
  final bool showTierCurves;

  /// Stroke width and colors for ropes when [showRopes] is enabled.
  final PuckRopeStyle ropeStyle;

  /// Circular menu contents, painted below the main puck. Supply interactive
  /// widgets (for example, buttons) to handle individual item selections.
  /// Give items stable keys when inserting or reordering them.
  final List<Widget> menuItems;

  /// Menu tiers ordered from nearest to farthest. Empty tiers are ignored.
  /// Supply either this or [menuItems]. Items should have stable, unique keys.
  /// Tiers launch 50ms apart, outside-in on opening and inside-out on closing.
  final List<List<Widget>> menuTiers;

  /// Preferred distance from the main puck center to the expanded menu item centers.
  final double menuRadius;
  final double menuItemDiameter;

  /// Keep item subtrees mounted beneath the root when closed. Useful for
  /// expensive content such as glass renderers. Hidden items remain inert.
  /// Defaults to false, which disposes collapsed item subtrees.
  final bool maintainMenuState;

  /// Wrap a tier's positioned items (already in a Stack) in a rendering layer.
  /// The wrapper receives the same bounds as this overlay. It must preserve
  /// those coordinates. Tier indices run from nearest to farthest.
  final Widget Function(BuildContext context, int tier, Widget child)?
  menuTierBuilder;

  /// Optional externally controlled expanded state. Root taps update its value;
  /// programmatic changes do not invoke [onTap]. Owned by the caller.
  final ValueNotifier<bool>? menuExpanded;

  @override
  State<PuckOverlay> createState() => _PuckOverlayState();
}

class _PuckOverlayState extends State<PuckOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_tick);
  final _cables = PuckCables();
  final _curves = PuckTierCurves();
  Size? _size;
  bool _geometryChanged = false;
  double _globalTop = 0;
  double _keyboardHeight = 0;
  double? _keyboardOriginalY;
  bool _draggedWithKeyboard = false;
  SpringSimulation? _returnSpring;
  double? _returnTargetY;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _menuPhase = widget.menuExpanded?.value == true
        ? _MenuPhase.expanded
        : _MenuPhase.closed;
    widget.menuExpanded?.addListener(_syncExpanded);
  }

  @override
  void didChangeMetrics() {
    // Read the view directly on every metrics change: Scaffold may consume
    // MediaQuery.viewInsets when it resizes its body for the keyboard.
    setState(() {});
  }

  void _measureGlobalTop(Duration _) {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top != _globalTop) setState(() => _globalTop = top);
  }

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
  Stopwatch? _menuMotionClock;

  List<List<Widget>> get _tiers => widget.menuTiers.isEmpty
      ? [widget.menuItems]
      : widget.menuTiers.where((tier) => tier.isNotEmpty).toList();
  List<Widget> get _items => _tiers.expand((tier) => tier).toList();

  double get _left => -widget.diameter * widget.offscreenFraction;
  double get _right => math.max(_left, _size!.width - widget.diameter - _left);
  double get _bottom => math.max(0, _size!.height - widget.diameter);

  // Once released, lay out against the docking destination. The root spring
  // can bounce without feeding those transient positions back into the solver.
  Offset get _menuPosition => _tiers.length > 1 && _ticker.isActive
      ? Offset(
          _targetX,
          (_returnTargetY ?? _vertical!.finalX).clamp(0, _bottom),
        )
      : _position;

  Offset _bounded(Offset position) =>
      Offset(position.dx.clamp(_left, _right), position.dy.clamp(0, _bottom));

  void _tick(Duration elapsed) {
    final time = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final x = _horizontal!;
    final y = _returnSpring ?? _vertical!;
    setState(() {
      _position = _bounded(Offset(x.x(time), y.x(time)));
      // Contact with a vertical boundary absorbs vertical momentum.
      final hitBoundary = y.x(time) <= 0 || y.x(time) >= _bottom;
      if (x.isDone(time) &&
          (y.isDone(time) || (_returnSpring == null && hitBoundary))) {
        _position = _bounded(
          Offset(_targetX, _returnTargetY ?? _vertical!.finalX),
        );
        if (_returnSpring != null) _keyboardOriginalY = null;
        _returnSpring = null;
        _returnTargetY = null;
        _ticker.stop();
      }
    });
  }

  void _dock(Offset velocity) {
    _grabOffset = null;
    _ticker.stop();
    _returnSpring = null;
    _returnTargetY = null;
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
    if (_keyboardHeight == 0 && _keyboardOriginalY != null) {
      _returnTargetY = _keyboardOriginalY!.clamp(0.0, _bottom);
      _returnSpring = SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 220, damping: 26),
        _position.dy,
        _returnTargetY!,
        velocity.dy,
      );
    }
    _ticker.start();
  }

  void _syncExpanded() => _setExpanded(widget.menuExpanded!.value);

  void _toggleMenu() {
    PuckOpeningTrace.measure('tap.callback', () {
      _setExpanded(!_expanded);
      widget.onTap?.call();
    });
  }

  void _setExpanded(bool expanded) {
    if (expanded == _expanded) return;
    setState(() {
      _menuGeneration++;
      _menuMotionClock = WidgetsBinding.instance.samplingClock.stopwatch()
        ..start();
      _pendingCollapse.clear();
      if (!expanded) {
        _pendingCollapse.addAll([
          for (var i = 0; i < _items.length; i++) _items[i].key ?? i,
        ]);
        _menuPhase = _pendingCollapse.isEmpty
            ? _MenuPhase.closed
            : _MenuPhase.collapsing;
      } else {
        _menuPhase = _MenuPhase.expanded;
      }
    });
    widget.menuExpanded?.value = expanded;
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

  // Multi-tier end caps can approach the wall without a large inward wedge.
  double _menuInset(double itemDiameter) => math.min(
    _tiers.length > 1 ? 4 : 24,
    math.max(0, (_size!.width - itemDiameter) / 2),
  );

  // Exact visible arc on the inward semicircle for a given clear edge gap.
  // Splitting at circle/rectangle intersections also handles narrow containers.
  (double, double)? _menuArc(
    Offset center,
    double half,
    double gap,
    double radius,
  ) {
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

  List<Offset> _tierTargets(
    double itemDiameter,
    int count,
    double radius, {
    (double, double)? sharedArc,
  }) {
    final center =
        _menuPosition + Offset(widget.diameter / 2, widget.diameter / 2);
    final half = itemDiameter / 2;
    if (count == 0) return const [];
    // Maximize a shared clear gap: between circular item edges (chord distance)
    // and between the end items and the actual screen boundaries.
    var low = 0.0;
    var high = math.max(_size!.width, _size!.height);
    var arc = sharedArc ?? _menuArc(center, half, 0, radius);
    for (var step = 0; sharedArc == null && step < 40; step++) {
      final gap = (low + high) / 2;
      final candidate = _menuArc(center, half, gap, radius);
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

  List<double> _menuRadii(double diameter) {
    final tiers = _tiers;
    if (tiers.length <= 1) {
      return [widget.menuRadius];
    }
    final center =
        _menuPosition + Offset(widget.diameter / 2, widget.diameter / 2);
    // Find the largest usable outer radius, including narrow and corner layouts.
    var outer = widget.menuRadius;
    final limit = _size!.longestSide * 1.4143;
    for (var radius = diameter; radius <= limit; radius += 2) {
      final arc = _menuArc(center, diameter / 2, 0, radius);
      if (arc == null) continue;
      final spacing = 2 * math.asin(math.min(1, diameter / (2 * radius)));
      if (arc.$2 - arc.$1 >= (tiers.last.length - 1) * spacing) {
        outer = radius;
      }
    }
    final near = math.min(widget.menuRadius, outer / tiers.length);
    // Increase each outward step beyond the preferred inner radius. Scale
    // all gaps together when the viewport requires compression.
    final gaps = [
      for (var tier = 1; tier < tiers.length; tier++)
        math.max(widget.menuRadius, diameter) + 8 * tier,
    ];
    final span = gaps.fold(0.0, (sum, gap) => sum + gap);
    final scale = math.min(1.0, (outer - near) / span);
    var radius = near;
    return [near, for (final gap in gaps) radius += gap * scale];
  }

  // All rings use the intersection of their visible angular intervals.
  // Keep a small fixed boundary clearance; maximize spacing between items
  // without turning that extra space into padding against the docking wall.
  (double, double)? _sharedMenuArc(double diameter, List<double> radii) {
    final center =
        _menuPosition + Offset(widget.diameter / 2, widget.diameter / 2);
    final tiers = _tiers;
    (double, double)? available() {
      var start = double.negativeInfinity;
      var end = double.infinity;
      for (final radius in radii) {
        final arc = _menuArc(center, diameter / 2, 4, radius);
        if (arc == null) return null;
        start = math.max(start, arc.$1);
        end = math.min(end, arc.$2);
      }
      return start <= end ? (start, end) : null;
    }

    var best = available();
    var low = 0.0;
    var high = _size!.longestSide;
    for (var step = 0; step < 40; step++) {
      final gap = (low + high) / 2;
      final arc = best;
      var fits = arc != null;
      for (var tier = 0; fits && tier < tiers.length; tier++) {
        final count = tiers[tier].length;
        if (count <= 1) continue;
        final ratio = (diameter + gap) / (2 * radii[tier]);
        fits =
            ratio <= 1 &&
            (count - 1) * 2 * math.asin(ratio) <= arc!.$2 - arc.$1;
      }
      if (fits) {
        low = gap;
        best = arc;
      } else {
        high = gap;
      }
    }
    return best;
  }

  Object? _menuLayoutKey;
  List<double>? _restingRadii;
  (double, double)? _retainedArc;

  (List<double>, (double, double)?) _menuLayout(double diameter) {
    if (!_expanded) {
      _menuLayoutKey = null;
      return (const [], null);
    }
    if (_tiers.length <= 1) {
      _menuLayoutKey = null;
      return (_menuRadii(diameter), null);
    }
    final key = (
      _size,
      diameter,
      widget.diameter,
      widget.menuRadius,
      _tiers.map((tier) => tier.length).join(','),
    );
    if (_menuLayoutKey != key) {
      _menuLayoutKey = key;
      _restingRadii = _menuRadii(diameter);
      _retainedArc = _sharedMenuArc(diameter, _restingRadii!);
      return (_restingRadii!, _retainedArc);
    }
    final resting = _restingRadii!;
    // Compression belongs to dragging. Restore the resting ring distances on
    // release and choose end caps for the final dock, rather than repeatedly
    // alternating between radial expansion and angular expansion.
    if (_grabOffset == null) {
      final arc = _sharedMenuArc(diameter, resting);
      if (arc != null) {
        _retainedArc = arc;
        return (resting, arc);
      }
      final radii = _menuRadii(diameter);
      _retainedArc = _sharedMenuArc(diameter, radii);
      return (radii, _retainedArc);
    }
    List<double> compressed(double scale) => [
      for (final radius in resting)
        resting.first + (radius - resting.first) * scale,
    ];
    final center =
        _menuPosition + Offset(widget.diameter / 2, widget.diameter / 2);
    final half = diameter / 2;
    final inset = _menuInset(diameter);
    bool fits(double scale) {
      final arc = _retainedArc;
      if (arc == null) return false;
      final radii = compressed(scale);
      final tiers = _tiers;
      for (var tier = 0; tier < tiers.length; tier++) {
        final count = tiers[tier].length;
        for (var item = 0; item < count; item++) {
          final fraction = count == 1 ? 0.5 : item / (count - 1);
          final angle = arc.$1 + (arc.$2 - arc.$1) * fraction;
          final point =
              center + Offset(math.cos(angle), math.sin(angle)) * radii[tier];
          if (point.dx < half + inset - 1e-6 ||
              point.dx > _size!.width - half - inset + 1e-6 ||
              point.dy < half - 1e-6 ||
              point.dy > _size!.height - half + 1e-6) {
            return false;
          }
        }
      }
      return true;
    }

    (List<double>, (double, double)?) fanOut(List<double> radii) {
      final available = _sharedMenuArc(diameter, radii);
      final retained = _retainedArc;
      if (available != null &&
          (retained == null ||
              (available.$1 <= retained.$1 + 1e-8 &&
                  available.$2 >= retained.$2 - 1e-8 &&
                  available.$2 - available.$1 >
                      retained.$2 - retained.$1 + 1e-8))) {
        _retainedArc = available;
      }
      return (radii, _retainedArc);
    }

    // Give recovered space to the angular fan before restoring radial gaps.
    // Otherwise expanding the radii consumes that space and pins the arc to
    // the same narrow endpoints all the way back to the wall.
    fanOut(compressed(0.5));

    // Preserve both end caps while squeezing the radial gaps. Always measure
    // against resting distances, so repeated frames cannot compound compression.
    if (fits(1)) return fanOut(resting);
    if (fits(0.5)) {
      var low = 0.5;
      var high = 1.0;
      for (var step = 0; step < 30; step++) {
        final scale = (low + high) / 2;
        if (fits(scale)) {
          low = scale;
        } else {
          high = scale;
        }
      }
      return fanOut(compressed(low));
    }
    // Rearrange only after the allowed compression is exhausted.
    var radii = compressed(0.5);
    var arc = _sharedMenuArc(diameter, radii);
    if (arc == null) {
      // Very small viewports can require the existing visibility fallback.
      radii = _menuRadii(diameter);
      arc = _sharedMenuArc(diameter, radii);
    }
    _retainedArc = arc;
    return (radii, arc);
  }

  List<Offset> _menuTargets(
    double diameter,
    List<double> radii,
    (double, double)? arc,
  ) {
    final tiers = _tiers;
    return [
      for (var tier = 0; tier < tiers.length; tier++)
        ..._tierTargets(
          diameter,
          tiers[tier].length,
          radii[tier],
          sharedArc: arc,
        ),
    ];
  }

  Duration _tierDelay(int index) {
    final tiers = _tiers;
    var tier = 0;
    while (tier < tiers.length - 1 && index >= tiers[tier].length) {
      index -= tiers[tier++].length;
    }
    return Duration(
      milliseconds: 50 * (_expanded ? tiers.length - 1 - tier : tier),
    );
  }

  @override
  void didUpdateWidget(covariant PuckOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuExpanded != widget.menuExpanded) {
      oldWidget.menuExpanded?.removeListener(_syncExpanded);
      widget.menuExpanded?.addListener(_syncExpanded);
      if (widget.menuExpanded != null) _syncExpanded();
    }
    if (_menuPhase == _MenuPhase.collapsing) {
      final identities = {
        for (var i = 0; i < _items.length; i++) _items[i].key ?? i,
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
    widget.menuExpanded?.removeListener(_syncExpanded);
    WidgetsBinding.instance.removeObserver(this);
    _curves.dispose();
    _cables.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.menuItems.isEmpty || widget.menuTiers.isEmpty,
      'Supply either menuItems or menuTiers.',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth && constraints.hasBoundedHeight,
          'PuckOverlay requires bounded width and height.',
        );
        WidgetsBinding.instance.addPostFrameCallback(_measureGlobalTop);
        final view = View.of(context);
        final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
        final keyboardTop =
            (view.physicalSize.height / view.devicePixelRatio) - keyboard;
        // Intersect the keyboard-free viewport with this overlay's area. This
        // also avoids subtracting the inset twice in an already resized body.
        final size = Size(
          constraints.maxWidth,
          keyboard > 0
              ? (keyboardTop - _globalTop).clamp(0, constraints.maxHeight)
              : constraints.maxHeight,
        );
        if (_keyboardHeight == 0 && keyboard > 0) {
          _draggedWithKeyboard = false;
        }
        final newBottom = math.max(0.0, size.height - widget.diameter);
        if (keyboard > 0 &&
            !_draggedWithKeyboard &&
            _keyboardOriginalY == null &&
            _size != null &&
            _position.dy > newBottom) {
          _keyboardOriginalY = _position.dy;
        }
        final restore =
            keyboard == 0 &&
            _keyboardOriginalY != null &&
            (_keyboardHeight > 0 || _size != size || _geometryChanged);
        _keyboardHeight = keyboard;
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
        if (restore) _dock(Offset.zero);
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
        final items = _items;
        final generation = _menuGeneration;
        final tiers = _tiers;
        final itemTiers = [
          for (var tier = 0; tier < tiers.length; tier++)
            for (var item = 0; item < tiers[tier].length; item++) tier,
        ];
        PuckOpeningTrace.instant('overlay.layout.begin');
        final (radii, arc) = PuckOpeningTrace.measure(
          'menu.layout.solve',
          () => _menuLayout(itemDiameter),
        );
        final targets = _expanded
            ? PuckOpeningTrace.measure(
                'menu.targets',
                () => _menuTargets(itemDiameter, radii, arc),
              )
            : const <Offset>[];
        PuckOpeningTrace.instant('overlay.targets.ready');
        final menuPucks = <int, Widget>{
          for (var i = 0; i < items.length; i++)
            if (widget.maintainMenuState ||
                (_menuPhase != _MenuPhase.closed &&
                    (_expanded ||
                        _pendingCollapse.contains(items[i].key ?? i))))
              i: SpringPuck(
                key: ValueKey(items[i].key ?? i),
                origin: origin,
                delay: _tierDelay(i),
                motionClock: _menuMotionClock,
                cables: _cables,
                showRopes: widget.showRopes,
                curves: widget.showTierCurves ? _curves : null,
                tier: itemTiers[i],
                order: i,
                dormant: _menuPhase == _MenuPhase.closed,
                target: _expanded ? targets[i] : origin,
                diameter: itemDiameter,
                parentDiameter: widget.diameter,
                bounds: size,
                horizontalInset: _menuInset(itemDiameter),
                expanded: _expanded,
                onCollapsed: () =>
                    _itemCollapsed(items[i].key ?? i, generation),
                child: items[i],
              ),
        };
        final menuLayers = widget.menuTierBuilder == null
            ? menuPucks.values.toList()
            : <Widget>[
                for (var tier = 0; tier < tiers.length; tier++)
                  Positioned.fill(
                    key: ValueKey(('menu-tier', tier)),
                    child: widget.menuTierBuilder!(
                      context,
                      tier,
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final entry in menuPucks.entries)
                            if (itemTiers[entry.key] == tier) entry.value,
                        ],
                      ),
                    ),
                  ),
              ];
        return Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            widget.child,
            if (widget.showTierCurves)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: PuckTierCurvePainter(
                        _curves,
                        parentBounds: _position & Size.square(widget.diameter),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.showRopes)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: PuckCablePainter(
                      _cables,
                      style: widget.ropeStyle,
                      parentBounds: _position & Size.square(widget.diameter),
                    ),
                  ),
                ),
              ),
            ...menuLayers,
            // Paint the parent after every menu item, including while their
            // springs overlap it during expansion and collapse.
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
                    // A deliberate drag supersedes the pre-keyboard location.
                    _keyboardOriginalY = null;
                    if (_keyboardHeight > 0) {
                      _draggedWithKeyboard = true;
                    }
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
                  onTapUp: (_) => PuckOpeningTrace.measure(
                    'tap.up.dock',
                    () => _dock(Offset.zero),
                  ),
                  child: widget.puck,
                ),
              ),
            ),
            if (widget.showDebugAnchors)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: PuckAnchorPainter(
                      [
                        (_ticker.isActive
                                ? Offset(
                                    _targetX,
                                    (_returnTargetY ?? _vertical!.finalX).clamp(
                                      0,
                                      _bottom,
                                    ),
                                  )
                                : _position) +
                            Offset(widget.diameter / 2, widget.diameter / 2),
                        for (var i = 0; i < items.length; i++)
                          if (_menuPhase != _MenuPhase.closed &&
                              (_expanded ||
                                  _pendingCollapse.contains(items[i].key ?? i)))
                            (_expanded ? targets[i] : origin) +
                                Offset(itemDiameter / 2, itemDiameter / 2),
                      ],
                      center:
                          _menuPosition +
                          Offset(widget.diameter / 2, widget.diameter / 2),
                      radii: items.isEmpty ? const [] : radii,
                      arc: arc,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
