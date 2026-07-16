import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../surface/ui_node.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

/// Displays data visualization using CustomPainter — no external chart lib.
///
/// Props:
/// - `series` (List<Map>): Data points, each with `label` (String) and `value` (num).
/// - `kind` (String): Chart type — `"bar"` or `"line"`.
/// - `title` (String?): Optional chart title.
/// - `unit` (String?): Value unit label (e.g. `"kWh"`, `"%"`).
/// - `height` (num?): Chart height in logical pixels, default 200.
class CatalogMetricChart extends StatelessWidget {
  final Map<String, dynamic> props;
  final List<UiNode> children;
  final ThemeTokens? theme;
  final Map<String, String>? events;
  final EventCallback? onEvent;

  const CatalogMetricChart({
    super.key,
    required this.props,
    this.children = const [],
    this.theme,
    this.events,
    this.onEvent,
  });

  /// Registers this component in the [CatalogRegistry].
  static void register(CatalogRegistry registry) {
    registry.register('MetricChart', ({
      required Map<String, dynamic> props,
      required List<UiNode> children,
      Map<String, dynamic>? bindings,
      Map<String, String>? events,
      ThemeTokens? theme,
      required BuildContext context,
      EventCallback? onEvent,
    }) {
      return CatalogMetricChart(
        props: props,
        children: children,
        theme: theme,
        events: events,
        onEvent: onEvent,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ThemeTokens.minimal;
    final title = props['title'] as String?;
    final unit = props['unit'] as String? ?? '';
    final kind = props['kind'] as String? ?? 'bar';
    final chartHeight = (props['height'] as num?)?.toDouble() ?? 200.0;
    final rawSeries =
        (props['series'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];

    final series = rawSeries
        .map((e) => _DataPoint(
              label: e['label']?.toString() ?? '',
              value: (e['value'] as num?)?.toDouble() ?? 0,
            ))
        .toList();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: t.baseSpacing / 2),
      padding: EdgeInsets.all(t.baseSpacing),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: TextStyle(
                color: t.onSurface,
                fontSize: 16 * t.fontScale,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: t.baseSpacing),
          ],
          if (series.isEmpty)
            SizedBox(
              height: chartHeight,
              child: Center(
                child: Text(
                  'No data',
                  style: TextStyle(
                    color: t.onSurface.withAlpha(80),
                    fontSize: 14 * t.fontScale,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: chartHeight,
              child: CustomPaint(
                size: Size(double.infinity, chartHeight),
                painter: kind == 'line'
                    ? _LineChartPainter(
                        series: series, theme: t, unit: unit)
                    : _BarChartPainter(
                        series: series, theme: t, unit: unit),
              ),
            ),
          // X-axis labels
          if (series.isNotEmpty) ...[
            SizedBox(height: t.baseSpacing / 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: series
                  .map((dp) => Flexible(
                        child: Text(
                          dp.label,
                          style: TextStyle(
                            color: t.onSurface.withAlpha(100),
                            fontSize: 10 * t.fontScale,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DataPoint {
  final String label;
  final double value;
  const _DataPoint({required this.label, required this.value});
}

/// Custom painter for bar charts.
class _BarChartPainter extends CustomPainter {
  final List<_DataPoint> series;
  final ThemeTokens theme;
  final String unit;

  _BarChartPainter({
    required this.series,
    required this.theme,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    final maxVal = series.map((s) => s.value).reduce(math.max);
    final normalizedMax = maxVal == 0 ? 1.0 : maxVal;
    final barWidth = (size.width / series.length) * 0.6;
    final gap = (size.width / series.length) * 0.4;

    final paint = Paint()
      ..color = theme.accent
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = theme.onSurface.withAlpha(15)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < series.length; i++) {
      final x = i * (barWidth + gap) + gap / 2;
      final barHeight = (series[i].value / normalizedMax) * (size.height - 20);

      // Background bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, barWidth, size.height - 20),
          const Radius.circular(6),
        ),
        bgPaint,
      );

      // Value bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              x, size.height - 20 - barHeight, barWidth, barHeight),
          const Radius.circular(6),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom painter for line charts.
class _LineChartPainter extends CustomPainter {
  final List<_DataPoint> series;
  final ThemeTokens theme;
  final String unit;

  _LineChartPainter({
    required this.series,
    required this.theme,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;

    final maxVal = series.map((s) => s.value).reduce(math.max);
    final minVal = series.map((s) => s.value).reduce(math.min);
    final range = maxVal - minVal;
    final normalizedRange = range == 0 ? 1.0 : range;
    final chartHeight = size.height - 20;

    final linePaint = Paint()
      ..color = theme.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = theme.accent
      ..style = PaintingStyle.fill;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          theme.accent.withAlpha(60),
          theme.accent.withAlpha(5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (series.length - 1);

    for (int i = 0; i < series.length; i++) {
      final x = i * stepX;
      final y = chartHeight -
          ((series[i].value - minVal) / normalizedRange) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw dots
    for (int i = 0; i < series.length; i++) {
      final x = i * stepX;
      final y = chartHeight -
          ((series[i].value - minVal) / normalizedRange) * chartHeight;
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(
        Offset(x, y),
        2,
        Paint()..color = theme.surface,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
