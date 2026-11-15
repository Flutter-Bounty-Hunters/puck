import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'performance_results.dart';
import 'profile_chart.dart';
import 'results_details.dart';

export 'results_details.dart' show PerformanceSampleScreen;

typedef ResultsLoader = Future<PerformanceRun?> Function();
const _background = Color(0xFF0C111B);
const _surface = Color(0xFF141D2B);
const _border = Color(0xFF263244);
const _muted = Color(0xFF96A5B9);
const _mint = Color(0xFF5ADDB0);
const _blue = Color(0xFF8DAEF2);
const _red = Color(0xFFFF7187);
const _variants = [
  'solid_single',
  'solid_three_level',
  'photos_single',
  'photos_three_level',
  'glass_single',
  'glass_three_level',
];

class PerformanceResultsScreen extends StatefulWidget {
  const PerformanceResultsScreen({
    super.key,
    this.loader = loadLatestPerformanceRun,
    this.onOpenDemo,
  });
  final ResultsLoader loader;
  final ValueChanged<String>? onOpenDemo;
  @override
  State<PerformanceResultsScreen> createState() =>
      _PerformanceResultsScreenState();
}

class _PerformanceResultsScreenState extends State<PerformanceResultsScreen> {
  PerformanceRun? _run;
  List<_SetupProfiles> _setups = [];
  bool _loading = true;
  String? _error;
  double _frameCeiling = 16.7;
  double _responseCeiling = 100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final run = await widget.loader();
      final setups = [
        for (final setup in run?.comparisonSetups ?? <PerformanceSetupGroup>[])
          _SetupProfiles(setup),
      ];
      final profiles = [
        for (final setup in setups)
          for (final card in setup.cards) ...card.profiles,
      ];
      final tallestFrame = profiles.fold(
        0.0,
        (max, p) => math.max(max, p.worstWorkMs ?? 0),
      );
      final response = setups
          .expand((s) => s.cards)
          .expand(
            (c) => [c.profiles[0].slideStartMs, c.profiles[1].slideStartMs],
          )
          .whereType<double>()
          .fold(0.0, math.max);
      if (mounted) {
        setState(() {
          _run = run;
          _setups = setups;
          _frameCeiling = math.max(16.7, tallestFrame);
          _responseCeiling = math
              .max(100, (response / 100).ceil() * 100)
              .toDouble();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _mint,
        brightness: Brightness.dark,
        surface: _surface,
      ),
      useMaterial3: true,
    ),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Menu profiles',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          actions: [
            if (widget.onOpenDemo != null)
              PopupMenuButton<String>(
                tooltip: 'Try a demo',
                icon: const Icon(Icons.bubble_chart_outlined, size: 20),
                onSelected: widget.onOpenDemo,
                itemBuilder: (_) => [
                  for (final id in _variants)
                    PopupMenuItem(value: id, child: Text(variantLabel(id))),
                ],
              ),
            IconButton(
              tooltip: 'Chart guide',
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () => _guide(context),
            ),
            IconButton(
              tooltip: 'Refresh results',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        body: Column(
          children: [
            if (_loading)
              const LinearProgressIndicator(minHeight: 2, color: _mint),
            Expanded(
              child: _error != null
                  ? _Empty(
                      title: 'Could not load results',
                      detail: _error!,
                      retry: _load,
                    )
                  : _run == null
                  ? _Empty(
                      title: _loading ? 'Reading results…' : 'No results yet',
                      detail: 'dart run tool/performance/review.dart --device <device-id>',
                      retry: _loading ? null : _load,
                    )
                  : _dashboard(context, _run!),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _dashboard(
    BuildContext context,
    PerformanceRun run,
  ) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${run.device} · ${run.started?.toLocal().toString().substring(0, 16) ?? 'Unknown date'}',
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                      Text(
                        run.mode.toUpperCase(),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (run.failedLaunches > 0 || run.status != 'complete')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _details(context),
                      child: Text(
                        [
                          if (run.status != 'complete') run.status,
                          if (run.failedLaunches > 0)
                            '${run.failedLaunches} failed launches',
                        ].join(' · '),
                        style: const TextStyle(color: _red, fontSize: 11),
                      ),
                    ),
                  ),
                for (final setup in _setups) ...[
                  if (_setups.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
                      child: Text(
                        setup.setup.label,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      Widget card(_ConfigurationProfile p) => _ProfileCard(
                        profile: p,
                        frameCeiling: _frameCeiling,
                        responseCeiling: _responseCeiling,
                        onSelect: (index) =>
                            _measurements(context, p.profiles[index]),
                      );
                      if (constraints.maxWidth < 850) {
                        return Column(
                          children: [
                            for (final p in setup.cards)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: card(p),
                              ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < setup.cards.length; i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: card(setup.cards[i])),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: i + 1 < setup.cards.length
                                        ? card(setup.cards[i + 1])
                                        : const SizedBox(),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                if (_setups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'No completed measurements.',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => _details(context),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text(
                    'Run details & logs',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  void _details(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => RunDetailsScreen(run: _run!)));
  void _guide(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: _surface,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reading a profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text(
              'Each column is an interaction. The thick band spans median to p95 frame processing time; the thin whisker reaches the worst frame. All charts share a scale that fits the largest frame time, with a minimum of 16.7 ms. Tap a column for exact values and captured frames.',
              style: TextStyle(color: _muted, height: 1.6),
            ),
            const SizedBox(height: 14),
            const Text(
              'The two horizontal guides are 60 FPS (16.67 ms) and 120 FPS (8.33 ms). Work is the slower of UI and raster, not their sum. These are work-budget checks, not measured display FPS.',
              style: TextStyle(color: _muted, height: 1.6),
            ),
            const SizedBox(height: 14),
            const Text(
              'First and repeat meters measure time from tap release to the first observed puck movement, on a separate shared scale. Missing measurements are gaps. Configurations with different test settings are kept in separate groups.',
              style: TextStyle(color: _muted, height: 1.6),
            ),
            if (_run?.mode == 'debug') ...[
              const SizedBox(height: 14),
              const Text(
                'Debug capture: compilation and assertion overhead affect these results. Confirm performance on a physical device in profile mode.',
                style: TextStyle(color: _muted, height: 1.6),
              ),
            ],
            if (_run != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _details(this.context);
                },
                child: const Text('Run details & logs'),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  void _measurements(BuildContext context, PerformanceProfile profile) {
    if (profile.samples.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _surface,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .65,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '${variantLabel(profile.samples.first.variant)} · ${profile.samples.first.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              for (final sample in profile.samples)
                ListTile(
                  title: Text(
                    'Launch ${sample.launch} · sample ${sample.repetition}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '${sample.frameCount} frames · p95 ${_ms(PerformanceProfile.fromSamples([sample]).workP95Ms)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PerformanceSampleScreen(sample: sample),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupProfiles {
  _SetupProfiles(this.setup) {
    final samples = setup.samples;
    final ids = setup.launches.map((l) => l.variant).toSet().toList()
      ..sort((a, b) => _variants.indexOf(a).compareTo(_variants.indexOf(b)));
    cards = [
      for (final id in ids)
        _ConfigurationProfile(
          id,
          [
            for (final mode in menuProfileModes)
              PerformanceProfile.fromSamples(
                samples.where((s) => s.variant == id && s.name == mode),
              ),
          ],
          setup.launches
              .where((l) => l.variant == id)
              .any((l) => l.glassFallback),
        ),
    ];
  }
  final PerformanceSetupGroup setup;
  late final List<_ConfigurationProfile> cards;
}

class _ConfigurationProfile {
  const _ConfigurationProfile(this.id, this.profiles, this.fallback);
  final String id;
  final List<PerformanceProfile> profiles;
  final bool fallback;
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.frameCeiling,
    required this.responseCeiling,
    required this.onSelect,
  });
  final _ConfigurationProfile profile;
  final double frameCeiling, responseCeiling;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('profile-${profile.id}'),
    padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${profile.id.startsWith('glass')
                    ? 'Glass'
                    : profile.id.startsWith('photos')
                    ? 'Photos'
                    : 'Solid color'} / ${profile.id.endsWith('three_level') ? '3 levels' : '1 level'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (profile.fallback)
              const Tooltip(
                message: 'Glass fallback renderer',
                child: Icon(Icons.info_outline, color: _muted, size: 15),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Avg Frame Time Across Animation',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 9),
        ),
        const SizedBox(height: 4),
        MenuProfileChart(
          profiles: profile.profiles,
          ceilingMs: frameCeiling,
          variantLabel: variantLabel(profile.id),
          onSelect: onSelect,
        ),
        const SizedBox(height: 6),
        const Text(
          'Time after tap to pucks slide start',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 9),
        ),
        const SizedBox(height: 4),
        for (final entry in [(0, 'First'), (1, 'Repeat')])
          _ResponseBar(
            value: profile.profiles[entry.$1].slideStartMs,
            label: entry.$2,
            ceiling: responseCeiling,
          ),
      ],
    ),
  );
}

class _ResponseBar extends StatelessWidget {
  const _ResponseBar({
    required this.value,
    required this.label,
    required this.ceiling,
  });
  final double? value;
  final String label;
  final double ceiling;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 9),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (value != null)
                  Container(
                    height: 4,
                    width: math.max(
                      2,
                      constraints.maxWidth * (value! / ceiling).clamp(0, 1),
                    ),
                    decoration: BoxDecoration(
                      color: value! > 250
                          ? _red
                          : label == 'Repeat'
                          ? _muted
                          : _blue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 55,
          child: Text(
            _ms(value),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: value != null && value! > 250 ? _red : _muted,
              fontSize: 10,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

String _ms(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ms';

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.detail, this.retry});
  final String title, detail;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          SelectableText(
            detail,
            style: const TextStyle(color: _muted),
            textAlign: TextAlign.center,
          ),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
