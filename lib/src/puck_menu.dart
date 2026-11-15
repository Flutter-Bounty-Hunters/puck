import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme;

import 'spring_puck.dart';
import 'puck_opening_trace.dart';
import 'puck_level_curves.dart';
import 'puck_cables.dart';
import 'puck_anchor_painter.dart';
import 'puck_layout_preview_painter.dart';
import 'puck_anchor_storage.dart';

part 'puck_menu_controller.dart';

enum _MenuPhase { closed, expanded, collapsing }

/// A self-contained layer displaying a draggable [rootPuck] and its menu items.
///
/// Place above page content in a Stack, typically using Positioned.fill.
/// Requires bounded constraints. Wrap this widget in [SafeArea] to make safe
/// area insets collision boundaries. Only the root and menu items intercept
/// pointer events; the rest of the layer lets touches reach content underneath.
/// Ten percent of its diameter extends beyond the horizontal edge when docked.
class PuckMenu extends StatefulWidget {
  /// Creates a menu with one level of items.
  const PuckMenu.singleLevel({
    super.key,
    this.controller,
    this.id,
    required this.rootPuck,
    required List<Widget> puckItems,
    this.layout = const PuckMenuLayout(),
    this.arcStyle = const ArcStyle(),
    this.showRopes = false,
    this.ropeStyle = const PuckRopeStyle(),
    this.debug = const PuckMenuDebug(),
  }) : _singleLevelItems = puckItems,
       _multiLevelItems = null;

  /// Creates a menu with lists ordered from the nearest to farthest level.
  const PuckMenu.multiLevel({
    super.key,
    this.controller,
    this.id,
    required this.rootPuck,
    required List<List<Widget>> puckItems,
    this.layout = const PuckMenuLayout(),
    this.arcStyle = const ArcStyle(),
    this.showRopes = false,
    this.ropeStyle = const PuckRopeStyle(),
    this.debug = const PuckMenuDebug(),
  }) : _singleLevelItems = null,
       _multiLevelItems = puckItems;

  /// External commands and lifecycle notifications for this menu.
  /// The caller owns and disposes the controller.
  final PuckMenuController? controller;

  /// Optional persistent identity for this menu. A stable ID automatically
  /// saves and restores its docking edge and proportional vertical position,
  /// including across navigation and app restarts. Menus without an ID do not
  /// access storage. Missing/invalid saved data uses [layout]'s initial position.
  /// Use distinct IDs for menus that should remember independent positions.
  final String? id;

  /// Developer-provided content, clipped to [PuckMenuLayout.diameter].
  final Widget rootPuck;

  /// Menu contents grouped into levels ordered nearest to farthest.
  ///
  /// [PuckMenu.singleLevel] accepts a flat list and exposes it here as one level;
  /// [PuckMenu.multiLevel] accepts the grouped lists directly. Give items stable,
  /// unique keys. Empty levels are ignored during layout. Levels launch 50ms
  /// apart, outside-in on opening and inside-out on closing.
  List<List<Widget>> get puckItems => _multiLevelItems ?? [_singleLevelItems!];

  /// Menu sizing, level geometry, docking, and initial root placement.
  final PuckMenuLayout layout;

  /// Appearance of level curves when [PuckMenuDebug.showLevelCurves] is enabled.
  final ArcStyle arcStyle;

  /// Connect menu items to their parent with animated ropes. Off by default.
  /// Disabled ropes are neither painted nor simulated.
  final bool showRopes;

  /// Stroke width and colors for ropes when [showRopes] is enabled.
  final PuckRopeStyle ropeStyle;

  /// Visual diagnostics for anchors, level curves, and layout exploration.
  final PuckMenuDebug debug;

  final List<Widget>? _singleLevelItems;
  final List<List<Widget>>? _multiLevelItems;

  @override
  State<PuckMenu> createState() => _PuckMenuState();
}

/// The horizontal edge to which a puck docks.
enum PuckEdge { left, right }

/// Menu sizing, level geometry, docking, and initial root placement.
@immutable
class PuckMenuLayout {
  const PuckMenuLayout({
    this.diameter = 64,
    this.offscreenFraction = 0.1,
    this.initialEdge = PuckEdge.right,
    this.initialVerticalAlignment = 0.5,
    this.levelRadius = 112,
    this.puckDiameter = 48,
  }) : assert(diameter > 0 && diameter < double.infinity),
       assert(offscreenFraction >= 0 && offscreenFraction <= 0.5),
       assert(initialVerticalAlignment >= 0 && initialVerticalAlignment <= 1),
       assert(levelRadius > 0 && levelRadius < double.infinity),
       assert(puckDiameter > 0 && puckDiameter < double.infinity);

  /// Root-puck diameter in logical pixels. Must be positive and finite.
  final double diameter;

  /// Fraction of the root diameter hidden beyond its docking edge, from 0 to 0.5.
  final double offscreenFraction;

  /// Docking edge used when the menu is first mounted.
  final PuckEdge initialEdge;

  /// Initial vertical placement: 0 is the top, 1 the bottom, and 0.5 the middle.
  final double initialVerticalAlignment;

  /// Preferred distance from the root center to items in the first level.
  final double levelRadius;

  /// Diameter of each menu item. The root uses [diameter] instead.
  final double puckDiameter;
}

/// Appearance of the circular curves connecting menu items on each level.
@immutable
class ArcStyle {
  const ArcStyle({this.color, this.thickness = 4})
    : assert(thickness > 0 && thickness < double.infinity);

  /// Stroke color. Defaults to light gray in light mode and dark gray in dark
  /// mode when null.
  final Color? color;

  /// Stroke width in logical pixels.
  final double thickness;
}

/// The two-tone stroke used to paint menu ropes.
@immutable
class PuckRopeStyle {
  const PuckRopeStyle({
    this.thickness = 3,
    this.brightColor = const Color(0xFF89939E),
    this.darkColor = const Color(0x66000000),
  }) : assert(thickness > 0 && thickness < double.infinity);

  /// Total stroke width in logical pixels.
  final double thickness;

  /// Color of the inner highlight, painted at half [thickness].
  final Color brightColor;

  /// Color of the full-width outer stroke.
  final Color darkColor;
}

/// Optional visual diagnostics for a puck menu. Disabled by default.
@immutable
class PuckMenuDebug {
  const PuckMenuDebug({
    this.showAnchors = false,
    this.showLevelCurves = false,
    this.layoutPreview = false,
  });

  /// Draw level perimeters, shared end caps, and red spring-destination dots.
  /// During dragging the root marker follows the puck; during docking it
  /// marks the landing position. Item dots exist only while items are mounted.
  final bool showAnchors;

  /// Connect each level's moving items with a circular curve, clipped around
  /// the pucks. Curves follow the springs and fade near the root.
  final bool showLevelCurves;

  /// Replace items and their springs with radius guides, item-width bands,
  /// and filled sectors for the solved arc, using the normal layout rules.
  final bool layoutPreview;
}

class _PuckMenuState extends State<PuckMenu>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_tick);
  final _cables = PuckCables();
  final _curves = PuckLevelCurves();
  Size? _size;
  bool _geometryChanged = false;
  double _globalTop = 0;
  double _keyboardHeight = 0;
  double? _keyboardOriginalY;
  bool _draggedWithKeyboard = false;
  SpringSimulation? _returnSpring;
  double? _returnTargetY;
  int _anchorRequest = 0;
  SavedPuckAnchor? _pendingRestoredAnchor;
  bool _resetAnchor = false;
  String? _saveAnchorOnSettle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAnchor();
    _attachController();
    if (widget.controller != null) {
      _applyControllerRequestAfterBuild();
    }
  }

  void _loadAnchor({bool reset = false}) {
    final request = ++_anchorRequest;
    final id = widget.id;
    _pendingRestoredAnchor = id == null ? null : PuckAnchorStorage.cached(id);
    if (reset) {
      _resetAnchor = true;
      _saveAnchorOnSettle = null;
      _keyboardOriginalY = null;
    }
    if (id == null || _pendingRestoredAnchor != null) return;
    unawaited(
      PuckAnchorStorage.read(id).then((anchor) {
        if (!mounted ||
            request != _anchorRequest ||
            widget.id != id ||
            anchor == null) {
          return;
        }
        setState(() => _pendingRestoredAnchor = anchor);
      }),
    );
  }

  void _saveAnchor(double y) {
    final id = widget.id;
    if (id == null || _size == null || _bottom <= 0) return;
    PuckAnchorStorage.save(id, (
      edge: _edge,
      verticalAlignment: (y / _bottom).clamp(0.0, 1.0),
    ));
  }

  void _attachController() {
    final controller = widget.controller;
    if (controller == null) return;
    controller._attach(this, _setExpanded);
    controller._status = _expanded
        ? (_opening ? PuckMenuStatus.expanding : PuckMenuStatus.expanded)
        : (_menuPhase == _MenuPhase.collapsing
              ? PuckMenuStatus.collapsing
              : PuckMenuStatus.collapsed);
    controller._isDragging = _dragging;
    controller._isSettled = !_awaitingSettle;
  }

  void _applyControllerRequestAfterBuild() {
    final controller = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          identical(widget.controller, controller) &&
          controller != null &&
          !controller._disposed) {
        _setExpanded(controller._requestedExpanded);
      }
    });
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
  late PuckEdge _edge = widget.layout.initialEdge;
  double _targetX = 0;
  _MenuPhase _menuPhase = _MenuPhase.closed;
  bool get _expanded => _menuPhase == _MenuPhase.expanded;
  final Set<Object> _pendingCollapse = {};
  final Set<Object> _pendingExpansion = {};
  bool _opening = false;
  bool _dragging = false;
  bool _awaitingSettle = false;
  int _menuGeneration = 0;
  int _completedGeneration = 0;
  Stopwatch? _menuMotionClock;

  List<List<Widget>> get _levels => widget._multiLevelItems == null
      ? widget.puckItems
      : widget.puckItems.where((level) => level.isNotEmpty).toList();
  List<Widget> get _items => _levels.expand((level) => level).toList();

  double get _left => -widget.layout.diameter * widget.layout.offscreenFraction;
  double get _right =>
      math.max(_left, _size!.width - widget.layout.diameter - _left);
  double get _bottom => math.max(0, _size!.height - widget.layout.diameter);

  // Item targets use the stable docking destination. The layout preview shows
  // geometry at the moving root, including throughout its return spring.
  Offset get _menuPosition => !widget.debug.layoutPreview && _ticker.isActive
      ? Offset(
          _targetX,
          (_returnTargetY ?? _vertical!.finalX).clamp(0, _bottom),
        )
      : _position;

  // Side edges are docking destinations, not drag limits. Preserve horizontal
  // motion beyond them, including the spring's return from an offscreen release.
  Offset _constrainVertical(Offset position) =>
      Offset(position.dx, position.dy.clamp(0, _bottom));

  void _tick(Duration elapsed) {
    final time = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final x = _horizontal!;
    final y = _returnSpring ?? _vertical!;
    var settled = false;
    setState(() {
      _position = _constrainVertical(Offset(x.x(time), y.x(time)));
      // Contact with a vertical boundary absorbs vertical momentum.
      final hitBoundary = y.x(time) <= 0 || y.x(time) >= _bottom;
      if (x.isDone(time) &&
          (y.isDone(time) || (_returnSpring == null && hitBoundary))) {
        _position = _constrainVertical(
          Offset(_targetX, _returnTargetY ?? _vertical!.finalX),
        );
        if (_returnSpring != null) _keyboardOriginalY = null;
        _returnSpring = null;
        _returnTargetY = null;
        _ticker.stop();
        settled = _awaitingSettle;
        _awaitingSettle = false;
      }
    });
    if (settled) {
      if (_saveAnchorOnSettle != null && _saveAnchorOnSettle == widget.id) {
        _saveAnchor(_position.dy);
      }
      _saveAnchorOnSettle = null;
      widget.controller?._settled();
    }
  }

  void _dock(Offset velocity) {
    final released = _dragging;
    _dragging = false;
    _grabOffset = null;
    _ticker.stop();
    _returnSpring = null;
    _returnTargetY = null;
    // Momentum carries the puck vertically, while the nearest horizontal edge
    // attracts it. Horizontal release velocity feeds directly into the spring.
    _edge = (_position.dx + widget.layout.diameter / 2 < _size!.width / 2)
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
    _awaitingSettle =
        _awaitingSettle ||
        (_position.dx - _targetX).abs() > 0.01 ||
        velocity.distance > 0.01 ||
        _returnSpring != null;
    if (_awaitingSettle) widget.controller?._isSettled = false;
    _ticker.start();
    if (released) {
      _saveAnchorOnSettle = widget.id;
      _saveAnchor(_vertical!.finalX.clamp(0.0, _bottom));
      widget.controller?._dragReleased();
    }
  }

  void _toggleMenu() {
    PuckOpeningTrace.measure('tap.callback', () {
      _setExpanded(!_expanded);
    });
  }

  void _setExpanded(bool expanded) {
    if (expanded == _expanded) return;
    setState(() {
      _menuGeneration++;
      _menuMotionClock = WidgetsBinding.instance.samplingClock.stopwatch()
        ..start();
      _pendingCollapse.clear();
      _pendingExpansion.clear();
      _opening = expanded;
      if (!expanded) {
        if (!widget.debug.layoutPreview) {
          _pendingCollapse.addAll([
            for (var i = 0; i < _items.length; i++) _items[i].key ?? i,
          ]);
        }
        _menuPhase = _pendingCollapse.isEmpty
            ? _MenuPhase.closed
            : _MenuPhase.collapsing;
      } else {
        _menuPhase = _MenuPhase.expanded;
        if (!widget.debug.layoutPreview) {
          _pendingExpansion.addAll([
            for (var i = 0; i < _items.length; i++) _items[i].key ?? i,
          ]);
        }
      }
    });
    final generation = _menuGeneration;
    if (expanded) {
      widget.controller?._expanding();
    } else {
      widget.controller?._collapsing();
    }
    _finishMenuTransition(generation);
  }

  void _finishMenuTransition(int generation) {
    if (!mounted ||
        generation != _menuGeneration ||
        generation == _completedGeneration) {
      return;
    }
    if (_expanded && _opening && _pendingExpansion.isEmpty) {
      _opening = false;
      _completedGeneration = generation;
      widget.controller?._expanded();
    } else if (_menuPhase == _MenuPhase.closed) {
      _completedGeneration = generation;
      widget.controller?._collapsed();
    }
  }

  void _itemExpanded(Object identity, int generation) {
    if (!_expanded || !_opening || generation != _menuGeneration) return;
    _pendingExpansion.remove(identity);
    _finishMenuTransition(generation);
  }

  void _itemCollapsed(Object identity, int generation) {
    if (_menuPhase != _MenuPhase.collapsing || generation != _menuGeneration) {
      return;
    }
    setState(() {
      _pendingCollapse.remove(identity);
      if (_pendingCollapse.isEmpty) _menuPhase = _MenuPhase.closed;
    });
    _finishMenuTransition(generation);
  }

  // End caps can approach the wall without a large inward wedge.
  double _menuInset(double itemDiameter) =>
      math.min(4, math.max(0, (_size!.width - itemDiameter) / 2));

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

  List<Offset> _levelTargets(
    double itemDiameter,
    int count,
    double radius, {
    (double, double)? sharedArc,
    int level = 0,
  }) {
    final center =
        _menuPosition +
        Offset(widget.layout.diameter / 2, widget.layout.diameter / 2);
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
    var first = count == 1 ? (start + end) / 2 : start;
    var spacing = count == 1 ? 0.0 : (end - start) / (count - 1);
    final ringSpacing = 2 * math.pi / count;
    if (count > 1 && spacing >= ringSpacing - 1e-8) {
      // Close the ring without duplicating its endpoints. Equivalent cyclic
      // phases let items keep their positions as the arc crosses its seam.
      spacing = ringSpacing;
      final lastFirst = math.max(start, end - (count - 1) * spacing);
      final previous = _levelPhases[level] ?? (start + lastFirst) / 2;
      final shift =
          ((previous - (start + lastFirst) / 2) / spacing).round() * spacing;
      first = previous.clamp(start + shift, lastFirst + shift);
    } else if (count == 1 && end - start >= 2 * math.pi - 1e-8) {
      first = _levelPhases[level] ?? first;
    }
    _levelPhases[level] = first;
    final points = List.generate(count, (index) {
      final angle = first + spacing * index;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      // If the requested perimeter cannot fit, prioritize visibility.
      final inset = _menuInset(itemDiameter);
      return Offset(
        (point.dx - half).clamp(inset, _size!.width - itemDiameter - inset),
        (point.dy - half).clamp(0, _size!.height - itemDiameter),
      );
    });
    // Mirror the complete sequence when the fan changes sides. Individual
    // items keep their neighbors along the arc; never sort by screen Y.
    // A full ring has no facing side, so retain its direction across the seam.
    final fullRing = end - start >= 2 * math.pi - 1e-8;
    final reversed = fullRing
        ? (_levelReversed[level] ?? widget.layout.initialEdge == PuckEdge.right)
        : math.cos((start + end) / 2) < 0;
    _levelReversed[level] = reversed;
    return reversed ? points.reversed.toList() : points;
  }

  List<double> _menuRadii(double diameter) {
    final levels = _levels;
    if (levels.length <= 1) {
      return [widget.layout.levelRadius];
    }
    final center =
        _menuPosition +
        Offset(widget.layout.diameter / 2, widget.layout.diameter / 2);
    // Find the largest usable outer radius, including narrow and corner layouts.
    var outer = widget.layout.levelRadius;
    final limit = _size!.longestSide * 1.4143;
    for (var radius = diameter; radius <= limit; radius += 2) {
      final arc = _menuArc(center, diameter / 2, 0, radius);
      if (arc == null) continue;
      final spacing = 2 * math.asin(math.min(1, diameter / (2 * radius)));
      if (arc.$2 - arc.$1 >= (levels.last.length - 1) * spacing) {
        outer = radius;
      }
    }
    final near = math.min(widget.layout.levelRadius, outer / levels.length);
    // Increase each outward step beyond the preferred inner radius. Scale
    // all gaps together when the viewport requires compression.
    final gaps = [
      for (var level = 1; level < levels.length; level++)
        math.max(widget.layout.levelRadius, diameter) + 8 * level,
    ];
    final span = gaps.fold(0.0, (sum, gap) => sum + gap);
    final scale = math.min(1.0, (outer - near) / span);
    var radius = near;
    return [near, for (final gap in gaps) radius += gap * scale];
  }

  // Find the widest shared arc anywhere around the root, up to maxSpan.
  // For a rectangular viewport, checking the inner and outer rings also covers
  // every intermediate ring: their points lie between those two endpoints.
  (double, double)? _sharedMenuArc(
    double diameter,
    List<double> radii, {
    bool balance = true,
    double maxSpan = math.pi,
    double? fixedMiddle,
  }) {
    if (radii.isEmpty) return null;
    final center =
        _menuPosition +
        Offset(widget.layout.diameter / 2, widget.layout.diameter / 2);
    final half = diameter / 2;
    final inset = math.max(_menuInset(diameter), 4.0);
    final left = half + inset;
    final right = _size!.width - half - inset;
    final top = half + 4;
    final bottom = _size!.height - half - 4;
    if (left > right || top > bottom) return null;
    const turn = 2 * math.pi;
    final rings = [radii.first, if (radii.last != radii.first) radii.last];
    if (fixedMiddle != null) {
      // A centered comparison needs only four wall limits, not angular runs.
      // Release a wall's limit over a small clearance band after tangency;
      // joining two visible runs must not suddenly change a candidate's score.
      var reach = math.min(maxSpan, turn) / 2;
      final transition = math.max(4.0, diameter / 4);
      for (final wall in [
        (center.dx - left, math.pi),
        (right - center.dx, 0.0),
        (center.dy - top, -math.pi / 2),
        (bottom - center.dy, math.pi / 2),
      ]) {
        final separation = math
            .atan2(
              math.sin(wall.$2 - fixedMiddle),
              math.cos(wall.$2 - fixedMiddle),
            )
            .abs();
        for (final radius in rings) {
          double limit;
          if (wall.$1 <= radius) {
            limit = separation - math.acos((wall.$1 / radius).clamp(-1.0, 1.0));
          } else {
            final t = ((wall.$1 - radius) / transition).clamp(0.0, 1.0);
            limit = separation + (math.pi - separation) * t * t * (3 - 2 * t);
          }
          reach = math.min(reach, limit);
        }
      }
      return reach <= 1e-10 ? null : (fixedMiddle - reach, fixedMiddle + reach);
    }
    final cuts = <double>[0, turn];
    void add(double angle) {
      final a = angle % turn;
      if (a > 1e-10 && a < turn - 1e-10) cuts.add(a);
    }

    for (final radius in rings) {
      for (final x in [left, right]) {
        final ratio = (x - center.dx) / radius;
        if (ratio.abs() <= 1) {
          final a = math.acos(ratio);
          add(a);
          add(-a);
        }
      }
      for (final y in [top, bottom]) {
        final ratio = (y - center.dy) / radius;
        if (ratio.abs() <= 1) {
          final a = math.asin(ratio);
          add(a);
          add(math.pi - a);
        }
      }
    }
    cuts.sort();
    final runs = <(double, double)>[];
    for (var i = 0; i < cuts.length - 1; i++) {
      if (cuts[i + 1] - cuts[i] < 1e-10) continue;
      final a = (cuts[i] + cuts[i + 1]) / 2;
      final direction = Offset(math.cos(a), math.sin(a));
      if (!rings.every((r) {
        final p = center + direction * r;
        return p.dx >= left - 1e-8 &&
            p.dx <= right + 1e-8 &&
            p.dy >= top - 1e-8 &&
            p.dy <= bottom + 1e-8;
      })) {
        continue;
      }
      if (runs.isNotEmpty && runs.last.$2 == cuts[i]) {
        runs[runs.length - 1] = (runs.last.$1, cuts[i + 1]);
      } else {
        runs.add((cuts[i], cuts[i + 1]));
      }
    }
    // Join a visible run that crosses the zero-angle seam.
    if (runs.length > 1 && runs.first.$1 == 0 && runs.last.$2 == turn) {
      runs[0] = (runs.last.$1, runs.first.$2 + turn);
      runs.removeLast();
    }
    // Opposing walls contribute continuously instead of switching the preferred
    // side at the viewport midpoint. Near the top, this turns left -> down ->
    // right as the root crosses the screen (and mirrors near the bottom).
    final reach = _restingRadii?.last ?? radii.last;
    final leftPressure = math.max(0.0, reach - (center.dx - left));
    final rightPressure = math.max(0.0, reach - (right - center.dx));
    final topPressure = math.max(0.0, reach - (center.dy - top));
    final bottomPressure = math.max(0.0, reach - (bottom - center.dy));
    // Walls still steer the fan after the resting ring clears them. A hard
    // zero outside that ring removes all vertical preference in free space,
    // causing a left/right flip as opposing side pressures cross equality.
    // This smooth falloff retains the direction toward the larger clearance.
    final softness = radii.first;
    double influence(double distance) {
      final overlap = reach - distance;
      return (overlap + math.sqrt(overlap * overlap + softness * softness)) / 2;
    }

    final pressure = Offset(
      influence(center.dx - left) - influence(right - center.dx),
      influence(center.dy - top) - influence(bottom - center.dy),
    );
    final inward = center.dx < _size!.width / 2 ? 0.0 : math.pi;
    final preferred = pressure.distanceSquared < 1e-12
        ? inward
        : inward +
              math.atan2(
                math.sin(pressure.direction - inward),
                math.cos(pressure.direction - inward),
              );
    (double, double)? best;
    var bestWidth = -1.0;
    var bestDistance = double.infinity;
    var bestMinimum = 0.0;
    var bestMaximum = 0.0;
    for (final run in runs) {
      final width = math.min(maxSpan, run.$2 - run.$1);
      final fullCircle = run.$2 - run.$1 >= turn - 1e-8;
      final shift = ((preferred - (run.$1 + run.$2) / 2) / turn).round() * turn;
      final minimum = fullCircle
          ? preferred - math.pi
          : run.$1 + shift + width / 2;
      final maximum = fullCircle
          ? preferred + math.pi
          : math.max(minimum, run.$2 + shift - width / 2);
      final middle = preferred.clamp(minimum, maximum);
      final distance = (middle - preferred).abs();
      if (width > bestWidth + 1e-8 ||
          ((width - bestWidth).abs() <= 1e-8 && distance < bestDistance)) {
        best = (middle - width / 2, middle + width / 2);
        bestWidth = width;
        bestDistance = distance;
        bestMinimum = minimum;
        bestMaximum = maximum;
      }
    }
    if (best == null || !balance || bestMaximum - bestMinimum < 1e-10) {
      return best;
    }

    final width = best.$2 - best.$1;
    double clearance(double angle) {
      final direction = Offset(math.cos(angle), math.sin(angle));
      var gap = double.infinity;
      for (final r in rings) {
        final p = center + direction * r;
        gap = math.min(
          gap,
          math.min(
            math.min(p.dx - left, right - p.dx),
            math.min(p.dy - top, bottom - p.dy),
          ),
        );
      }
      return gap;
    }

    double difference(double middle) =>
        clearance(middle - width / 2) - clearance(middle + width / 2);
    var chosen = (best.$1 + best.$2) / 2;
    var error = difference(chosen).abs();
    if (error < 1e-7) return best;
    void consider(double middle) {
      final candidateError = difference(middle).abs();
      final balanced = candidateError < .001;
      final wasBalanced = error < .001;
      if ((balanced && !wasBalanced) ||
          (balanced &&
              wasBalanced &&
              (middle - preferred).abs() < (chosen - preferred).abs()) ||
          (!balanced && !wasBalanced && candidateError < error)) {
        chosen = middle;
        error = candidateError;
      }
    }

    // Find balanced cap clearances near the direction of available space.
    var previous = bestMinimum;
    var previousValue = difference(previous);
    consider(previous);
    for (var step = 1; step <= 16; step++) {
      final current = bestMinimum + (bestMaximum - bestMinimum) * step / 16;
      final value = difference(current);
      consider(current);
      if (previousValue * value < 0) {
        var low = previous;
        var high = current;
        var lowValue = previousValue;
        for (var iteration = 0; iteration < 20; iteration++) {
          final middle = (low + high) / 2;
          final middleValue = difference(middle);
          if (lowValue * middleValue <= 0) {
            high = middle;
          } else {
            low = middle;
            lowValue = middleValue;
          }
        }
        consider((low + high) / 2);
      }
      previous = current;
      previousValue = value;
    }
    // Exact equality can have two separated solutions when opposite walls
    // compete. Fade that correction as their influence becomes equal, keeping
    // the continuous space-driven orientation instead of flipping solutions.
    double dominance(double a, double b) =>
        a == 0 || b == 0 ? 1 : math.min(1.0, 2 * (a - b).abs() / (a + b));
    final correction = math.min(
      dominance(leftPressure, rightPressure),
      dominance(topPressure, bottomPressure),
    );
    final ideal = (best.$1 + best.$2) / 2;
    final middle = ideal + (chosen - ideal) * correction;
    return (middle - width / 2, middle + width / 2);
  }

  Object? _menuLayoutKey;
  List<double>? _restingRadii;
  final Map<int, double> _levelPhases = {};
  final Map<int, bool> _levelReversed = {};

  (List<double>, (double, double)?) _menuLayout(double diameter) {
    final base = _baseMenuLayout(diameter);
    final arc = base.$2;
    final resting = _restingRadii;
    if (arc == null ||
        resting == null ||
        base.$1.last >= resting.last - 1e-7 ||
        (_grabOffset == null && !widget.debug.layoutPreview)) {
      return base;
    }
    final span = arc.$2 - arc.$1;
    final roomToImprove = ((2 * math.pi - span) / math.pi).clamp(0.0, 1.0);
    if (roomToImprove <= 1e-8) return base;
    final near = resting.first;
    final range = resting.last - near;
    if (range <= 1e-8) return base;
    final scale = (base.$1.last - near) / range;
    final middle = (arc.$1 + arc.$2) / 2;
    final levels = _levels;

    // Compare actual chord clearances, including the radial clearance between
    // levels. Saturate at a comfortable gap so excess space can instead restore
    // resting radii. Smooth weights avoid switching between discrete winners.
    double clearance(List<double> radii, double width) {
      var gap = double.infinity;
      int? previous;
      for (var level = 0; level < levels.length; level++) {
        final count = levels[level].length;
        if (count == 0) continue;
        if (count > 1) {
          final step = math.min(width / (count - 1), 2 * math.pi / count);
          gap = math.min(gap, 2 * radii[level] * math.sin(step / 2) - diameter);
        }
        if (previous != null) {
          gap = math.min(gap, radii[level] - radii[previous] - diameter);
        }
        previous = level;
      }
      return gap;
    }

    double ease(double value) {
      final t = value.clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    const comfortableGap = 8.0;
    final baseGap = math.min(comfortableGap, clearance(base.$1, span));
    var weight = 1.0;
    var targetScale = scale;
    var width = span;
    const samples = 12;
    for (var sample = 1; sample <= samples; sample++) {
      final fraction = sample / samples;
      final candidateScale = scale + (1 - scale) * fraction;
      final radii = [
        for (final r in resting) near + (r - near) * candidateScale,
      ];
      final candidate = _sharedMenuArc(
        diameter,
        radii,
        maxSpan: span,
        balance: false,
        fixedMiddle: middle,
      );
      if (candidate == null) continue;
      final gap = clearance(radii, candidate.$2 - candidate.$1);
      final score =
          math.min(comfortableGap, gap) +
          comfortableGap * fraction * ease((gap - baseGap) / comfortableGap);
      final contribution =
          ease((score - baseGap) / (3 * comfortableGap)) * roomToImprove;
      if (contribution == 0) continue;
      weight += contribution;
      targetScale += contribution * candidateScale;
      width += contribution * (candidate.$2 - candidate.$1);
    }
    if (weight == 1) return base;
    final resultArc = (
      middle - width / weight / 2,
      middle + width / weight / 2,
    );
    // Interpolated arcs stay in the same connected visible run. Limit the
    // outward movement analytically so every intermediate layout is safe.
    final center =
        _menuPosition +
        Offset(widget.layout.diameter / 2, widget.layout.diameter / 2);
    final half = diameter / 2;
    final bounds = Rect.fromLTRB(
      half + math.max(_menuInset(diameter), 4.0),
      half + 4,
      _size!.width - half - math.max(_menuInset(diameter), 4.0),
      _size!.height - half - 4,
    );
    if (!bounds.contains(center)) return base;
    var limit = near + range * targetScale / weight;
    final angles = [resultArc.$1, resultArc.$2];
    for (
      var i = (resultArc.$1 / (math.pi / 2)).ceil();
      i * math.pi / 2 <= resultArc.$2;
      i++
    ) {
      angles.add(i * math.pi / 2);
    }
    for (final angle in angles) {
      final x = math.cos(angle), y = math.sin(angle);
      if (x > 1e-10) limit = math.min(limit, (bounds.right - center.dx) / x);
      if (x < -1e-10) limit = math.min(limit, (bounds.left - center.dx) / x);
      if (y > 1e-10) limit = math.min(limit, (bounds.bottom - center.dy) / y);
      if (y < -1e-10) limit = math.min(limit, (bounds.top - center.dy) / y);
    }
    final resultScale = ((limit - near) / range).clamp(scale, 1.0);
    return (
      [for (final r in resting) near + (r - near) * resultScale],
      resultArc,
    );
  }

  (List<double>, (double, double)?) _baseMenuLayout(double diameter) {
    final base = _solveMenuLayout(diameter);
    final arc = base.$2;
    final resting = _restingRadii;
    if (!_expanded ||
        arc == null ||
        resting == null ||
        arc.$2 - arc.$1 < math.pi - 1e-7) {
      return base;
    }
    final center =
        _menuPosition +
        Offset(widget.layout.diameter / 2, widget.layout.diameter / 2);
    final half = diameter / 2;
    final inset = math.max(_menuInset(diameter), 4.0);
    final bounds = Rect.fromLTRB(
      half + inset,
      half + 4,
      _size!.width - half - inset,
      _size!.height - half - 4,
    );
    final distances = [
      center.dx - bounds.left,
      bounds.right - center.dx,
      center.dy - bounds.top,
      bounds.bottom - center.dy,
    ];
    final wide = _sharedMenuArc(diameter, base.$1, maxSpan: 2 * math.pi)!;
    final ordered = [...distances]..sort();
    final capacity = math.min(bounds.width, bounds.height) / 2;
    final outer = base.$1.last;
    final thirdWall = ordered[2];
    // Three walls can split the visible ring into disconnected runs. As a
    // wall clears the ring, unfold the newly joined run continuously rather
    // than adding that entire angular region at its tangency threshold.
    // At the viewport's inscribed radius, this reaches the whole available
    // arc, so closing a ring never leaves an artificial directional gap.
    final progress = thirdWall <= capacity
        ? (wide.$2 - wide.$1 >= 2 * math.pi - 1e-8 ? 1.0 : 0.0)
        : ((thirdWall - outer) / (thirdWall - capacity)).clamp(0.0, 1.0);
    final unfold = progress * progress * (3 - 2 * progress);
    if (unfold == 0) return base;
    final span =
        arc.$2 - arc.$1 + ((wide.$2 - wide.$1) - (arc.$2 - arc.$1)) * unfold;
    return (base.$1, _sharedMenuArc(diameter, base.$1, maxSpan: span));
  }

  (List<double>, (double, double)?) _solveMenuLayout(double diameter) {
    if (!_expanded) {
      _menuLayoutKey = null;
      _levelPhases.clear();
      _levelReversed.clear();
      return (const [], null);
    }
    final key = (
      _size,
      diameter,
      widget.layout.diameter,
      widget.layout.levelRadius,
      _levels.map((level) => level.length).join(','),
    );
    if (_menuLayoutKey != key) {
      _menuLayoutKey = key;
      _restingRadii = _menuRadii(diameter);
      if (!widget.debug.layoutPreview) {
        return (_restingRadii!, _sharedMenuArc(diameter, _restingRadii!));
      }
    }
    final resting = _restingRadii!;
    // Real items target the final dock and can use its resting radii. The
    // preview follows the moving root, so it must keep solving for available
    // space throughout docking instead of forcing a radius reset on release.
    if (_grabOffset == null && !widget.debug.layoutPreview) {
      final arc = _sharedMenuArc(diameter, resting);
      if (arc != null) {
        return (resting, arc);
      }
      final radii = _menuRadii(diameter);
      return (radii, _sharedMenuArc(diameter, radii));
    }
    List<double> compressed(double scale) => [
      for (final radius in resting)
        resting.first + (radius - resting.first) * scale,
    ];

    // Rotation gets the first chance to preserve the fan's width. The fixed
    // inner ring limits the useful span: compressing outer gaps cannot help
    // an end cap that already collides on that ring.
    final innerArc = _sharedMenuArc(diameter, [resting.first], balance: false);
    if (innerArc == null) {
      return (resting, null);
    }
    final desiredWidth = innerArc.$2 - innerArc.$1;
    bool wideEnough((double, double)? arc) =>
        arc != null && arc.$2 - arc.$1 >= desiredWidth - 1e-8;
    final fullArc = _sharedMenuArc(diameter, resting);
    if (wideEnough(fullArc)) {
      return (resting, fullArc);
    }

    // Only compress when even the best rotation cannot maintain that span.
    // Each smaller outer radius lies between the previous one and the fixed
    // inner ring, so its available angles can only increase.
    var radii = compressed(0.5);
    var arc = _sharedMenuArc(diameter, radii);
    if (wideEnough(arc)) {
      var low = 0.5;
      var high = 1.0;
      for (var step = 0; step < 24; step++) {
        final scale = (low + high) / 2;
        final candidate = _sharedMenuArc(
          diameter,
          compressed(scale),
          balance: false,
        );
        if (wideEnough(candidate)) {
          low = scale;
        } else {
          high = scale;
        }
      }
      radii = compressed(low);
      arc = _sharedMenuArc(diameter, radii);
    } else if (arc == null) {
      // Keep the existing visibility fallback for very small viewports.
      radii = _menuRadii(diameter);
      arc = _sharedMenuArc(diameter, radii);
    }
    return (radii, arc);
  }

  List<Offset> _menuTargets(
    double diameter,
    List<double> radii,
    (double, double)? arc,
  ) {
    final levels = _levels;
    return [
      for (var level = 0; level < levels.length; level++)
        ..._levelTargets(
          diameter,
          levels[level].length,
          radii[level],
          sharedArc: arc,
          level: level,
        ),
    ];
  }

  Duration _levelDelay(int index) {
    final levels = _levels;
    var level = 0;
    while (level < levels.length - 1 && index >= levels[level].length) {
      index -= levels[level++].length;
    }
    return Duration(
      milliseconds: 50 * (_expanded ? levels.length - 1 - level : level),
    );
  }

  @override
  void didUpdateWidget(covariant PuckMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _loadAnchor(reset: true);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      _attachController();
      _applyControllerRequestAfterBuild();
    }
    if (_menuPhase == _MenuPhase.collapsing || _opening) {
      if (widget.debug.layoutPreview) _pendingCollapse.clear();
      final identities = {
        for (var i = 0; i < _items.length; i++) _items[i].key ?? i,
      };
      _pendingCollapse.retainAll(identities);
      _pendingExpansion.retainAll(identities);
      if (_opening) {
        final oldItems = oldWidget.puckItems.expand((level) => level).toList();
        final oldIdentities = {
          for (var i = 0; i < oldItems.length; i++) oldItems[i].key ?? i,
        };
        _pendingExpansion.addAll(identities.difference(oldIdentities));
      }
      if (_menuPhase == _MenuPhase.collapsing && _pendingCollapse.isEmpty) {
        _menuPhase = _MenuPhase.closed;
      }
      final generation = _menuGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finishMenuTransition(generation);
      });
    }
    _geometryChanged =
        oldWidget.layout.diameter != widget.layout.diameter ||
        oldWidget.layout.offscreenFraction != widget.layout.offscreenFraction;
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    WidgetsBinding.instance.removeObserver(this);
    _curves.dispose();
    _cables.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth && constraints.hasBoundedHeight,
          'PuckMenu requires bounded width and height.',
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
        final newBottom = math.max(0.0, size.height - widget.layout.diameter);
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
        // Keyboard-driven moves must never replace a user-chosen anchor.
        if (_keyboardHeight != keyboard) _saveAnchorOnSettle = null;
        _keyboardHeight = keyboard;
        final firstLayout = _size == null || _resetAnchor;
        if (_resetAnchor) {
          _resetAnchor = false;
          _edge = widget.layout.initialEdge;
          _ticker.stop();
          _returnSpring = null;
          _returnTargetY = null;
          _awaitingSettle = false;
          widget.controller?._isSettled = !_dragging;
        }
        if (firstLayout || _size != size || _geometryChanged) {
          final horizontalGeometryChanged =
              firstLayout || _size!.width != size.width || _geometryChanged;
          _geometryChanged = false;
          if (horizontalGeometryChanged) {
            _ticker.stop();
            // A resize places the root directly on its new anchor.
            if (_awaitingSettle && !_dragging) {
              _awaitingSettle = false;
              final controller = widget.controller;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    !_awaitingSettle &&
                    !_dragging &&
                    identical(widget.controller, controller)) {
                  controller?._settled();
                }
              });
            }
          }
          _size = size;
          _position = Offset(
            horizontalGeometryChanged
                ? (_edge == PuckEdge.left ? _left : _right)
                : _position.dx,
            firstLayout
                ? _bottom * widget.layout.initialVerticalAlignment
                : _position.dy.clamp(0, _bottom),
          );
        }
        final restored = _pendingRestoredAnchor;
        if (restored != null) {
          _pendingRestoredAnchor = null;
          _ticker.stop();
          _edge = restored.edge;
          _position = Offset(
            _edge == PuckEdge.left ? _left : _right,
            _bottom * restored.verticalAlignment,
          );
          _menuLayoutKey = null;
          _levelPhases.clear();
          _levelReversed.clear();
        }
        _position = _constrainVertical(_position);
        if (restore) _dock(Offset.zero);
        final itemDiameter = math.min(
          widget.layout.puckDiameter,
          math.min(size.width, size.height),
        );
        final origin =
            _position +
            Offset(
              (widget.layout.diameter - itemDiameter) / 2,
              (widget.layout.diameter - itemDiameter) / 2,
            );
        final items = _items;
        final generation = _menuGeneration;
        final levels = _levels;
        final itemLevels = [
          for (var level = 0; level < levels.length; level++)
            for (var item = 0; item < levels[level].length; item++) level,
        ];
        PuckOpeningTrace.instant('overlay.layout.begin');
        final (radii, arc) = PuckOpeningTrace.measure(
          'menu.layout.solve',
          () => _menuLayout(itemDiameter),
        );
        final targets =
            _expanded &&
                (!widget.debug.layoutPreview || widget.debug.showAnchors)
            ? PuckOpeningTrace.measure(
                'menu.targets',
                () => _menuTargets(itemDiameter, radii, arc),
              )
            : const <Offset>[];
        PuckOpeningTrace.instant('overlay.targets.ready');
        if (_expanded) {
          _curves.fullCircle =
              arc != null && arc.$2 - arc.$1 >= 2 * math.pi - 1e-8;
        }
        final menuPucks = <Widget>[
          if (!widget.debug.layoutPreview && _menuPhase != _MenuPhase.closed)
            for (var i = 0; i < items.length; i++)
              if (_expanded || _pendingCollapse.contains(items[i].key ?? i))
                SpringPuck(
                  key: ValueKey(items[i].key ?? i),
                  origin: origin,
                  delay: _levelDelay(i),
                  motionClock: _menuMotionClock,
                  cables: _cables,
                  showRopes: widget.showRopes,
                  curves: widget.debug.showLevelCurves ? _curves : null,
                  level: itemLevels[i],
                  order: i,
                  target: _expanded ? targets[i] : origin,
                  diameter: itemDiameter,
                  parentDiameter: widget.layout.diameter,
                  bounds: size,
                  horizontalInset: _menuInset(itemDiameter),
                  expanded: _expanded,
                  onCollapsed: () =>
                      _itemCollapsed(items[i].key ?? i, generation),
                  onExpanded: () =>
                      _itemExpanded(items[i].key ?? i, generation),
                  child: items[i],
                ),
        ];
        final menuWidgets = widget.debug.layoutPreview
            ? <Widget>[
                if (_expanded)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: PuckLayoutPreviewPainter(
                          center:
                              _menuPosition +
                              Offset(
                                widget.layout.diameter / 2,
                                widget.layout.diameter / 2,
                              ),
                          radii: radii,
                          itemDiameter: itemDiameter,
                          arc: arc,
                        ),
                      ),
                    ),
                  ),
              ]
            : menuPucks;
        return Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            if (widget.debug.showLevelCurves && !widget.debug.layoutPreview)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: PuckLevelCurvePainter(
                        _curves,
                        parentBounds:
                            _position & Size.square(widget.layout.diameter),
                        color:
                            widget.arcStyle.color ??
                            (Theme.brightnessOf(context) == Brightness.dark
                                ? const Color(0xFF424242)
                                : const Color(0xFFD1D5DB)),
                        thickness: widget.arcStyle.thickness,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.showRopes && !widget.debug.layoutPreview)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: PuckCablePainter(
                      _cables,
                      style: widget.ropeStyle,
                      parentBounds:
                          _position & Size.square(widget.layout.diameter),
                    ),
                  ),
                ),
              ),
            ...menuWidgets,
            // Paint the parent after every menu item, including while their
            // springs overlap it during expansion and collapse.
            Positioned(
              left: _position.dx,
              top: _position.dy,
              width: widget.layout.diameter,
              height: widget.layout.diameter,
              child: ClipOval(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleMenu,
                  onPanDown: (details) {
                    // A late disk read must not move a puck the user touched.
                    _anchorRequest++;
                    _pendingRestoredAnchor = null;
                    _ticker.stop();
                    _grabOffset = details.localPosition;
                  },
                  onPanStart: (_) {
                    _dragging = true;
                    _awaitingSettle = true;
                    widget.controller?._dragStarted();
                  },
                  onPanUpdate: (details) {
                    // A deliberate drag supersedes the pre-keyboard location.
                    _keyboardOriginalY = null;
                    if (_keyboardHeight > 0) {
                      _draggedWithKeyboard = true;
                    }
                    final box = context.findRenderObject()! as RenderBox;
                    setState(() {
                      _position = _constrainVertical(
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
                  child: widget.rootPuck,
                ),
              ),
            ),
            if (widget.debug.showAnchors)
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
                            Offset(
                              widget.layout.diameter / 2,
                              widget.layout.diameter / 2,
                            ),
                        for (var i = 0; i < items.length; i++)
                          if (_menuPhase != _MenuPhase.closed &&
                              (_expanded ||
                                  _pendingCollapse.contains(items[i].key ?? i)))
                            (_expanded ? targets[i] : origin) +
                                Offset(itemDiameter / 2, itemDiameter / 2),
                      ],
                      center:
                          _menuPosition +
                          Offset(
                            widget.layout.diameter / 2,
                            widget.layout.diameter / 2,
                          ),
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
