import 'dart:ui' as ui;
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:puck/puck.dart';

import '../prepared_menu_glass_layer.dart';

const performanceVariants = [
  'solid_single',
  'solid_three_tier',
  'photos_single',
  'photos_three_tier',
  'glass_single',
  'glass_three_tier',
];
const performanceRootDiameter = 64.0;
const performanceItemDiameter = 48.0;
const performanceMenuRadius = 80.0;
const performancePhotos = [
  'assets/performance/as11-44-6550.jpg',
  'assets/performance/as17-148-22727.jpg',
  'assets/performance/PIA07782.jpg',
  'assets/performance/as11-44-6584.jpg',
  'assets/performance/as11-44-6581.jpg',
  'assets/performance/as11-44-6626.jpg',
  'assets/performance/as11-44-6665.jpg',
  'assets/performance/as11-44-6634.jpg',
  'assets/performance/as11-44-6551.jpg',
  'assets/performance/as11-44-6549.jpg',
  'assets/performance/as11-44-6548.jpg',
  'assets/performance/as11-44-6667.jpg',
  'assets/performance/as11-44-6642.jpg',
  'assets/performance/as11-44-6552.jpg',
  'assets/performance/as11-44-6689.jpg',
  'assets/performance/as11-44-6609.jpg',
  'assets/performance/as11-44-6553.jpg',
  'assets/performance/as11-40-5915.jpg',
  'assets/performance/as11-40-5881.jpg',
  'assets/performance/as11-40-5880.jpg',
  'assets/performance/as11-40-5863.jpg',
  'assets/performance/as11-40-5877.jpg',
  'assets/performance/as11-40-5873.jpg',
  'assets/performance/as11-40-5964.jpg',
];

class PerformanceConfig {
  const PerformanceConfig({
    required this.variant,
    this.repeats = 5,
    this.startDelayMs = 250,
    this.budgetFps = 60,
    this.prepareGlass = true,
    this.curves = false,
    this.automated = false,
    this.openingProfile = false,
  });

  final String variant;
  final int repeats;
  final int startDelayMs;
  final double budgetFps;
  final bool prepareGlass;
  final bool curves;
  final bool automated;
  final bool openingProfile;
  bool get threeTier => variant.endsWith('three_tier');
  bool get glass => variant.startsWith('glass_');
  bool get photos => variant.startsWith('photos_');
  List<int> get counts => threeTier ? const [4, 7, 12] : const [4];
  int get itemCount => counts.fold(0, (sum, count) => sum + count);

  factory PerformanceConfig.fromRoute(String route) {
    final uri = Uri.parse(route);
    final variant = uri.path.replaceFirst(RegExp(r'^/'), '');
    if (!performanceVariants.contains(variant)) {
      throw ArgumentError('Unknown performance variant: $variant');
    }
    final query = uri.queryParameters;
    final config = PerformanceConfig(
      variant: variant,
      automated: query['automated'] == '1',
      openingProfile: query['opening_profile'] == '1',
      repeats: int.parse(query['repeats'] ?? '5'),
      startDelayMs: int.parse(query['start_delay_ms'] ?? '250'),
      budgetFps: double.parse(query['budget_fps'] ?? '60'),
      prepareGlass: query['prepare'] != '0',
      curves: query['curves'] == '1',
    );
    if (config.repeats < 1 ||
        config.startDelayMs < 0 ||
        !config.budgetFps.isFinite ||
        config.budgetFps <= 0) {
      throw ArgumentError('Invalid benchmark parameters');
    }
    return config;
  }

  Map<String, Object> toJson() => {
    'variant': variant,
    'opening_profile': openingProfile,
    'tier_counts': counts,
    'item_count': itemCount,
    'repeats': repeats,
    'start_delay_ms': startDelayMs,
    'frame_budget_fps': budgetFps,
    'prepare_glass': prepareGlass,
    'curves': curves,
    'maintain_menu_state': true,
    'photo_cache_policy':
        'Bundled assets; no explicit precache; 192px decode cache',
  };
}

class PerformanceHandles {
  PerformanceHandles(PerformanceConfig config)
    : items = List.generate(
        config.itemCount,
        (i) => GlobalKey(debugLabel: 'performance-item-$i'),
      );
  final root = GlobalKey(debugLabel: 'performance-root');
  final overlay = GlobalKey(debugLabel: 'performance-overlay');
  final List<GlobalKey> items;
  final expanded = ValueNotifier(false);
  final photoReadyUs = <String, int>{};
  void dispose() => expanded.dispose();
}

void runPerformanceDemo(String variant) {
  final config = PerformanceConfig(variant: variant);
  runApp(PerformanceDemo(config: config));
}

class PerformanceDemo extends StatefulWidget {
  const PerformanceDemo({
    super.key,
    required this.config,
    this.handles,
    this.onExit,
  });
  final PerformanceConfig config;
  final PerformanceHandles? handles;
  final VoidCallback? onExit;
  @override
  State<PerformanceDemo> createState() => _PerformanceDemoState();
}

class _PerformanceDemoState extends State<PerformanceDemo> {
  late final _handles = widget.handles ?? PerformanceHandles(widget.config);

  @override
  void dispose() {
    if (widget.handles == null) _handles.dispose();
    super.dispose();
  }

  Widget _content(int index, {bool root = false}) {
    final config = widget.config;
    final icon = Icon(
      root
          ? Icons.menu
          : const [
              Icons.home,
              Icons.search,
              Icons.favorite,
              Icons.explore,
              Icons.bookmark,
              Icons.share,
            ][index % 6],
      color: Colors.white,
    );
    Widget content;
    if (config.glass) {
      content = root
          ? LiquidGlass.withOwnLayer(
              settings: _settings,
              appearance: _appearance,
              shape: const LiquidOval(),
              child: icon,
            )
          : LiquidGlass(shape: const LiquidOval(), child: icon);
    } else if (config.photos) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            performancePhotos[root ? performancePhotos.length - 1 : index],
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, synchronous) {
              if (frame != null) {
                _handles.photoReadyUs.putIfAbsent(
                  root ? 'root' : 'item-$index',
                  () => developer.Timeline.now,
                );
              }
              return child;
            },
            cacheWidth: 192,
            cacheHeight: 192,
            errorBuilder: (context, error, stack) =>
                throw StateError('Photo asset failed: $error'),
          ),
          if (root) icon,
        ],
      );
    } else {
      content = ColoredBox(
        color: Colors.primaries[index % Colors.primaries.length],
        child: icon,
      );
    }
    return SizedBox(
      key: root ? _handles.root : _handles.items[index],
      child: content,
    );
  }

  final _settings = LiquidGlassSettings.ios27Regular(
    brightness: Brightness.light,
    tintAmount: 0.7,
  );
  final _appearance = LiquidGlassAppearance.ios27Regular(
    brightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) {
    var index = 0;
    final tiers = [
      for (final count in widget.config.counts)
        [for (var i = 0; i < count; i++) _content(index++)],
    ];
    final page = Scaffold(
      appBar: AppBar(
        title: Text(widget.config.variant),
        leading: widget.onExit == null
            ? null
            : BackButton(onPressed: widget.onExit),
      ),
      body: const CustomPaint(
        painter: _BenchmarkBackground(),
        child: SizedBox.expand(),
      ),
    );
    return MaterialApp(
      // Flutter may prioritize the native defaultRouteName over initialRoute.
      // Treat that string exclusively as benchmark configuration and create
      // exactly one visual route, including on a real device launch.
      routes: {'/': (_) => page},
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: (_) => page,
        ),
      ],
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      builder: (context, child) => Overlay.wrap(
        child: Stack(
          fit: StackFit.expand,
          children: [
            child!,
            SafeArea(
              child: PuckOverlay(
                key: _handles.overlay,
                diameter: performanceRootDiameter,
                menuItemDiameter: performanceItemDiameter,
                menuRadius: performanceMenuRadius,
                maintainMenuState: true,
                menuExpanded: _handles.expanded,
                showTierCurves: widget.config.curves,
                menuTierBuilder: widget.config.glass
                    ? (context, tier, child) => widget.config.prepareGlass
                          ? PreparedMenuGlassLayer(
                              settings: _settings,
                              appearance: _appearance,
                              itemCount: widget.config.counts[tier],
                              radius: 80.0 + 80 * tier + 4 * tier * (tier + 1),
                              child: child,
                            )
                          : LiquidGlassLayer(
                              settings: _settings,
                              defaultAppearance: _appearance,
                              child: child,
                            )
                    : null,
                menuTiers: tiers,
                puck: _content(0, root: true),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenchmarkBackground extends CustomPainter {
  const _BenchmarkBackground();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1F5F9),
    );
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide * .3,
      Paint()..color = const Color(0x66818CF8),
    );
    final text = TextPainter(
      text: const TextSpan(
        text: 'Puck performance\nDrag, release, open, close',
        style: TextStyle(color: Color(0xFF334155), fontSize: 18),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width);
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, (size.height - text.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BenchmarkBackground oldDelegate) => false;
}
