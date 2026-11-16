import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puck_example/runtime_performance.dart';

FrameTiming frame({int ui = 2000, int raster = 3000}) => FrameTiming(
  vsyncStart: 0,
  buildStart: 1000,
  buildFinish: 1000 + ui,
  rasterStart: 2000 + ui,
  rasterFinish: 2000 + ui + raster,
  rasterFinishWallTime: 2000 + ui + raster,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'frame readings use the display budget and separate timing from jank',
    () {
      final monitor = RuntimePerformanceMonitor(
        readMemory: () => 128 * 1024 * 1024,
      )..refreshRate = 120;
      addTearDown(monitor.dispose);
      monitor.recordFrames([
        for (var i = 0; i < 119; i++) frame(),
        frame(ui: 20000),
      ]);
      monitor.sample();
      PerformanceReading reading(String id) =>
          monitor.readings.singleWhere((r) => r.id == id);
      expect(monitor.frameBudgetMs, closeTo(8.333, 0.001));
      expect(reading('ui').value, 2);
      expect(reading('raster').value, 3);
      expect(reading('vsync').value, 1);
      expect(reading('latency').value, 7);
      expect(reading('jank').value, closeTo(100 / 120, 0.001));
      expect(reading('memory').value, 128);
      expect(reading('memory').health, 0.75);
      expect(reading('ui').health, closeTo(0.76, 0.001));
      monitor.recordFrames([for (var i = 0; i < 120; i++) frame(ui: 20000)]);
      monitor.sample();
      expect(reading('ui').health, 0);
      expect(reading('jank').value, 100);
      expect(reading('jank').health, 0);
    },
  );

  test('frame window is bounded and empty measurements stay unavailable', () {
    final monitor = RuntimePerformanceMonitor(readMemory: () => null);
    addTearDown(monitor.dispose);
    monitor.sample();
    expect(monitor.readings.first.health, isNull);
    expect(monitor.readings.first.formatted, '—');
    expect(monitor.readings.singleWhere((r) => r.id == 'memory').value, isNull);
    monitor.recordFrames([for (var i = 0; i < 80; i++) frame(ui: 50000)]);
    monitor.recordFrames([for (var i = 0; i < 120; i++) frame()]);
    monitor.sample();
    expect(monitor.frameCount, 120);
    expect(monitor.readings.first.value, 2);
    expect(monitor.readings.singleWhere((r) => r.id == 'jank').value, 0);
  });

  testWidgets(
    'sampling starts once, stops, and disposes without a live timer',
    (tester) async {
      final monitor = RuntimePerformanceMonitor(readMemory: () => 0);
      var updates = 0;
      monitor.addListener(() => updates++);
      monitor.start();
      monitor.start();
      expect(monitor.isRunning, isTrue);
      expect(updates, 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(updates, 2);
      monitor.stop();
      expect(monitor.isRunning, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(updates, 2);
      monitor.start();
      monitor.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
