import 'package:flutter/material.dart';

import 'performance_demo.dart';
import 'performance_results.dart';
import 'results_screen.dart';
import 'results_theme.dart';

export 'performance_results.dart'
    show
        PerformanceRun,
        loadLatestPerformanceRun,
        loadBundledPerformanceRun,
        performanceResultsAsset;
export 'results_screen.dart' show PerformanceResultsScreen, ResultsLoader;
export 'results_theme.dart' show performanceResultsTheme;

/// Shared results UI, including its theme, drill-down routes, and demo launcher.
/// Embed directly in a tab or use as the home of the standalone results app.
class PerformanceResultsView extends StatefulWidget {
  const PerformanceResultsView({
    super.key,
    this.loader = loadLatestPerformanceRun,
    this.active = true,
  });

  final ResultsLoader loader;
  final bool active;

  @override
  State<PerformanceResultsView> createState() => _PerformanceResultsViewState();
}

class _PerformanceResultsViewState extends State<PerformanceResultsView> {
  final _navigator = GlobalKey<NavigatorState>();
  final _heroes = HeroController();

  @override
  Widget build(BuildContext context) => Theme(
    data: performanceResultsTheme(),
    child: NavigatorPopHandler<Object?>(
      enabled: widget.active,
      onPopWithResult: (result) => _navigator.currentState!.pop(result),
      child: HeroControllerScope(
        controller: _heroes,
        child: Navigator(
          key: _navigator,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => PerformanceResultsScreen(
              loader: widget.loader,
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
      ),
    ),
  );
}
