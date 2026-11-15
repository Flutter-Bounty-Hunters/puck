import 'package:flutter/foundation.dart';

/// Optional visual diagnostics for a puck menu. Disabled by default.
@immutable
class PuckMenuDebug {
  const PuckMenuDebug({
    this.showAnchors = false,
    this.showLevelCurves = false,
    this.layoutPreview = false,
  });

  /// Draw level perimeters, shared end caps, and red spring-destination dots.
  /// During dragging the root marker follows the puck; during docking it
  /// marks the landing position. Item dots exist only while items are mounted.
  final bool showAnchors;

  /// Connect each level's moving items with a circular curve, clipped around
  /// the pucks. Curves follow the springs and fade near the root.
  final bool showLevelCurves;

  /// Replace items and their springs with radius guides, item-width bands,
  /// and filled sectors for the solved arc, using the normal layout rules.
  final bool layoutPreview;
}
