import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

/// Live item geometry shared with the tier arc layer.
class PuckTierCurveItem {
  PuckTierCurveItem(this.bounds, this.tier, this.order);
  Rect bounds;
  final int tier;
  final int order;
}

class PuckTierCurves extends ChangeNotifier {
  bool fullCircle = false;
  final _items = <Object, PuckTierCurveItem>{};
  List<List<PuckTierCurveItem>>? _tiers;
  Duration? _lastRepaint;

  Iterable<PuckTierCurveItem> get items => _items.values;

  // Membership/order changes invalidate this cache; animation only updates bounds.
  List<List<PuckTierCurveItem>> get tiers => _tiers ??= _groupTiers();
  List<List<PuckTierCurveItem>> _groupTiers() {
    final grouped = <int, List<PuckTierCurveItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.tier, () => []).add(item);
    }
    return [
      for (final tier in grouped.values)
        tier..sort((a, b) => a.order.compareTo(b.order)),
    ];
  }

  void update(
    Object identity, {
    required Rect bounds,
    required int tier,
    required int order,
  }) {
    final item = _items[identity];
    if (item != null && item.tier == tier && item.order == order) {
      item.bounds = bounds;
    } else {
      _items[identity] = PuckTierCurveItem(bounds, tier, order);
      _tiers = null;
    }
  }

  void remove(Object identity) {
    if (_items.remove(identity) != null) _tiers = null;
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
class PuckTierCurvePainter extends CustomPainter {
  PuckTierCurvePainter(this.curves, {required this.parentBounds})
    : super(repaint: curves);

  final PuckTierCurves curves;
  final Rect parentBounds;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (final tier in curves.tiers) {
      if (tier.length < 2) continue;
      final distance =
          tier.fold(
            0.0,
            (sum, item) =>
                sum + (item.bounds.center - parentBounds.center).distance,
          ) /
          tier.length;
      final opacity =
          ((distance - parentBounds.shortestSide / 2) /
                  tier.first.bounds.shortestSide)
              .clamp(0.0, 1.0);
      if (opacity == 0) continue;
      final first = tier.first.bounds.center;
      final last = tier.last.bounds.center;
      if ((last - first).distance < 0.001) continue;
      var center = parentBounds.center;
      if (tier.length >= 3) {
        // Fit the live centers so the circle follows the spring's scale and
        // translation, rather than approximating it with joined segments.
        final b = tier[tier.length ~/ 2].bounds.center - first;
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
      } else if (tier.length >= 3) {
        final middle =
            ((tier[tier.length ~/ 2].bounds.center - center).direction -
                start) %
            (2 * math.pi);
        if (middle > sweep + 1e-6) sweep -= 2 * math.pi;
      } else if (sweep > math.pi) {
        sweep -= 2 * math.pi;
      }
      paint.color = const Color(0xFF818CF8).withValues(alpha: 0.65 * opacity);
      final span = sweep.abs();
      final direction = sweep.sign;
      final covered = <(double, double)>[];
      var hidden = false;
      void exclude(Rect bounds) {
        // Inflate by half the stroke so rounded segment ends cannot bleed
        // into even translucent pucks. No boolean paths, masks, or saveLayers.
        final holeRadius = bounds.shortestSide / 2 + paint.strokeWidth / 2;
        final delta = bounds.center - center;
        final distance = delta.distance;
        if (distance + radius <= holeRadius) {
          hidden = true;
          return;
        }
        if (distance < 1e-6 ||
            distance >= radius + holeRadius ||
            distance + holeRadius <= radius) {
          return;
        }
        final halfAngle = math.acos(
          ((radius * radius + distance * distance - holeRadius * holeRadius) /
                  (2 * radius * distance))
              .clamp(-1.0, 1.0),
        );
        final angle = ((delta.direction - start) * direction) % (2 * math.pi);
        for (final shift in [-2 * math.pi, 0.0, 2 * math.pi]) {
          final from = math.max(0.0, angle + shift - halfAngle);
          final to = math.min(span, angle + shift + halfAngle);
          if (from < to) covered.add((from, to));
        }
      }

      exclude(parentBounds);
      for (final item in curves.items) {
        exclude(item.bounds);
      }
      if (hidden) continue;
      covered.sort((a, b) => a.$1.compareTo(b.$1));
      final circle = Rect.fromCircle(center: center, radius: radius);
      var cursor = 0.0;
      void drawTo(double end) {
        if (end > cursor + 1e-6) {
          canvas.drawArc(
            circle,
            start + direction * cursor,
            direction * (end - cursor),
            false,
            paint,
          );
        }
      }

      for (final interval in covered) {
        drawTo(interval.$1);
        cursor = math.max(cursor, interval.$2);
      }
      drawTo(span);
    }
  }

  @override
  bool shouldRepaint(covariant PuckTierCurvePainter oldDelegate) => true;
}
