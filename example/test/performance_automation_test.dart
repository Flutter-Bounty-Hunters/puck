import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puck_example/performance/automation.dart';
import 'package:puck_example/performance/performance_demo.dart';

void main() {
  for (final variant in ['solid_single', 'solid_three_level']) {
    testWidgets('sensors follow disposal and fresh openings: $variant', (
      tester,
    ) async {
      final config = PerformanceConfig(variant: variant);
      final handles = PerformanceHandles(config);
      addTearDown(handles.dispose);
      await tester.pumpWidget(
        PerformanceDemo(config: config, handles: handles),
      );
      await tester.pumpAndSettle();
      Offset rootCenter() {
        final box =
            handles.overlay.currentContext!.findRenderObject()! as RenderBox;
        return box.globalToLocal(tester.getCenter(find.byKey(handles.root)));
      }

      final sensors = [
        for (final key in handles.items) PerformanceItemSensor(key, rootCenter),
      ];
      void checkClosed() {
        for (final sensor in sensors) {
          expect(sensor.mounted, isFalse);
          expect(sensor.widget, isNull);
          expect(sensor.center, rootCenter());
        }
      }

      checkClosed();
      for (var opening = 0; opening < 2; opening++) {
        handles.controller.open();
        await tester.pumpAndSettle();
        for (final sensor in sensors) {
          expect(sensor.mounted, isTrue);
          expect(sensor.widget!.expanded, isTrue);
          expect(
            (sensor.center - (sensor.widget!.target + const Offset(24, 24)))
                .distance,
            lessThan(.001),
          );
        }
        handles.controller.close();
        await tester.pumpAndSettle();
        checkClosed();
      }
      await tester.drag(find.byKey(handles.root), const Offset(-100, -40));
      await tester.pumpAndSettle();
      checkClosed();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
