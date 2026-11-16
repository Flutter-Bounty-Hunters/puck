import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:puck/puck.dart';

import 'runtime_performance.dart';
import 'menu_root_puck.dart';

const performancePuckColor = Color(0xFF181B24);

class PerformanceMonitorMenu extends StatefulWidget {
  const PerformanceMonitorMenu({
    super.key,
    required this.visible,
    required this.active,
    required this.showDebugAnchors,
    this.controller,
  });

  final bool visible;
  final bool active;
  final bool showDebugAnchors;
  final PuckMenuController? controller;

  @override
  State<PerformanceMonitorMenu> createState() => _PerformanceMonitorMenuState();
}

class _PerformanceMonitorMenuState extends State<PerformanceMonitorMenu>
    with WidgetsBindingObserver {
  final _monitor = RuntimePerformanceMonitor();
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _monitor.refreshRate = View.of(context).display.refreshRate;
    _syncSampling();
  }

  @override
  void didUpdateWidget(PerformanceMonitorMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSampling();
  }

  @override
  void didChangeMetrics() {
    _monitor.refreshRate = View.of(context).display.refreshRate;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncSampling();
  }

  void _syncSampling() {
    if (widget.visible && widget.active && _foreground) {
      _monitor.start();
    } else {
      _monitor.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PuckMenu.singleLevel(
    key: const ValueKey('performance-menu'),
    controller: widget.controller,
    id: 'demo-performance-right-column-v2',
    visible: widget.visible,
    layout: const PuckMenuLayout(
      initialEdge: PuckEdge.right,
      initialVerticalAlignment: 0.70,
      levelRadius: 180,
      puckDiameter: 68,
    ),
    debug: PuckMenuDebug(showAnchors: widget.showDebugAnchors),
    rootPuck: const MenuRootPuck(
      key: ValueKey('performance-root'),
      child: Material(
        color: performancePuckColor,
        shape: CircleBorder(),
        child: Tooltip(
          message: kDebugMode
              ? 'Performance monitor · debug timings include development overhead'
              : 'Performance monitor',
          child: Icon(Icons.speed_rounded, color: Colors.white, size: 30),
        ),
      ),
    ),
    puckItems: [
      for (final id in [
        'ui',
        'raster',
        'latency',
        'vsync',
        'jank',
        'memory',
        'images',
      ])
        _PerformanceMeterPuck(
          key: ValueKey('performance-$id'),
          id: id,
          monitor: _monitor,
        ),
    ],
  );
}

class _PerformanceMeterPuck extends StatelessWidget {
  const _PerformanceMeterPuck({
    super.key,
    required this.id,
    required this.monitor,
  });

  final String id;
  final RuntimePerformanceMonitor monitor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: monitor,
    builder: (context, _) {
      final reading = monitor.readings.where((r) => r.id == id).firstOrNull;
      final health = reading?.health;
      final color = health == null
          ? const Color(0xFF94A3B8)
          : health >= 0.5
          ? const Color(0xFF4ADE80)
          : health >= 0.2
          ? const Color(0xFFFBBF24)
          : const Color(0xFFFB7185);
      final label = reading?.label ?? id;
      final value = reading?.formatted ?? '—';
      return Semantics(
        label: '${reading?.name ?? label}: $value',
        value: health == null
            ? 'Not available yet'
            : '${(health * 100).round()}% headroom',
        child: Tooltip(
          message:
              '${reading?.name ?? label}: $value\n'
              '${reading?.detail ?? 'Waiting for measurements.'}',
          child: Material(
            color: performancePuckColor,
            shape: const CircleBorder(),
            child: CustomPaint(
              key: const ValueKey('performance-meter'),
              painter: _HealthMeterPainter(health: health, color: color),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _HealthMeterPainter extends CustomPainter {
  const _HealthMeterPainter({required this.health, required this.color});

  final double? health;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = health == null
          ? const Color(0xFF343A46)
          : color.withValues(alpha: 0.18);
    canvas.drawArc(bounds, -math.pi / 2, math.pi * 2, false, paint);
    if (health != null && health! > 0) {
      canvas.drawArc(
        bounds,
        -math.pi / 2,
        math.pi * 2 * health!,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_HealthMeterPainter oldDelegate) =>
      health != oldDelegate.health || color != oldDelegate.color;
}
