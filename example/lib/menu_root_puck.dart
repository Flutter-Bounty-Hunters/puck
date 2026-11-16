import 'package:flutter/material.dart';

/// Shared lighting and rim for the example's root pucks.
class MenuRootPuck extends StatelessWidget {
  const MenuRootPuck({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(foregroundPainter: const _RootRimPainter(), child: child);
}

class _RootRimPainter extends CustomPainter {
  const _RootRimPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawOval(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x26FFFFFF), Color(0x00FFFFFF), Color(0x24000000)],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      center,
      radius - 1.75,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.drawCircle(
      center,
      radius - 0.4,
      Paint()
        ..color = const Color(0xFFD1D5DB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_RootRimPainter oldDelegate) => false;
}
