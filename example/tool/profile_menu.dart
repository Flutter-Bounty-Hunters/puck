// ignore_for_file: avoid_print, implementation_imports
// Run with: flutter run -d <device> -t tool/profile_menu.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' show FramePhase;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:puck/src/puck_level_curves.dart';
import 'package:puck/puck.dart';

import 'package:puck_example/main.dart' as demo;

final results = <Map<String, Object?>>[];
Map<String, Object?>? active;
final frames = <FrameTiming>[];
PuckLevelCurves? curves;
RenderBox? rootBox;
Offset rootCenter = Offset.zero;
RenderBox? overlayBox;
Offset rootLocalCenter = Offset.zero;

void inspect(Element element) {
  final widget = element.widget;
  if (widget is CustomPaint && widget.painter is PuckLevelCurvePainter) {
    curves = (widget.painter! as PuckLevelCurvePainter).curves;
  }
  if (widget is PuckMenu) {
    overlayBox = element.findRenderObject() as RenderBox?;
  }
  if (widget is Icon && widget.icon == Icons.menu) {
    rootBox = element.findRenderObject() as RenderBox?;
  }
  element.visitChildren(inspect);
}

void observe(Duration _) {
  final sample = active;
  if (sample == null || curves == null) return;
  final start = sample['tapUpUs']! as int;
  final now = developer.Timeline.now;
  final items = curves!.items;
  void mark(String key) {
    if (sample.containsKey(key)) return;
    sample[key] = now - start;
    developer.Timeline.instantSync(
      'Puck.$key',
      arguments: {'trial': sample['trial']!},
    );
  }

  if (items.isNotEmpty) mark('mountedUs');
  if (items.any(
    (item) => (item.bounds.center - rootLocalCenter).distance > 0.5,
  )) {
    mark('movingUs');
  }
  if (items.any(
    (item) => (item.bounds.center - rootLocalCenter).distance > 8.5,
  )) {
    mark('visibleUs');
  }
}

Future<void> tap() async {
  final position = rootBox!.localToGlobal(rootBox!.size.center(Offset.zero));
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(position: position, pointer: 1),
  );
  await Future<void>.delayed(const Duration(milliseconds: 40));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(position: position, pointer: 1),
  );
}

Future<void> main() async {
  developer.registerExtension(
    'ext.puck.profileResults',
    (method, parameters) async => developer.ServiceExtensionResponse.result(
      jsonEncode({'results': results, 'active': active}),
    ),
  );
  demo.main();
  SchedulerBinding.instance.addTimingsCallback(frames.addAll);
  SchedulerBinding.instance.addPersistentFrameCallback((_) {
    SchedulerBinding.instance.addPostFrameCallback(observe);
  });
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Let startup and effect preloading finish before testing the first open.
    await Future<void>.delayed(
      const Duration(
        milliseconds: int.fromEnvironment(
          'PUCK_PROFILE_START_DELAY_MS',
          defaultValue: 6000,
        ),
      ),
    );
    WidgetsBinding.instance.rootElement!.visitChildren(inspect);
    rootCenter = rootBox!.localToGlobal(rootBox!.size.center(Offset.zero));
    rootLocalCenter = overlayBox!.globalToLocal(rootCenter);
    print('PUCK_PROFILE_READY ${developer.Timeline.now}');
    for (var trial = 1; trial <= 6; trial++) {
      final position = rootCenter;
      GestureBinding.instance.handlePointerEvent(
        PointerDownEvent(position: position, pointer: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final start = developer.Timeline.now;
      final sample = <String, Object?>{'trial': trial, 'tapUpUs': start};
      active = sample;
      developer.Timeline.instantSync('Puck.tapUp', arguments: {'trial': trial});
      GestureBinding.instance.handlePointerEvent(
        PointerUpEvent(position: position, pointer: 1),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      active = null;
      final trialFrames = frames
          .where(
            (frame) =>
                frame.timestampInMicroseconds(FramePhase.rasterFinish) >=
                    start &&
                frame.timestampInMicroseconds(FramePhase.vsyncStart) <
                    start + 3000000,
          )
          .toList();
      sample['frames'] = [
        for (final frame in trialFrames)
          {
            'vsyncUs': frame.timestampInMicroseconds(FramePhase.vsyncStart),
            'buildUs': frame.buildDuration.inMicroseconds,
            'rasterUs': frame.rasterDuration.inMicroseconds,
            'totalUs': frame.totalSpan.inMicroseconds,
          },
      ];
      results.add(sample);
      print('PUCK_PROFILE_TRIAL ${jsonEncode(sample)}');
      await tap();
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    print('PUCK_PROFILE_COMPLETE ${jsonEncode(results)}');
  });
}
