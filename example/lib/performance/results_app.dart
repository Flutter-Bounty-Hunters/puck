import 'package:flutter/material.dart';

import 'performance_ui.dart';

class PerformanceResultsApp extends StatelessWidget {
  const PerformanceResultsApp({
    super.key,
    this.loader = loadLatestPerformanceRun,
  });

  final ResultsLoader loader;

  MaterialPageRoute<void> _resultsRoute() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/'),
    builder: (_) => PerformanceResultsView(loader: loader),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: performanceResultsTheme(),
    // The standalone launcher uses /results; it still starts one dashboard.
    onGenerateInitialRoutes: (_) => [_resultsRoute()],
    onGenerateRoute: (settings) =>
        settings.name == '/' ? _resultsRoute() : null,
  );
}
