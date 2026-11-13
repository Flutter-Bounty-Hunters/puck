import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:puck/puck.dart';
import 'package:puck_example/performance/frame_metrics.dart';
import 'package:puck_example/performance/performance_demo.dart';

void main() {
  test(
    'frame budget excludes pipeline queue latency and handles empty data',
    () {
      final metrics = summarizeFrames([
        {'build_us': 1000, 'raster_us': 2000, 'total_us': 70000},
        {'build_us': 20000, 'raster_us': 1000, 'total_us': 25000},
        {'build_us': 1000, 'raster_us': 40000, 'total_us': 45000},
      ], 60);
      expect(metrics['frame_count'], 3);
      expect(metrics['over_budget_frames'], 2);
      expect(metrics['ui_over_budget_frames'], 1);
      expect(metrics['raster_over_budget_frames'], 1);
      expect(metrics['estimated_missed_refresh_intervals'], 3);
      expect(summarizeFrames([], 120)['over_budget_percent'], 0);
      expect(
        summarizeFrames([
          {'build_us': 9000, 'raster_us': 1000, 'total_us': 9000},
        ], 120)['over_budget_frames'],
        1,
      );
    },
  );

  test('route configuration is explicit and rejects contaminated variants', () {
    final config = PerformanceConfig.fromRoute(
      '/photos_three_tier?automated=1&repeats=3&prepare=0&budget_fps=120',
    );
    expect(config.counts, [4, 7, 12]);
    expect(config.automated, isTrue);
    expect(config.prepareGlass, isFalse);
    expect(config.budgetFps, 120);
    expect(() => PerformanceConfig.fromRoute('/unknown'), throwsArgumentError);
    expect(
      () => PerformanceConfig.fromRoute('/solid_single?repeats=0'),
      throwsArgumentError,
    );
  });

  for (final variant in performanceVariants) {
    testWidgets('$variant has correct content, counts, and immediate opening', (
      tester,
    ) async {
      tester.platformDispatcher.defaultRouteNameTestValue =
          '/$variant?automated=1';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      final config = PerformanceConfig(variant: variant, prepareGlass: false);
      final handles = PerformanceHandles(config);
      await tester.pumpWidget(
        PerformanceDemo(config: config, handles: handles),
      );
      await tester.pumpAndSettle();
      final overlay = tester.widget<PuckOverlay>(find.byType(PuckOverlay));
      expect(overlay.menuTiers.map((tier) => tier.length), config.counts);
      expect(handles.expanded.value, isFalse);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byType(Image),
        config.photos ? findsNWidgets(config.itemCount + 1) : findsNothing,
      );
      expect(
        find.byType(LiquidGlassLayer),
        config.glass ? findsNWidgets(config.counts.length + 1) : findsNothing,
      );
      await tester.tap(find.byKey(handles.root));
      await tester.pumpAndSettle();
      expect(handles.expanded.value, isTrue);
      expect(
        tester.getCenter(find.byKey(handles.items.last)),
        isNot(tester.getCenter(find.byKey(handles.root))),
      );
      await tester.pumpWidget(const SizedBox());
      handles.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
