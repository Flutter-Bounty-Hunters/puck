import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Shows the solved tier geometry without creating animated menu items.
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
    // farthest first so every tier's sector remains distinguishable.
    final angles = arc;
    if (angles != null) {
      final (start, end) = angles;
      for (var tier = radii.length - 1; tier >= 0; tier--) {
        paint
          ..style = PaintingStyle.fill
          ..color = _colors[tier % _colors.length].withValues(alpha: 0.16);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radii[tier]),
          start,
          end - start,
          true,
          paint,
        );
      }
    }
    for (var tier = 0; tier < radii.length; tier++) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = itemDiameter
        ..color = _colors[tier % _colors.length].withValues(alpha: 0.13);
      canvas.drawCircle(center, radii[tier], paint);
    }
    for (var tier = 0; tier < radii.length; tier++) {
      paint
        ..strokeWidth = 1.25
        ..color = _colors[tier % _colors.length];
      canvas.drawCircle(center, radii[tier], paint);
    }
  }

  @override
  bool shouldRepaint(covariant PuckLayoutPreviewPainter oldDelegate) =>
      center != oldDelegate.center ||
      itemDiameter != oldDelegate.itemDiameter ||
      arc != oldDelegate.arc ||
      !listEquals(radii, oldDelegate.radii);
}
