import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'performance_results.dart';

const menuProfileModes = [
  'first_open',
  'repeat_open',
  'repeat_close',
  'closed_pull',
  'closed_rapid_drag',
  'closed_release',
  'open_pull',
  'open_rapid_drag',
  'open_release',
];
const _labels = [
  'First',
  'Repeat',
  'Close',
  'Pull',
  'Drag',
  'Dock',
  'Pull',
  'Drag',
  'Dock',
];
const _text = Color(0xFF98A6BB);
const _mint = Color(0xFF5ADDB0);
const _amber = Color(0xFFF0CB77);
const _red = Color(0xFFFF7187);

/// Categorical distributions, not a continuous timeline. Shared scales make
/// cards comparable; off-scale maxima are marked explicitly rather than lost.
class MenuProfileChart extends StatelessWidget {
  const MenuProfileChart({
    super.key,
    required this.profiles,
    required this.ceilingMs,
    this.onSelect,
    this.variantLabel = '',
  }) : assert(profiles.length == 9),
       assert(ceilingMs >= 16.7);
  final List<PerformanceProfile> profiles;
  final double ceilingMs;
  final ValueChanged<int>? onSelect;
  final String variantLabel;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 164,
    child: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _ProfilePainter(profiles, ceilingMs)),
          ),
          Positioned(
            left: 8,
            right: 47,
            top: 15,
            bottom: 43,
            child: Row(
              children: [
                for (var i = 0; i < profiles.length; i++)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${scenarioLabels[menuProfileModes[i]]}\n'
                          'Median ${_ms(profiles[i].workP50Ms)} · p95 ${_ms(profiles[i].workP95Ms)}\n'
                          'Peak ${_ms(profiles[i].worstWorkMs)}\n'
                          '60 FPS: ${_percent(profiles[i].budget(60).overBudgetPercent)} over\n'
                          '120 FPS: ${_percent(profiles[i].budget(120).overBudgetPercent)} over',
                      child: Semantics(
                        label:
                            '$variantLabel, ${scenarioLabels[menuProfileModes[i]]}, '
                            'p95 ${_ms(profiles[i].workP95Ms)}, peak ${_ms(profiles[i].worstWorkMs)}',
                        button: profiles[i].measurementCount > 0,
                        child: InkWell(
                          key: ValueKey('mode-${menuProfileModes[i]}'),
                          onTap: profiles[i].measurementCount == 0
                              ? null
                              : () => onSelect?.call(i),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _ms(double? value) =>
    value == null ? 'not captured' : '${value.toStringAsFixed(1)} ms';
String _percent(double? value) =>
    value == null ? 'unknown' : '${value.toStringAsFixed(1)}%';

class _ProfilePainter extends CustomPainter {
  _ProfilePainter(this.profiles, this.ceiling);
  final List<PerformanceProfile> profiles;
  final double ceiling;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(8, 15, size.width - 47, size.height - 43);
    final step = plot.width / 9;
    if (step <= 0) return;
    double y(double value) =>
        plot.bottom - (value / ceiling).clamp(0, 1) * plot.height;
    void text(
      String label,
      Offset position, {
      Color color = _text,
      double fontSize = 9,
      bool center = false,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        position - Offset(center ? painter.width / 2 : 0, 0),
      );
    }

    canvas.drawLine(
      plot.bottomLeft,
      plot.bottomRight,
      Paint()..color = const Color(0xFF303A4A),
    );
    for (final boundary in [3, 6]) {
      final x = plot.left + step * boundary;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, size.height - 7),
        Paint()..color = const Color(0xFF293345),
      );
    }
    for (final rate in [60, 120]) {
      final value = 1000 / rate;
      final color = rate == 60 ? _amber : const Color(0xFF82A8EF);
      for (var x = plot.left; x < plot.right; x += 5) {
        canvas.drawLine(
          Offset(x, y(value)),
          Offset(math.min(x + 2, plot.right), y(value)),
          Paint()..color = color.withValues(alpha: .45),
        );
      }
      text(
        '${value.toStringAsFixed(1)} ms',
        Offset(plot.right + 6, y(value) - 5),
        color: color,
        fontSize: 8,
      );
    }
    final highest = profiles.fold<double>(
      0,
      (peak, p) => math.max(peak, p.worstWorkMs ?? 0),
    );
    for (var i = 0; i < 9; i++) {
      final p = profiles[i];
      final median = p.workP50Ms;
      final p95 = p.workP95Ms;
      final peak = p.worstWorkMs;
      final x = plot.left + step * (i + .5);
      text(_labels[i], Offset(x, plot.bottom + 7), center: true, fontSize: 8.5);
      if (median == null || p95 == null || peak == null) {
        text('—', Offset(x, plot.bottom - 16), center: true);
        continue;
      }
      Color color(double ms) => ms > 1000 / 30
          ? _red
          : ms > 1000 / 60
          ? _amber
          : _mint;
      canvas.drawLine(
        Offset(x, y(median)),
        Offset(x, y(peak)),
        Paint()
          ..color = color(peak).withValues(alpha: .65)
          ..strokeWidth = 1.2,
      );
      final width = math.min(step * .4, 17.0);
      final rect = Rect.fromLTRB(
        x - width / 2,
        y(p95),
        x + width / 2,
        math.max(y(median), y(p95) + 2),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = color(p95).withValues(alpha: .65),
      );
      canvas.drawLine(
        Offset(x - width / 2, y(median)),
        Offset(x + width / 2, y(median)),
        Paint()
          ..color = color(p95)
          ..strokeWidth = 2,
      );
      if (peak > ceiling) {
        final arrow = Path()
          ..moveTo(x - 3, plot.top + 4)
          ..lineTo(x, plot.top)
          ..lineTo(x + 3, plot.top + 4);
        canvas.drawPath(
          arrow,
          Paint()
            ..color = color(peak)
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke,
        );
        if (peak == highest) {
          text(
            '↑${peak.toStringAsFixed(0)}',
            Offset(x, plot.top - 14),
            color: color(peak),
            center: true,
            fontSize: 8,
          );
        }
      } else {
        canvas.drawLine(
          Offset(x - 3, y(peak)),
          Offset(x + 3, y(peak)),
          Paint()
            ..color = color(peak)
            ..strokeWidth = 1.5,
        );
      }
    }
    for (var group = 0; group < 3; group++) {
      text(
        ['Open / close', 'Closed menu', 'Open menu'][group],
        Offset(plot.left + step * (group * 3 + 1.5), size.height - 14),
        center: true,
        fontSize: 8.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProfilePainter old) =>
      old.profiles != profiles || old.ceiling != ceiling;
}
