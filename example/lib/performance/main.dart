import 'dart:ui' as ui;
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import 'automation.dart';
import 'performance_demo.dart';
import 'results_app.dart';

void main() {
  final mainEnteredUs = developer.Timeline.now;
  WidgetsFlutterBinding.ensureInitialized();
  final route = ui.PlatformDispatcher.instance.defaultRouteName;
  if (route == '/' || route == '/results') {
    runApp(const PerformanceResultsApp());
    return;
  }
  final config = PerformanceConfig.fromRoute(route);
  final handles = PerformanceHandles(config);
  runApp(PerformanceDemo(config: config, handles: handles));
  if (config.automated) {
    PerformanceAutomation(
      config,
      handles,
      mainEnteredUs: mainEnteredUs,
    ).start();
  }
}
