import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck_example/performance/performance_demo.dart';
import 'package:puck_example/performance/performance_results.dart';
import 'package:puck_example/performance/results_app.dart';
import 'package:puck_example/performance/profile_chart.dart';
import 'package:puck_example/performance/results_files.dart';
import 'package:puck_example/performance/results_screen.dart';

Map<String, dynamic> fixture() => {
  'schema_version': 2,
  'status': 'complete',
  'mode': 'debug',
  'started_utc': '2026-11-12T14:00:00Z',
  'device': {'name': 'Test phone'},
  'parameters': {'budget_fps': 60},
  'cases': [
    {
      'variant': 'solid_single',
      'launch': 1,
      'flutter_log': 'A real log',
      'traces': [
        {'traceEvents': []},
      ],
      'report': {
        'success': true,
        'launch': {'fresh_process_verified': true},
        'scenarios': [
          {
            'name': 'first_open',
            'repetition': 1,
            'milestones_ms': {
              'first_item_motion': 12.0,
              'first_content_emergence': 23.0,
              'settled': 650.0,
            },
            'metrics': {
              'frame_count': 2,
              'frame_budget_ms': 16.67,
              'over_budget_percent': 50.0,
              'ui': {'p95_ms': 20.0, 'max_ms': 20.0},
              'raster': {'p95_ms': 2.0, 'max_ms': 2.0},
            },
            'frames': [
              {'build_us': 1000, 'raster_us': 2000},
              {'build_us': 20000, 'raster_us': 2000},
            ],
          },
        ],
      },
    },
    {
      'variant': 'glass_three_tier',
      'launch': 1,
      'error': 'Connection lost',
      'report': {
        'success': false,
        'native_shader_filters_supported': false,
        'scenarios': [],
      },
    },
  ],
};

void main() {
  test(
    'raw reports drive charts; failed launches and large traces stay out',
    () {
      final data = fixture();
      data['summary'] = {
        'samples': [
          {'response_ms': 999999},
        ],
      };
      final run = parsePerformanceRun(jsonEncode(data));
      expect(run.samples.single.response, 23);
      expect(run.profile().slideStartMs, 12);
      expect(run.samples.single.frames, hasLength(2));
      expect(run.failedLaunches, 1);
      expect(run.launches.last.glassFallback, isTrue);
      expect(run.launches.first.data['traces'], isNull);
      expect(run.launches.first.data['trace_count'], 1);
      expect(run.data['summary'], isNull);
      expect(medianValue([1, 2, 4, 5]), 3);
      expect(medianValue([]), isNull);
      expect(
        () => parsePerformanceRun('{"schema_version":1}'),
        throwsFormatException,
      );
    },
  );

  test(
    'latest uses measurement date, not copy date; ignores legacy folders',
    () async {
      final directory = await Directory.systemTemp.createTemp('puck-results-');
      addTearDown(() => directory.delete(recursive: true));
      expect(await latestPerformanceFile(directory), isNull);
      await Directory('${directory.path}/old-run').create();
      final recent = File('${directory.path}/recent.json');
      await recent.writeAsString(
        jsonEncode({...fixture(), 'started_utc': '2026-11-12T14:00:00Z'}),
      );
      await File('${directory.path}/copied-old.json').writeAsString(
        jsonEncode({...fixture(), 'started_utc': '20250101T000000000000Z'}),
      );
      await File('${directory.path}/unrelated.json')
          .writeAsString('{"hello":true}');
      await File('${directory.path}/pending.json.tmp')
          .writeAsString(jsonEncode(fixture()));
      expect((await latestPerformanceFile(directory))?.path, recent.path);
      await File('${directory.path}/focused-profiler.json').writeAsString(
        jsonEncode({
          ...fixture(),
          'started_utc': '2028-01-01T00:00:00Z',
          'parameters': {'profile_opening': true},
        }),
      );
      expect((await latestPerformanceFile(directory))?.path, recent.path);
      // Do not hide a damaged newest run by showing an older result instead.
      final broken = File('${directory.path}/broken.json');
      await broken.writeAsString(
        '{"schema_version":2,"started_utc":"2027-01-01T00:00:00Z",',
      );
      expect((await latestPerformanceFile(directory))?.path, broken.path);
    },
  );

  testWidgets('empty results refresh into a responsive dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceResultsScreen(
          loader: () async => ++loads == 1 ? null : PerformanceRun(fixture()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No results yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh results'));
    await tester.pumpAndSettle();
    expect(find.text('Menu profiles'), findsOneWidget);
    expect(find.text('Solid color / 1 tier'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('A real log'), findsNothing);
    final chart = tester.widget<MenuProfileChart>(
      find.byType(MenuProfileChart),
    );
    expect(chart.profiles.length, 9);
    expect(chart.profiles[0].workP95Ms, 20);
    expect(chart.profiles[1].measurementCount, 0);
    expect(chart.ceilingMs, 20);
    expect(find.text('12.0 ms'), findsOneWidget);
    expect(find.text('Time after tap to pucks slide start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profiles compare the same raw frames with both budgets', (
    tester,
  ) async {
    final data = fixture();
    data['cases'][0]['report']['scenarios'][0]['frames'][1]['build_us'] = 9000;
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceResultsScreen(
          loader: () async => PerformanceRun(data),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chart = tester.widget<MenuProfileChart>(
      find.byType(MenuProfileChart),
    );
    expect(chart.profiles.first.budget(60).overBudgetPercent, 0);
    expect(chart.profiles.first.budget(120).overBudgetPercent, 50);
    expect(chart.ceilingMs, 16.7);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Tooltip &&
            w.message!.contains('60 FPS: 0.0% over\n120 FPS: 50.0% over'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all modes share one profile and remain individually inspectable',
    (tester) async {
      final data = jsonDecode(jsonEncode(fixture())) as Map<String, dynamic>;
      final original = data['cases'][0]['report']['scenarios'][0];
      data['cases'][0]['report']['scenarios'] = [
        for (final mode in menuProfileModes)
          {
            ...jsonDecode(jsonEncode(original)) as Map<String, dynamic>,
            'name': mode,
          },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceResultsScreen(
            loader: () async => PerformanceRun(data),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<MenuProfileChart>(
        find.byType(MenuProfileChart),
      );
      expect(chart.profiles.every((p) => p.measurementCount == 1), isTrue);
      await tester.tap(find.byKey(const ValueKey('mode-repeat_open')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Launch 1 · sample 1'));
      await tester.pumpAndSettle();
      expect(find.text('Repeated opening'), findsOneWidget);
      expect(find.text('Frame work · milliseconds'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'configuration charts keep the same axes despite different costs',
    (tester) async {
      final data = jsonDecode(jsonEncode(fixture())) as Map<String, dynamic>;
      final other = jsonDecode(jsonEncode(data['cases'][0]));
      other['variant'] = 'glass_single';
      // A rare spike must determine the shared scale even when p95 is low.
      other['report']['scenarios'][0]['frames'] = [
        for (var i = 0; i < 99; i++) {'build_us': 2000, 'raster_us': 1000},
        {'build_us': 157145, 'raster_us': 1000},
      ];
      other['report']['scenarios'][0]['metrics']['frame_count'] = 100;
      data['cases'].add(other);
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceResultsScreen(
            loader: () async => PerformanceRun(data),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final charts = tester
          .widgetList<MenuProfileChart>(find.byType(MenuProfileChart))
          .toList();
      expect(charts.length, 2);
      expect(charts.map((chart) => chart.ceilingMs).toSet(), {157.145});
      expect(charts[0].profiles.first.workP95Ms, 20);
      expect(charts[1].profiles.first.workP95Ms, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed loads can retry, and sample timelines are reachable', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceResultsScreen(
          loader: () async {
            if (++loads == 1) throw const FormatException('Broken result');
            return PerformanceRun(fixture());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load results'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    final details = find.text('Run details & logs');
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();
    final launch = find.text('Solid · 1 tier · launch 1');
    await tester.ensureVisible(launch);
    await tester.pumpAndSettle();
    await tester.tap(launch);
    await tester.pumpAndSettle();
    final sample = find.text('First opening · 1');
    await tester.ensureVisible(sample);
    await tester.pumpAndSettle();
    await tester.tap(sample);
    await tester.pumpAndSettle();
    expect(find.text('Frame work · milliseconds'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('23.00 ms'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review app can open a demo and return to results', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/results';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(
      PerformanceResultsApp(loader: () async => PerformanceRun(fixture())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Try a demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solid · 1 tier').last);
    await tester.pumpAndSettle();
    expect(find.byType(PerformanceDemo), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(PerformanceDemo), findsNothing);
    expect(find.text('Menu profiles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
