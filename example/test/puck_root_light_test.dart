import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck_example/puck_root_light.dart';

List<PuckLightSource> fixtureLights(Size size) => [
  PuckLightSource(size.center(Offset.zero), 1, Colors.white),
  PuckLightSource(Offset(size.width, size.height * 0.30), 0.45, Colors.white),
  PuckLightSource(
    Offset(size.width * 0.12, size.height * 1.08),
    0.72,
    Colors.white,
  ),
];

void main() {
  setUpAll(() async {
    final fonts = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await fonts.load();
  });
  test('fixed screen lights change direction and fade with distance', () {
    const screen = Size(400, 800);
    final near = samplePuckLights(
      const Offset(200, 340),
      screen,
      sources: fixtureLights(screen),
    );
    final far = samplePuckLights(
      const Offset(360, 720),
      screen,
      sources: fixtureLights(screen),
    );
    expect(near.first.intensity, greaterThan(far.first.intensity));
    expect(near.last.intensity, lessThan(far.last.intensity));
    expect(near.first.direction, isNot(far.first.direction));
    for (final sample in [...near, ...far]) {
      expect(sample.direction.distance, closeTo(1, 0.00001));
      expect(sample.intensity, inInclusiveRange(0, 1));
    }
    final scaled = samplePuckLights(
      const Offset(400, 680),
      const Size(800, 1600),
      sources: fixtureLights(const Size(800, 1600)),
    );
    for (var index = 0; index < near.length; index++) {
      expect(
        (scaled[index].direction - near[index].direction).distance,
        lessThan(0.00001),
      );
      expect(scaled[index].intensity, closeTo(near[index].intensity, 0.00001));
    }
  });

  test(
    'the primary light uses the bubble position rather than screen center',
    () {
      const bubble = Offset(200, 450);
      const root = Offset(350, 250);
      final light = samplePuckLights(
        root,
        const Size(400, 800),
        sources: const [PuckLightSource(bubble, 1, Colors.white)],
      ).first;
      final towardBubble = bubble - root;
      expect(
        (light.direction - towardBubble / towardBubble.distance).distance,
        lessThan(0.00001),
      );
      final atBubble = samplePuckLights(
        bubble,
        const Size(400, 800),
        sources: const [PuckLightSource(bubble, 1, Colors.white)],
      ).first;
      expect(atBubble.intensity, 1);
      expect(atBubble.intensity, greaterThan(light.intensity));
    },
  );

  test('there are no unanchored fallback lights', () {
    expect(
      samplePuckLights(const Offset(200, 400), const Size(400, 800)),
      isEmpty,
    );
    expect(PuckLightAnchorHandle(intensity: 1).source, isNull);
  });

  test('interior ring blends in continuously as the light crosses the rim', () {
    expect(puckInteriorLightBlend(40, 32), 0);
    expect(puckInteriorLightBlend(0, 32), 1);
    expect(puckInteriorLightBlend(20, 32), 1);
    expect(puckInteriorLightBlend(32, 32), inExclusiveRange(0, 1));
    expect(
      puckInteriorLightBlend(28, 32),
      greaterThan(puckInteriorLightBlend(32, 32)),
    );
    expect(
      (puckInteriorLightBlend(32.01, 32) - puckInteriorLightBlend(31.99, 32))
          .abs(),
      lessThan(0.01),
    );
    expect(puckInteriorLightBlend(0, 0), 0);
  });

  testWidgets(
    'covered bubble lights most of the inner ring and shifts its bright side',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      final lightPosition = ValueNotifier(const Offset(200, 400));
      addTearDown(lightPosition.dispose);
      final lightKey = GlobalKey();
      final sceneKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: sceneKey,
            child: ColoredBox(
              color: Colors.black,
              child: ValueListenableBuilder<Offset>(
                valueListenable: lightPosition,
                child: PuckRootLight(
                  enabled: true,
                  brightness: Brightness.dark,
                  primaryLightKey: lightKey,
                  child: const ClipOval(
                    child: RepaintBoundary(
                      child: ColoredBox(color: Color(0xFF303036)),
                    ),
                  ),
                ),
                builder: (context, light, child) => Stack(
                  children: [
                    Positioned(
                      left: light.dx - 12,
                      top: light.dy - 12,
                      width: 24,
                      height: 24,
                      child: SizedBox(key: lightKey),
                    ),
                    Positioned(
                      left: 168,
                      top: 368,
                      width: 64,
                      height: 64,
                      child: child!,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<ByteData> pixels() async => (await tester.runAsync(() async {
        final boundary =
            sceneKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        } finally {
          image.dispose();
        }
      }))!;
      int red(ByteData image, int x, int y) =>
          image.getUint8((y * 400 + x) * 4);
      final centered = await pixels();
      var brightSectors = 0;
      for (var i = 0; i < 16; i++) {
        final angle = i * math.pi / 8;
        if (red(
              centered,
              (200 + 24 * math.cos(angle)).round(),
              (400 + 24 * math.sin(angle)).round(),
            ) >
            100) {
          brightSectors++;
        }
      }
      expect(brightSectors, greaterThanOrEqualTo(14));
      lightPosition.value = const Offset(212, 400);
      await tester.pumpAndSettle();
      final right = await pixels();
      expect(red(right, 224, 400), greaterThan(red(right, 176, 400) + 30));
      lightPosition.value = const Offset(188, 400);
      await tester.pumpAndSettle();
      final left = await pixels();
      expect(red(left, 176, 400), greaterThan(red(left, 224, 400) + 30));
      // Approaching along the same direction broadens the glare before overlap.
      lightPosition.value = const Offset(380, 400);
      await tester.pumpAndSettle();
      final far = await pixels();
      lightPosition.value = const Offset(250, 400);
      await tester.pumpAndSettle();
      final near = await pixels();
      expect(red(near, 214, 423), greaterThan(red(far, 214, 423) + 50));
      expect(red(near, 226, 400), greaterThan(red(far, 226, 400) + 15));
      expect(red(near, 227, 427), greaterThan(red(far, 227, 427) + 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bubble contour removes only overlapping fragments of ground glare',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      final sourceKey = GlobalKey();
      final sceneKey = GlobalKey();
      var iconSize = 0.0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: sceneKey,
            child: ColoredBox(
              color: Colors.black,
              child: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return Stack(
                    children: [
                      Positioned(
                        left: 260 - iconSize / 2,
                        top: 400 - iconSize / 2,
                        width: iconSize,
                        height: iconSize,
                        child: SizedBox(key: sourceKey),
                      ),
                      Positioned(
                        left: 168,
                        top: 368,
                        width: 64,
                        height: 64,
                        child: PuckRootLight(
                          enabled: true,
                          brightness: Brightness.dark,
                          primaryLightKey: sourceKey,
                          child: const ClipOval(
                            child: RepaintBoundary(
                              child: ColoredBox(color: Color(0xFF303036)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<ByteData> pixels() async => (await tester.runAsync(() async {
        final boundary =
            sceneKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        } finally {
          image.dispose();
        }
      }))!;
      final original = await pixels();
      rebuild(() => iconSize = 36);
      await tester.pumpAndSettle();
      final masked = await pixels();
      var erased = 0;
      var retained = 0;
      for (var y = 375; y <= 425; y++) {
        for (var x = 232; x <= 255; x++) {
          if ((Offset(x.toDouble(), y.toDouble()) - const Offset(200, 400))
                  .distance <
              34) {
            continue;
          }
          final index = (y * 400 + x) * 4;
          final before = original.getUint8(index);
          final after = masked.getUint8(index);
          if (before > after + 10) {
            erased++;
          }
          if (after > 15 && (before - after).abs() <= 2) {
            retained++;
          }
        }
      }
      expect(erased, greaterThan(5));
      expect(retained, greaterThan(5));
      // The ground-only mask cannot erase the glass or the page behind it.
      for (final point in [const Offset(224, 400), const Offset(150, 350)]) {
        final index = (point.dy.toInt() * 400 + point.dx.toInt()) * 4;
        expect(masked.getUint8(index), original.getUint8(index));
      }
      expect(tester.takeException(), isNull);
    },
  );

  test('near-field glare builds before the bubble crosses the rim', () {
    expect(puckNearLightBlend(120, 32), 0);
    expect(puckNearLightBlend(32, 32), 1);
    expect(puckNearLightBlend(48, 32), greaterThan(0.8));
    expect(puckNearLightBlend(48, 32), greaterThan(puckNearLightBlend(80, 32)));
    expect(puckInteriorLightBlend(48, 32), 0);
    expect(puckNearLightBlend(0, 0), 0);
  });

  test('nearby lights keep getting brighter instead of hitting a plateau', () {
    for (final exposure in [2.2, 2.7]) {
      final levels = [
        for (final intensity in [0.1, 0.4, 0.6, 0.8, 1.0])
          puckLightEnergy(intensity, exposure: exposure),
      ];
      expect(puckLightEnergy(0, exposure: exposure), 0);
      for (var i = 1; i < levels.length; i++) {
        expect(levels[i] - levels[i - 1], greaterThan(0.02));
      }
      expect(levels.last, lessThan(1));
    }
  });

  test('a puck coincident with a source has finite lighting', () {
    const screen = Size(400, 800);
    final source = fixtureLights(screen).first;
    final sample = samplePuckLights(
      source.position,
      screen,
      sources: [source],
    ).first;
    expect(sample.intensity, source.intensity);
    expect(sample.direction.distance, 1);
    expect(samplePuckLights(Offset.zero, Size.zero), isEmpty);
  });

  testWidgets(
    'moving the same root repaints its local lighting from screen position',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(500, 800);
      addTearDown(tester.view.reset);
      final position = ValueNotifier(const Offset(350, 180));
      addTearDown(position.dispose);
      final sceneKey = GlobalKey();
      final lightKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: sceneKey,
            child: ColoredBox(
              color: Colors.black,
              child: ValueListenableBuilder<Offset>(
                valueListenable: position,
                child: PuckRootLight(
                  primaryLightKey: lightKey,
                  enabled: true,
                  brightness: Brightness.dark,
                  // A child paint boundary must not interrupt the foreground glints.
                  child: const RepaintBoundary(
                    child: ColoredBox(color: Color(0xFF303036)),
                  ),
                ),
                builder: (context, offset, child) => Stack(
                  children: [
                    Positioned(
                      left: 238,
                      top: 388,
                      width: 24,
                      height: 24,
                      child: SizedBox(key: lightKey),
                    ),
                    Positioned(
                      left: offset.dx,
                      top: offset.dy,
                      width: 64,
                      height: 64,
                      child: child!,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final root = find.byType(PuckRootLight);
      final state = tester.renderObject(root);
      Future<List<int>> pixelsAroundRoot() async {
        final center = tester.getCenter(root);
        return (await tester.runAsync(() async {
          final boundary =
              sceneKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            return [
              for (
                var y = center.dy.round() - 80;
                y < center.dy.round() + 80;
                y++
              )
                for (
                  var x = center.dx.round() - 80;
                  x < center.dx.round() + 80;
                  x++
                )
                  data.getUint8((y * image.width + x) * 4),
            ];
          } finally {
            image.dispose();
          }
        }))!;
      }

      final before = await pixelsAroundRoot();
      position.value = const Offset(100, 500);
      await tester.pumpAndSettle();
      expect(tester.renderObject(root), same(state));
      final after = await pixelsAroundRoot();
      final difference = List.generate(
        before.length,
        (i) => (before[i] - after[i]).abs(),
      ).fold<int>(0, (sum, value) => sum + value);
      expect(difference, greaterThan(1000));
      expect(tester.takeException(), isNull);
    },
  );
}
