import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'performance_results.dart';

const _uiColor = Color(0xFF7A9DFF);
const _rasterColor = Color(0xFF55D9C0);
const _sixtyColor = Color(0xFFFFBD69);
const _oneTwentyColor = Color(0xFFB6A4FF);

String _ms(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(2)} ms';
String _percent(double? value) =>
    value == null ? 'Unknown' : '${value.toStringAsFixed(1)}%';

class RunDetailsScreen extends StatelessWidget {
  const RunDetailsScreen({super.key, required this.run});
  final PerformanceRun run;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Run details')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  run.device,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${run.mode} · ${run.started?.toLocal().toString().split('.').first ?? 'Unknown time'} · ${run.status}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Card(
                  child: ExpansionTile(
                    title: const Text('Test setup'),
                    subtitle: const Text(
                      'Device, rendering policy, and run configuration',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(
                            const JsonEncoder.withIndent('  ').convert({
                              'device': run.data['device'],
                              'mode': run.mode,
                              'parameters': run.data['parameters'],
                            }),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Launches', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text(
                  'Select a measurement for its frame timeline. Logs and process information stay within each launch.',
                ),
                const SizedBox(height: 12),
                for (final launch in run.launches)
                  _LaunchDetails(launch: launch),
                if (run.launches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No launches have been saved yet.'),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LaunchDetails extends StatelessWidget {
  const _LaunchDetails({required this.launch});
  final PerformanceLaunch launch;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      initiallyExpanded: !launch.success,
      title: Text('${variantLabel(launch.variant)} · launch ${launch.launch}'),
      subtitle: Text(
        launch.success
            ? '${launch.samples.length} measurement${launch.samples.length == 1 ? '' : 's'}'
            : 'Failed or incomplete',
      ),
      leading: Icon(
        launch.success ? Icons.check_circle_outline : Icons.error_outline,
        color: launch.success
            ? _rasterColor
            : Theme.of(context).colorScheme.error,
      ),
      children: [
        if (launch.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              launch.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final sample in launch.samples)
          ListTile(
            title: Text('${sample.label} · ${sample.repetition}'),
            subtitle: Text(
              '${sample.frameCount} frames · UI p95 ${_ms(sample.uiP95)} · raster p95 ${_ms(sample.rasterP95)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PerformanceSampleScreen(sample: sample),
              ),
            ),
          ),
        ExpansionTile(
          title: const Text('Launch details & log'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  [
                    'Process: ${launch.data['process']?['pid'] ?? 'unavailable'}',
                    'Fresh process verified: ${launch.data['report']?['launch']?['fresh_process_verified'] ?? false}',
                    'Glass preparation: ${launch.data['report']?['config']?['prepare_glass'] ?? 'unknown'}',
                    'Display refresh rate: ${launch.data['report']?['display_refresh_rate_hz'] ?? 'unknown'} Hz',
                    'Native glass supported: ${launch.data['report']?['native_shader_filters_supported'] ?? 'unknown'}',
                    'Embedded trace chunks: ${launch.data['trace_count'] ?? 0}',
                    '',
                    launch.data['flutter_log'] as String? ?? 'No log captured.',
                  ].join('\n'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class PerformanceSampleScreen extends StatelessWidget {
  const PerformanceSampleScreen({super.key, required this.sample});
  final PerformanceSample sample;

  @override
  Widget build(BuildContext context) {
    final profile = PerformanceProfile.fromSamples([sample]);
    return Scaffold(
      appBar: AppBar(
        title: Text(sample.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    variantLabel(sample.variant),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Launch ${sample.launch} · repetition ${sample.repetition} · ${sample.frameCount} frames',
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final fps in [60, 120])
                          SizedBox(
                            width: constraints.maxWidth >= 440
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth,
                            child: _BudgetDetail(profile: profile.budget(fps)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Frame work · milliseconds',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The slower of UI and raster work determines the frame-work budget. These are work-budget checks, not measured display FPS.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (sample.frames.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No raw frame timeline was captured. A second refresh-rate budget cannot be inferred from a single saved percentage.',
                        ),
                      ),
                    )
                  else
                    _FrameTimeline(frames: sample.frames),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Metric(label: 'UI p95', value: _ms(profile.uiP95Ms)),
                      _Metric(
                        label: 'Raster p95',
                        value: _ms(profile.rasterP95Ms),
                      ),
                      _Metric(
                        label: 'Worst frame work',
                        value: _ms(profile.worstWorkMs),
                      ),
                      _Metric(
                        label: _responseLabel(sample),
                        value: _ms(sample.response),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Milestones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Times start at pointer-up, or at the start of commanded movement. Animation duration and time to first response are different measurements.',
                  ),
                  const SizedBox(height: 12),
                  for (final entry
                      in (sample.data['milestones_ms'] as Map? ?? {}).entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_milestoneLabel(entry.key.toString())),
                      trailing: Text(
                        _ms(number(entry.value)),
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  Card(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        sample.name.endsWith('release')
                            ? 'Observed settling includes 140 ms of stable positions and a minimum 1.2 s release-observation window. That window is intentional; it is not 1.2 s of rendering delay.'
                            : 'Observed settling includes 140 ms of stable positions. It includes the intended spring animation and should not be graded as input latency.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _responseLabel(PerformanceSample sample) => switch (sample.name) {
  'first_open' || 'repeat_open' => 'First visible item',
  'repeat_close' => 'Fully covered',
  _ => 'First root motion',
};

String _milestoneLabel(String name) => switch (name) {
  'first_item_motion' => 'First item motion',
  'first_item_emergence' => 'First item emergence',
  'first_content_emergence' => 'First visible content',
  'first_root_motion' => 'First root motion',
  'fully_covered' => 'Fully covered',
  'first_wall_contact' => 'First wall contact',
  'settled' => 'Observed settling',
  'pull_complete' => 'Pull complete',
  _ => name.replaceAll('_', ' '),
};

class _BudgetDetail extends StatelessWidget {
  const _BudgetDetail({required this.profile});
  final FrameBudgetProfile profile;
  @override
  Widget build(BuildContext context) {
    final hasMisses = profile.overBudgetFrames > 0;
    final color = profile.overBudgetPercent == null
        ? Theme.of(context).colorScheme.outline
        : hasMisses
        ? _sixtyColor
        : _rasterColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${profile.fps} FPS budget',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              '${_percent(profile.overBudgetPercent)} over',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${profile.overBudgetFrames} / ${profile.coveredFrameCount} known frames exceeded ${profile.budgetMs.toStringAsFixed(2)} ms',
            ),
            if (profile.unknownFrameCount > 0)
              Text(
                '${profile.unknownFrameCount} frames could not be evaluated.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FrameTimeline extends StatefulWidget {
  const _FrameTimeline({required this.frames});
  final List<Map<String, dynamic>> frames;
  @override
  State<_FrameTimeline> createState() => _FrameTimelineState();
}

class _FrameTimelineState extends State<_FrameTimeline> {
  int? selected;
  @override
  Widget build(BuildContext context) {
    final frame = selected == null ? null : widget.frames[selected!];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: const [
                _Legend(color: _uiColor, text: 'UI'),
                _Legend(color: _rasterColor, text: 'Raster'),
                _Legend(color: _sixtyColor, text: '60 FPS · 16.67 ms'),
                _Legend(color: _oneTwentyColor, text: '120 FPS · 8.33 ms'),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) => Semantics(
                label:
                    'UI and raster work for ${widget.frames.length} frames. Budget guides at 8.33 and 16.67 milliseconds. Tap to inspect a frame.',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => setState(() {
                    selected =
                        (((details.localPosition.dx - 40) /
                                    math.max(1, constraints.maxWidth - 48)) *
                                (widget.frames.length - 1))
                            .round()
                            .clamp(0, widget.frames.length - 1);
                  }),
                  child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _FramePainter(
                        widget.frames,
                        Theme.of(context).colorScheme.onSurface,
                        selected,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              frame == null
                  ? 'Frames in render order · tap a point to inspect'
                  : 'Frame ${selected! + 1} · UI ${_ms((number(frame['build_us']) ?? 0) / 1000)} · raster ${_ms((number(frame['raster_us']) ?? 0) / 1000)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.frames, this.labelColor, this.selected);
  final List<Map<String, dynamic>> frames;
  final Color labelColor;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final peak = frames.fold(
      1000 / 60 * 1.18,
      (max, f) => math.max(
        max,
        math.max(number(f['build_us']) ?? 0, number(f['raster_us']) ?? 0) /
            1000 *
            1.05,
      ),
    );
    final plot = Rect.fromLTRB(40, 8, size.width - 8, size.height - 22);
    if (plot.width <= 0 || frames.isEmpty) return;
    double y(double value) => plot.bottom - value / peak * plot.height;
    final axis = Paint()
      ..color = labelColor.withValues(alpha: .18)
      ..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
    for (final guide in [
      (1000 / 60, _sixtyColor),
      (1000 / 120, _oneTwentyColor),
    ]) {
      final paint = Paint()
        ..color = guide.$2.withValues(alpha: .75)
        ..strokeWidth = 1;
      for (var x = plot.left; x < plot.right; x += 7) {
        canvas.drawLine(
          Offset(x, y(guide.$1)),
          Offset(math.min(x + 4, plot.right), y(guide.$1)),
          paint,
        );
      }
    }
    for (final label in [0.0, peak / 2, peak]) {
      final text = TextPainter(
        text: TextSpan(
          text: label.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 10,
            color: labelColor.withValues(alpha: .65),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(0, y(label) - 6));
    }
    if (selected != null) {
      final x =
          plot.left +
          (frames.length == 1 ? .5 : selected! / (frames.length - 1)) *
              plot.width;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = labelColor.withValues(alpha: .3)
          ..strokeWidth = 1,
      );
    }
    for (final series in [
      ('build_us', _uiColor),
      ('raster_us', _rasterColor),
    ]) {
      final path = Path();
      final fill = Path()..moveTo(plot.left, plot.bottom);
      for (var i = 0; i < frames.length; i++) {
        final point = Offset(
          plot.left +
              (frames.length == 1 ? .5 : i / (frames.length - 1)) * plot.width,
          y((number(frames[i][series.$1]) ?? 0) / 1000),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
        fill.lineTo(point.dx, point.dy);
        if (frames.length <= 120 || i == selected) {
          canvas.drawCircle(
            point,
            i == selected ? 3.5 : 1.6,
            Paint()..color = series.$2,
          );
        }
      }
      fill.lineTo(plot.right, plot.bottom);
      fill.close();
      canvas.drawPath(fill, Paint()..color = series.$2.withValues(alpha: .08));
      canvas.drawPath(
        path,
        Paint()
          ..color = series.$2
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.frames != frames ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.selected != selected;
}
