import 'package:flutter/foundation.dart';

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
