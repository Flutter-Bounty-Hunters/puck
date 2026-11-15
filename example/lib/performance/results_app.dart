import 'package:flutter/material.dart';

import 'performance_demo.dart';
import 'performance_results.dart';
import 'results_screen.dart';

class PerformanceResultsApp extends StatelessWidget {
  const PerformanceResultsApp({
    super.key,
    this.loader = loadLatestPerformanceRun,
  });
  final ResultsLoader loader;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0C111B),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5ADDB0),
        brightness: Brightness.dark,
        surface: const Color(0xFF151D2B),
      ),
      useMaterial3: true,
    ),
    onGenerateInitialRoutes: (_) => [
      MaterialPageRoute<void>(
        builder: (_) => Builder(
          builder: (context) => PerformanceResultsScreen(
            loader: loader,
            onOpenDemo: (variant) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PerformanceDemo(
                  config: PerformanceConfig(variant: variant),
                  onExit: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
    routes: {'/': (_) => PerformanceResultsScreen(loader: loader)},
  );
}
