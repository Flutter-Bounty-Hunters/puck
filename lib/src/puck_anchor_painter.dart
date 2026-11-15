import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Paints spring destinations in overlay coordinates, above all puck content.
class PuckAnchorPainter extends CustomPainter {
  const PuckAnchorPainter(
    this.anchors, {
    this.center = Offset.zero,
    this.radii = const [],
    this.arc,
  });

  final List<Offset> anchors;
  final Offset center;
  final List<double> radii;

  /// Shared start and end angles for the level arcs, in radians.
  final (double, double)? arc;

  @override
  void paint(Canvas canvas, Size size) {
    final perimeter = Paint()
      ..color = const Color(0x88FF0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final radius in radii) {
      if (arc == null) {
        canvas.drawCircle(center, radius, perimeter);
      } else {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          arc!.$1,
          arc!.$2 - arc!.$1,
          false,
          perimeter,
        );
      }
    }
    if (arc != null && radii.isNotEmpty) {
      for (final angle in [arc!.$1, arc!.$2]) {
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          center,
          center + direction * (radii.last + 24),
          perimeter,
        );
      }
    }
    final paint = Paint()..color = const Color(0xFFFF0000);
    for (final anchor in anchors) {
      canvas.drawCircle(anchor, 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PuckAnchorPainter oldDelegate) =>
      !listEquals(anchors, oldDelegate.anchors) ||
      center != oldDelegate.center ||
      arc != oldDelegate.arc ||
      !listEquals(radii, oldDelegate.radii);
}
