import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'puck_light_anchor.dart';
export 'puck_light_anchor.dart';

@immutable
class PuckLightSample {
  const PuckLightSample(this.direction, this.intensity, this.color);

  /// Unit vector from the puck toward the source, in screen coordinates.
  final Offset direction;
  final double intensity;
  final Color color;
}

/// Smooth inverse-square falloff, with a finite source size to avoid hot spots.
List<PuckLightSample> samplePuckLights(
  Offset center,
  Size screenSize, {
  Iterable<PuckLightSource> sources = const [],
}) {
  if (screenSize.isEmpty) return const [];
  final falloff = screenSize.shortestSide * 0.85;
  return [
    for (final source in sources)
      (() {
        final delta = source.position - center;
        final distance = delta.distance;
        return PuckLightSample(
          distance > 0.001 ? delta / distance : const Offset(0, -1),
          source.intensity / (1 + delta.distanceSquared / (falloff * falloff)),
          source.color,
        );
      })(),
  ];
}

/// Boost faint highlights without clipping nearby lights to identical brightness.
double puckLightEnergy(double intensity, {required double exposure}) =>
    1 - math.exp(-intensity * exposure);

/// Blend smoothly into interior illumination as the light crosses the rim.
double puckInteriorLightBlend(double distance, double radius) {
  if (radius <= 0) {
    return 0;
  }
  final progress = ((radius * 1.10 - distance) / (radius * 0.45)).clamp(
    0.0,
    1.0,
  );
  return progress * progress * (3 - 2 * progress);
}

/// Build the near-field glare across the last few puck radii of approach.
double puckNearLightBlend(double distance, double radius) {
  if (radius <= 0) {
    return 0;
  }
  final progress = ((radius * 3.5 - distance) / (radius * 2.5)).clamp(0.0, 1.0);
  return progress * progress * (3 - 2 * progress);
}

/// Evaluates lighting at paint time, including every drag and docking frame.
/// No ticker or post-frame position measurement is needed while the puck rests.
class PuckRootLight extends SingleChildRenderObjectWidget {
  const PuckRootLight({
    super.key,
    required this.enabled,
    required this.brightness,
    this.primaryLightKey,
    this.additionalLights = const [],
    required super.child,
  });

  final bool enabled;
  final Brightness brightness;

  /// The brightest light follows this widget's actual screen-space center.
  final GlobalKey? primaryLightKey;
  final List<PuckLightAnchorHandle> additionalLights;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPuckRootLight(
    enabled,
    brightness,
    MediaQuery.sizeOf(context),
    primaryLightKey,
    additionalLights,
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPuckRootLight).configure(
      enabled,
      brightness,
      MediaQuery.sizeOf(context),
      primaryLightKey,
      additionalLights,
    );
  }
}

class _RenderPuckRootLight extends RenderProxyBox {
  _RenderPuckRootLight(
    this._enabled,
    this._brightness,
    this._screenSize,
    this._primaryLightKey,
    this._additionalLights,
  );

  bool _enabled;
  Brightness _brightness;
  Size _screenSize;
  GlobalKey? _primaryLightKey;
  List<PuckLightAnchorHandle> _additionalLights;
  TextPainter? _bubbleMaskFill;
  TextPainter? _bubbleMaskOutline;
  double? _bubbleMaskSize;

  @override
  void dispose() {
    _bubbleMaskFill?.dispose();
    _bubbleMaskOutline?.dispose();
    super.dispose();
  }

  void configure(
    bool enabled,
    Brightness brightness,
    Size screenSize,
    GlobalKey? primaryLightKey,
    List<PuckLightAnchorHandle> additionalLights,
  ) {
    if (_enabled == enabled &&
        _brightness == brightness &&
        _screenSize == screenSize &&
        _primaryLightKey == primaryLightKey &&
        _additionalLights == additionalLights) {
      return;
    }
    _enabled = enabled;
    _brightness = brightness;
    _screenSize = screenSize;
    _primaryLightKey = primaryLightKey;
    _additionalLights = additionalLights;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_enabled) {
      super.paint(context, offset);
      return;
    }
    final localCenter = size.center(Offset.zero);
    final source = _primaryLightKey?.currentContext?.findRenderObject();
    final primaryPosition =
        source is RenderBox && source.attached && source.hasSize
        ? source.localToGlobal(source.size.center(Offset.zero))
        : null;
    final sources = <PuckLightSource>[
      if (primaryPosition != null)
        PuckLightSource(primaryPosition, 1, const Color(0xFFD8EFFF)),
      for (final anchor in _additionalLights) ?anchor.source,
    ];
    final lights = samplePuckLights(
      localToGlobal(localCenter),
      _screenSize,
      sources: sources,
    );
    final primaryIndex = primaryPosition != null ? 0 : -1;
    final radius = size.shortestSide / 2;
    final primaryLocal = globalToLocal(
      primaryPosition ?? _screenSize.center(Offset.zero),
    );
    final primaryOffset = primaryLocal - localCenter;
    final interiorBlend = primaryPosition != null
        ? puckInteriorLightBlend(primaryOffset.distance, radius)
        : 0.0;
    final proximity = [
      for (final light in sources)
        puckNearLightBlend(
          (globalToLocal(light.position) - localCenter).distance,
          radius,
        ),
    ];
    final maskBounds = source is RenderBox && source.attached && source.hasSize
        ? Rect.fromPoints(
            globalToLocal(source.localToGlobal(Offset.zero)),
            globalToLocal(
              source.localToGlobal(source.size.bottomRight(Offset.zero)),
            ),
          )
        : null;
    final groundBounds = Rect.fromCircle(
      center: localCenter,
      radius: radius + 28,
    );
    final maskGround =
        maskBounds != null &&
        !maskBounds.isEmpty &&
        groundBounds.overlaps(
          maskBounds.inflate(maskBounds.shortestSide * 0.75),
        );
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (maskGround) {
      canvas.saveLayer(groundBounds, Paint());
    }
    for (final (index, light) in lights.indexed) {
      final exterior = index == primaryIndex ? 1 - interiorBlend : 1.0;
      final strength =
          light.intensity *
          exterior *
          (_brightness == Brightness.dark ? 1.0 : 0.55);
      // One glare per screen light, with no mirrored duplicate.
      _paintEmission(
        canvas,
        localCenter,
        radius,
        light.direction,
        strength,
        light.color,
        proximity: proximity[index],
      );
    }
    if (maskGround) {
      _eraseBubbleContour(canvas, maskBounds);
      canvas.restore();
    }
    canvas.restore();
    super.paint(context, offset);
    // Painting the child can switch recording canvases at its glass boundary.
    final foregroundCanvas = context.canvas;
    foregroundCanvas.save();
    foregroundCanvas.translate(offset.dx, offset.dy);
    for (final (index, light) in lights.indexed) {
      _paintGlint(
        foregroundCanvas,
        localCenter,
        radius,
        light.direction,
        light.intensity,
        light.color,
        proximity: proximity[index],
        opacity: index == primaryIndex ? 1 - interiorBlend : 1,
      );
    }
    if (primaryIndex >= 0 && interiorBlend > 0) {
      _paintInteriorRing(
        foregroundCanvas,
        localCenter,
        radius,
        primaryOffset,
        lights.first.intensity,
        interiorBlend,
      );
    }
    foregroundCanvas.restore();
  }

  void _eraseBubbleContour(Canvas canvas, Rect bounds) {
    final iconSize = bounds.shortestSide;
    if (_bubbleMaskSize != iconSize) {
      _bubbleMaskFill?.dispose();
      _bubbleMaskOutline?.dispose();
      _bubbleMaskSize = iconSize;
      TextPainter glyph(Paint foreground) => TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(Icons.bubble_chart.codePoint),
          style: TextStyle(
            inherit: false,
            fontSize: iconSize,
            fontFamily: Icons.bubble_chart.fontFamily,
            package: Icons.bubble_chart.fontPackage,
            height: 1,
            leadingDistribution: TextLeadingDistribution.even,
            foreground: foreground,
          ),
        ),
      )..layout();
      // Fill plus a broad outward stroke expands the real glyph contour.
      // Its softened edge erases each overlapping glare fragment gradually.
      final erase = Paint()
        ..color = Colors.white
        ..blendMode = BlendMode.dstOut
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, iconSize * 0.11);
      _bubbleMaskFill = glyph(erase);
      _bubbleMaskOutline = glyph(
        Paint()
          ..color = Colors.white
          ..blendMode = BlendMode.dstOut
          ..style = PaintingStyle.stroke
          ..strokeWidth = iconSize * 0.70
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, iconSize * 0.11),
      );
    }
    final position =
        bounds.center -
        Offset(_bubbleMaskFill!.width / 2, _bubbleMaskFill!.height / 2);
    _bubbleMaskFill!.paint(canvas, position);
    _bubbleMaskOutline!.paint(canvas, position);
  }

  void _paintEmission(
    Canvas canvas,
    Offset center,
    double radius,
    Offset direction,
    double strength,
    Color color, {
    double proximity = 0,
  }) {
    if (strength < 0.008) return;
    final energy = puckLightEnergy(strength, exposure: 2.2 + 0.6 * proximity);

    // The receiving surface catches a short echo of the circular rim.
    // Widen the reflected arc and bring it closer to the glass.
    final reflectionRadius = radius + math.max(4.0, radius * 0.18);
    final baseHalfSweep = math.asin(radius * 0.50 / reflectionRadius);
    final halfSweep = baseHalfSweep * (1 + 2.2 * proximity);
    final halfWidth = reflectionRadius * math.sin(halfSweep);
    final angle = math.atan2(direction.dy, direction.dx);
    final reflectionCenter = center + direction * reflectionRadius;
    final tangent = Offset(-direction.dy, direction.dx);
    final arc = Rect.fromCircle(center: center, radius: reflectionRadius);
    // Extend the surface reflection with a much fainter, wider falloff.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: reflectionRadius + 2),
      angle - halfSweep * 1.12,
      halfSweep * 2.24,
      false,
      Paint()
        ..shader = ui.Gradient.linear(
          reflectionCenter - tangent * halfWidth * 1.12,
          reflectionCenter + tangent * halfWidth * 1.12,
          [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.025 * energy),
            color.withValues(alpha: 0.06 * energy),
            color.withValues(alpha: 0.025 * energy),
            color.withValues(alpha: 0),
          ],
          [0, 0.25, 0.5, 0.75, 1],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.8),
    );
    final reflectionGradient = ui.Gradient.linear(
      reflectionCenter - tangent * halfWidth,
      reflectionCenter + tangent * halfWidth,
      [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.22 * energy),
        Colors.white.withValues(alpha: 0.58 * energy),
        color.withValues(alpha: 0.22 * energy),
        color.withValues(alpha: 0),
      ],
      [0, 0.25, 0.5, 0.75, 1],
    );
    canvas.drawArc(
      arc,
      angle - halfSweep,
      halfSweep * 2,
      false,
      Paint()
        ..shader = reflectionGradient
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.drawArc(
      arc,
      angle - halfSweep,
      halfSweep * 2,
      false,
      Paint()
        ..shader = reflectionGradient
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4),
    );
  }

  void _paintGlint(
    Canvas canvas,
    Offset center,
    double radius,
    Offset direction,
    double intensity,
    Color color, {
    double proximity = 0,
    double opacity = 1,
  }) {
    final strength = intensity * (_brightness == Brightness.dark ? 1.0 : 0.7);
    if (strength < 0.008 || opacity <= 0) {
      return;
    }
    final energy =
        puckLightEnergy(strength, exposure: 2.7 + 3 * proximity) * opacity;
    final angle = math.atan2(direction.dy, direction.dx);
    final sweep =
        (0.27 + 0.33 * math.sqrt(strength)) * 1.25 * (1 + 1.5 * proximity);
    // Broaden and deepen the near-field glare before it becomes the inner ring.
    // The outer wall keeps its three-pixel inset and inward-only fade.
    final outerRadius = math.max(0.0, radius - 3);
    if (outerRadius == 0) {
      return;
    }
    final depth = math.min(5.5 + 2 * proximity, outerRadius);
    final angularWidth = sweep / (math.pi * 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final bounds = Rect.fromCircle(center: Offset.zero, radius: outerRadius);
    canvas.saveLayer(bounds.inflate(1), Paint());
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: outerRadius - depth / 2),
      -sweep,
      sweep * 2,
      false,
      Paint()
        // Angular falloff stays smooth even when the arc exceeds half a ring.
        ..shader = ui.Gradient.sweep(
          Offset.zero,
          [
            Colors.white.withValues(alpha: energy),
            color.withValues(alpha: 0.55 * energy),
            color.withValues(alpha: 0),
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.55 * energy),
            Colors.white.withValues(alpha: energy),
          ],
          [
            0,
            angularWidth * 0.72,
            angularWidth,
            1 - angularWidth,
            1 - angularWidth * 0.72,
            1,
          ],
        )
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = depth,
    );
    _maskInward(canvas, Offset.zero, outerRadius, depth);
    canvas.restore();
    canvas.restore();
  }

  void _paintInteriorRing(
    Canvas canvas,
    Offset center,
    double radius,
    Offset lightOffset,
    double intensity,
    double blend,
  ) {
    final eccentricity = (lightOffset.distance / radius).clamp(0.0, 1.0);
    final angle = math.atan2(lightOffset.dy, lightOffset.dx);
    final gapHalf = 0.16 * eccentricity;
    final farSide = math.pow(1 - eccentricity, 3).toDouble();
    final shoulder = 1 - 0.25 * eccentricity;
    final strength = intensity * (_brightness == Brightness.dark ? 1.0 : 0.7);
    final energy = puckLightEnergy(strength, exposure: 4.2) * blend;
    final outerRadius = math.max(0.0, radius - 3 - 3 * blend);
    if (outerRadius == 0) {
      return;
    }
    final depth = math.min(7.5, outerRadius);
    // The gap stays opposite the light. As it reaches the center the gap
    // disappears, avoiding an arbitrary directional flip at zero distance.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final bounds = Rect.fromCircle(center: Offset.zero, radius: outerRadius);
    canvas.saveLayer(bounds.inflate(1), Paint());
    canvas.drawCircle(
      Offset.zero,
      outerRadius - depth / 2,
      Paint()
        ..shader = ui.Gradient.sweep(
          Offset.zero,
          [
            Colors.white.withValues(alpha: energy),
            Colors.white.withValues(alpha: shoulder * energy),
            Colors.white.withValues(alpha: farSide * energy),
            Colors.white.withValues(alpha: farSide * energy),
            Colors.white.withValues(alpha: shoulder * energy),
            Colors.white.withValues(alpha: energy),
          ],
          [
            0,
            0.40 - gapHalf,
            0.50 - gapHalf,
            0.50 + gapHalf,
            0.60 + gapHalf,
            1,
          ],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = depth,
    );
    _maskInward(canvas, Offset.zero, outerRadius, depth);
    canvas.restore();
    canvas.restore();
  }

  void _maskInward(
    Canvas canvas,
    Offset center,
    double outerRadius,
    double depth,
  ) {
    final innerStop = (outerRadius - depth) / outerRadius;
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.radial(
          center,
          outerRadius,
          const [
            Colors.transparent,
            Colors.transparent,
            Color(0x40FFFFFF),
            Colors.white,
          ],
          [0, innerStop, innerStop + (1 - innerStop) * 0.55, 1],
        ),
    );
  }
}
