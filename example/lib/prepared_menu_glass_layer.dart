import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Menu-local idle preparation. The real menu and the rest of the app remain
/// interactive; a disposable glass-only scene never contributes screen pixels.
class PreparedMenuGlassLayer extends StatefulWidget {
  const PreparedMenuGlassLayer({
    super.key,
    required this.settings,
    required this.appearance,
    required this.itemCount,
    required this.radius,
    required this.child,
  });

  final LiquidGlassSettings settings;
  final LiquidGlassAppearance appearance;
  final int itemCount;
  final double radius;
  final Widget child;

  @override
  State<PreparedMenuGlassLayer> createState() => _PreparedMenuGlassLayerState();
}

class _PreparedMenuGlassLayerState extends State<PreparedMenuGlassLayer> {
  // Serialize GPU submissions instead of launching three readbacks together.
  static Future<void> _queue = Future<void>.value();
  static const _trace = bool.fromEnvironment('PUCK_TRACE_PREPARATION');
  final _sceneKey = GlobalKey();
  bool _listening = false;
  bool _pending =
      ui.ImageFilter.isShaderFilterSupported &&
      !const bool.fromEnvironment('PUCK_SKIP_WARMUP');

  @override
  void initState() {
    super.initState();
    if (!_pending) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _listening = true;
    if (_trace) debugPrint('Menu glass ${widget.itemCount}: queued');
    _queue = _queue.then((_) async {
      await SchedulerBinding.instance.scheduleTask<void>(() {}, Priority.idle);
      if (mounted && _pending) await _prepare();
    });
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerSignalEvent) {
      if (_pending && _trace) {
        debugPrint('Menu glass ${widget.itemCount}: cancelled for input');
      }
      _cancel();
    }
  }

  void _stopListening() {
    if (!_listening) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _listening = false;
  }

  void _cancel() {
    if (!mounted || !_pending) return;
    setState(() => _pending = false);
    _stopListening();
  }

  Future<void> _prepare() async {
    ui.Image? image;
    if (_trace) debugPrint('Menu glass ${widget.itemCount}: preparing');
    try {
      await LiquidGlass.precache();
      if (!mounted || !_pending) return;
      // Complete layout and renderer initialization. This yields to ordinary
      // app frames and input instead of putting readiness in the tap path.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_pending) return;
      final scene =
          _sceneKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (scene == null || !scene.attached) return;
      // Opacity(0) suppresses normal screen painting. Explicitly paint this
      // composited child into its own layer solely for the offscreen readback.
      PaintingContext.repaintCompositedChild(
        scene,
        debugAlsoPaintedParent: true,
      );
      image = await scene.toImage(
        pixelRatio: View.of(context).devicePixelRatio,
      );
      if (_trace) {
        debugPrint('Menu glass ${widget.itemCount}: prepared offscreen');
      }
    } catch (error) {
      debugPrint('Idle menu glass preparation skipped: $error');
    } finally {
      image?.dispose();
      _cancel();
    }
  }

  @override
  void dispose() {
    _pending = false;
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = 2 * widget.radius + 48;
      final width = math.min(constraints.maxWidth, side);
      final height = math.min(constraints.maxHeight, side);
      final radius = math.max(
        0.0,
        math.min(widget.radius, math.min(width - 48, (height - 48) / 2)),
      );
      final center = Offset(width - 24, height / 2);
      return Stack(
        fit: StackFit.expand,
        children: [
          LiquidGlassLayer(
            settings: widget.settings,
            defaultAppearance: widget.appearance,
            child: widget.child,
          ),
          if (_pending)
            Positioned(
              left: 0,
              top: 0,
              width: width,
              height: height,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: 0,
                    child: RepaintBoundary(
                      key: _sceneKey,
                      child: LiquidGlassLayer(
                        settings: widget.settings,
                        defaultAppearance: widget.appearance,
                        child: Stack(
                          children: [
                            for (var i = 0; i < widget.itemCount; i++)
                              Positioned.fromRect(
                                rect: Rect.fromCircle(
                                  center:
                                      center +
                                      Offset(
                                            math.cos(
                                              math.pi / 2 +
                                                  math.pi *
                                                      i /
                                                      math.max(
                                                        1,
                                                        widget.itemCount - 1,
                                                      ),
                                            ),
                                            math.sin(
                                              math.pi / 2 +
                                                  math.pi *
                                                      i /
                                                      math.max(
                                                        1,
                                                        widget.itemCount - 1,
                                                      ),
                                            ),
                                          ) *
                                          radius,
                                  radius: 24,
                                ),
                                child: const LiquidGlass(
                                  shape: LiquidOval(),
                                  child: SizedBox.expand(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
