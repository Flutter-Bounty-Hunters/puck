import 'package:flutter_test/flutter_test.dart';
import 'package:puck_example/performance/performance_results.dart';

PerformanceSample sample(
  List<(int, int)> frames, {
  double response = 10,
  double settled = 500,
}) => PerformanceSample(
  {
    'name': 'first_open',
    'milestones_ms': {'first_content_emergence': response, 'settled': settled},
    'metrics': {
      'frame_count': frames.length,
      'frame_budget_ms': 1000 / 60,
      'ui': {'p95_ms': 999.0, 'max_ms': 999.0},
      'raster': {'p95_ms': 999.0, 'max_ms': 999.0},
    },
    'frames': [
      for (final frame in frames) {'build_us': frame.$1, 'raster_us': frame.$2},
    ],
  },
  'solid_single',
  1,
);

void main() {
  test('pool raw frames and compare each budget independently', () {
    final profile = PerformanceProfile.fromSamples([
      sample([(4000, 2000), (2000, 9000)]),
      sample(
        [(12000, 3000), (17000, 1000), (1000, 35000)],
        response: 30,
        settled: 700,
      ),
    ]);
    expect(profile.frameCount, 5);
    expect(profile.rawFrameCount, 5);
    expect(profile.measurementCount, 2);
    expect(profile.responseMs, 20);
    expect(profile.settledMs, 600);
    expect(profile.uiP95Ms, 17);
    expect(profile.rasterP95Ms, 35);
    expect(profile.workP95Ms, 35);
    expect(profile.workP50Ms, 12);
    expect(profile.worstWorkMs, 35);
    expect(profile.hasCompleteRawFrames, isTrue);
    expect(profile.budget(60).overBudgetFrames, 2);
    expect(profile.budget(60).overBudgetPercent, 40);
    expect(profile.budget(120).overBudgetFrames, 4);
    expect(profile.budget(120).withinBudgetPercent, 20);
    // UI and raster overlap: this is 9ms of limiting work, not 11ms.
    expect(profile.frames[1].workMs, 9);
  });

  test('saved 60Hz counts do not invent a 120Hz rate or work percentile', () {
    final saved = PerformanceSample(
      {
        'name': 'first_open',
        'metrics': {
          'frame_count': 100,
          'frame_budget_ms': 1000 / 60,
          'over_budget_frames': 25,
          'ui': {'p95_ms': 6.0, 'max_ms': 20.0},
          'raster': {'p95_ms': 7.0, 'max_ms': 30.0},
        },
      },
      'solid_single',
      1,
    );
    final profile = PerformanceProfile.fromSamples([saved]);
    expect(profile.responseMs, isNull);
    expect(profile.workP95Ms, isNull);
    expect(profile.uiP95Ms, 6);
    expect(profile.worstWorkMs, 30);
    expect(profile.usesAggregateFallback, isTrue);
    expect(profile.budget(60).overBudgetPercent, 25);
    expect(profile.budget(120).overBudgetPercent, isNull);
    expect(profile.budget(120).unknownFrameCount, 100);
  });

  test('partial or missing raw captures cannot appear as an exact rate', () {
    final partial = sample([(4000, 1000), (20000, 1000)]);
    partial.data['metrics']['frame_count'] = 3;
    final profile = PerformanceProfile.fromSamples([partial]);
    expect(profile.hasCompleteRawFrames, isFalse);
    expect(profile.budget(60).overBudgetPercent, isNull);
    expect(profile.budget(60).coveredFrameCount, 2);
    expect(profile.budget(60).unknownFrameCount, 1);
    final missing = PerformanceSample(
      {'metrics': <String, dynamic>{}},
      'solid_single',
      1,
    );
    expect(
      PerformanceProfile.fromSamples([
        sample([(1000, 1000)]),
        missing,
      ]).budget(60).overBudgetPercent,
      isNull,
    );
    expect(
      PerformanceProfile.fromSamples([]).budget(60).overBudgetPercent,
      isNull,
    );
  });

  test(
    'comparison groups isolate setup changes but allow material and tiers',
    () {
      Map<String, dynamic> launch(String variant, {bool curves = false}) => {
        'variant': variant,
        'launch': 1,
        'report': {
          'success': true,
          'mode': 'profile',
          'viewport': {'width': 400, 'height': 800},
          'display_refresh_rate_hz': 120,
          'config': {
            'curves': curves,
            'tier_counts': variant.endsWith('single') ? [4] : [4, 7, 12],
          },
          'scenarios': [
            sample([(1000, 1000)]).data,
          ],
        },
      };
      final run = PerformanceRun({
        'schema_version': 2,
        'device': {'name': 'Phone'},
        'cases': [
          launch('solid_single'),
          launch('glass_three_tier'),
          launch('photos_single', curves: true),
          {...launch('solid_single'), 'error': 'failed'},
        ],
      });
      expect(run.comparableSetup, isFalse);
      expect(run.comparisonSetups, hasLength(2));
      expect(run.comparisonSetups.first.launches, hasLength(2));
      expect(run.comparisonSetups.first.samples, hasLength(2));
      expect(run.profile().measurementCount, 3);
      expect(
        run
            .profile(variant: 'solid_single', scenario: 'first_open')
            .measurementCount,
        1,
      );
      final legacy = launch('glass_three_tier');
      (legacy['report']['config'] as Map)['maintain_menu_state'] = true;
      final current = launch('glass_three_tier');
      (current['report']['config'] as Map)['closed_item_policy'] = 'dispose';
      final independent = launch('glass_three_tier');
      (independent['report']['config'] as Map).addAll(<String, Object>{
        'closed_item_policy': 'dispose',
        'glass_layer_policy': 'individual_pucks',
      });
      final history = PerformanceRun({
        'schema_version': 2,
        'device': {'name': 'Phone'},
        'cases': [legacy, current, independent],
      });
      expect(history.comparisonSetups, hasLength(3));
      expect(
        history.comparisonSetups.map(
          (s) => s.configuration['closed_item_policy'],
        ),
        ['legacy_mounted', 'dispose', 'dispose'],
      );
    },
  );
}
