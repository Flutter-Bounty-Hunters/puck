import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

/// Live item geometry shared with the level arc layer.
class PuckLevelCurveItem {
  PuckLevelCurveItem(this.bounds, this.level, this.order);
  Rect bounds;
  final int level;
  final int order;
}

class PuckLevelCurves extends ChangeNotifier {
  bool fullCircle = false;
  final _items = <Object, PuckLevelCurveItem>{};
  List<List<PuckLevelCurveItem>>? _levels;
  Duration? _lastRepaint;

  Iterable<PuckLevelCurveItem> get items => _items.values;

  // Membership/order changes invalidate this cache; animation only updates bounds.
  List<List<PuckLevelCurveItem>> get levels => _levels ??= _groupLevels();
  List<List<PuckLevelCurveItem>> _groupLevels() {
    final grouped = <int, List<PuckLevelCurveItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.level, () => []).add(item);
    }
    return [
      for (final level in grouped.values)
        level..sort((a, b) => a.order.compareTo(b.order)),
    ];
  }

  void update(
    Object identity, {
    required Rect bounds,
    required int level,
    required int order,
  }) {
    final item = _items[identity];
    if (item != null && item.level == level && item.order == order) {
      item.bounds = bounds;
    } else {
      _items[identity] = PuckLevelCurveItem(bounds, level, order);
      _levels = null;
    }
  }

  void remove(Object identity) {
    if (_items.remove(identity) != null) _levels = null;
  }

  void repaint() {
    // All item tickers run before painting. One notification covers the frame.
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase != SchedulerPhase.idle) {
      final frame = scheduler.currentFrameTimeStamp;
      if (frame == _lastRepaint) return;
      _lastRepaint = frame;
    }
    notifyListeners();
  }
}

/// Connects the moving centers, with circular holes for every visible puck.
class PuckLevelCurvePainter extends CustomPainter {
  PuckLevelCurvePainter(
    this.curves, {
    required this.parentBounds,
    this.color = const Color(0xFFD1D5DB),
    this.thickness = 4,
  }) : super(repaint: curves);

  final PuckLevelCurves curves;
  final Rect parentBounds;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    // Cut out the actual puck circles once for the entire connector layer.
    // Separate inverse clips keep overlapping holes excluded too; no boolean
    // path operations or offscreen layers are needed.
    canvas.save();
    void exclude(Rect bounds) {
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addOval(bounds),
      );
    }

    exclude(parentBounds);
    for (final item in curves.items) {
      exclude(item.bounds);
    }
    for (final level in curves.levels) {
      if (level.length < 2) continue;
      final distance =
          level.fold(
            0.0,
            (sum, item) =>
                sum + (item.bounds.center - parentBounds.center).distance,
          ) /
          level.length;
      final opacity =
          ((distance - parentBounds.shortestSide / 2) /
                  level.first.bounds.shortestSide)
              .clamp(0.0, 1.0);
      if (opacity == 0) continue;
      final first = level.first.bounds.center;
      final last = level.last.bounds.center;
      if ((last - first).distance < 0.001) continue;
      var center = parentBounds.center;
      if (level.length >= 3) {
        // Fit the live centers so the circle follows the spring's scale and
        // translation, rather than approximating it with joined segments.
        final b = level[level.length ~/ 2].bounds.center - first;
        final c = last - first;
        final determinant = 2 * (b.dx * c.dy - b.dy * c.dx);
        if (determinant.abs() < 0.001) continue;
        center =
            first +
            Offset(
              (b.distanceSquared * c.dy - c.distanceSquared * b.dy) /
                  determinant,
              (b.dx * c.distanceSquared - c.dx * b.distanceSquared) /
                  determinant,
            );
      }
      final radius = (first - center).distance;
      final start = (first - center).direction;
      var sweep = ((last - center).direction - start) % (2 * math.pi);
      if (curves.fullCircle) {
        sweep = 2 * math.pi;
      } else if (level.length >= 3) {
        final middle =
            ((level[level.length ~/ 2].bounds.center - center).direction -
                start) %
            (2 * math.pi);
        if (middle > sweep + 1e-6) sweep -= 2 * math.pi;
      } else if (sweep > math.pi) {
        sweep -= 2 * math.pi;
      }
      paint.color = color.withValues(alpha: color.a * opacity);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PuckLevelCurvePainter oldDelegate) => true;
}
