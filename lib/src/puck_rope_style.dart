import 'package:flutter/widgets.dart';

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
