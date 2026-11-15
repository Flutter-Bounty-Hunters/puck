import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Shows the solved level geometry without creating animated menu items.
class PuckLayoutPreviewPainter extends CustomPainter {
  const PuckLayoutPreviewPainter({
    required this.center,
    required this.radii,
    required this.itemDiameter,
    required this.arc,
  });

  final Offset center;
  final List<double> radii;
  final double itemDiameter;
  final (double, double)? arc;

  static const _colors = [
    Color(0xFF6DDACB),
    Color(0xFF9CAFFF),
    Color(0xFFF1BF7A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // Filled pie slices sit behind all bands and center-radius guides. Paint
    // farthest first so every level's sector remains distinguishable.
    final angles = arc;
    if (angles != null) {
      final (start, end) = angles;
      for (var level = radii.length - 1; level >= 0; level--) {
        paint
          ..style = PaintingStyle.fill
          ..color = _colors[level % _colors.length].withValues(alpha: 0.16);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radii[level]),
          start,
          end - start,
          true,
          paint,
        );
      }
    }
    for (var level = 0; level < radii.length; level++) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = itemDiameter
        ..color = _colors[level % _colors.length].withValues(alpha: 0.13);
      canvas.drawCircle(center, radii[level], paint);
    }
    for (var level = 0; level < radii.length; level++) {
      paint
        ..strokeWidth = 1.25
        ..color = _colors[level % _colors.length];
      canvas.drawCircle(center, radii[level], paint);
    }
  }

  @override
  bool shouldRepaint(covariant PuckLayoutPreviewPainter oldDelegate) =>
      center != oldDelegate.center ||
      itemDiameter != oldDelegate.itemDiameter ||
      arc != oldDelegate.arc ||
      !listEquals(radii, oldDelegate.radii);
}
