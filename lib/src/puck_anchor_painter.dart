import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Paints spring destinations in overlay coordinates, above all puck content.
class PuckAnchorPainter extends CustomPainter {
  const PuckAnchorPainter(this.anchors);

  final List<Offset> anchors;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFF0000);
    for (final anchor in anchors) {
      canvas.drawCircle(anchor, 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PuckAnchorPainter oldDelegate) =>
      !listEquals(anchors, oldDelegate.anchors);
}
