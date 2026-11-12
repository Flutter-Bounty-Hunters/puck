import 'package:flutter/widgets.dart';

import 'puck_rope_style.dart';

/// Geometry shared by the independently animated items and their cable layer.
class PuckCables extends ChangeNotifier {
  final _items = <Object, ({List<Offset> points, Rect bounds})>{};

  // Updated during build, before the cable layer paints. Notifications happen
  // on animation ticks so no widget is marked dirty during another's build.
  void update(
    Object identity, {
    required List<Offset> points,
    required Rect bounds,
  }) {
    _items[identity] = (points: points, bounds: bounds);
  }

  void remove(Object identity) => _items.remove(identity);
  void repaint() => notifyListeners();
}

/// Clips only cable strokes, leaving the page and translucent pucks intact.
class PuckCablePainter extends CustomPainter {
  PuckCablePainter(
    this.cables, {
    required this.parentBounds,
    this.style = const PuckRopeStyle(),
  }) : super(repaint: cables);

  final PuckCables cables;
  final Rect parentBounds;
  final PuckRopeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final circles = Path()..addOval(parentBounds);
    for (final item in cables._items.values) {
      circles.addOval(item.bounds);
    }
    // Nonzero fill makes overlapping circles a union, with no exposed lenses.
    final visible = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      circles,
    );
    canvas.save();
    canvas.clipPath(visible);
    for (final item in cables._items.values) {
      final points = item.points;
      if (points.isEmpty) continue;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length - 1; i++) {
        final midpoint = (points[i] + points[i + 1]) / 2;
        path.quadraticBezierTo(
          points[i].dx,
          points[i].dy,
          midpoint.dx,
          midpoint.dy,
        );
      }
      path.lineTo(points.last.dx, points.last.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = style.darkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.thickness
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = style.brightColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.thickness / 2
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PuckCablePainter oldDelegate) => true; // A rebuild may add or remove items without an animation tick.
}
