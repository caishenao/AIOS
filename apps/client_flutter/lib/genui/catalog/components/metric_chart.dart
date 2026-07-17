import 'dart:math';
import 'package:flutter/material.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

class ChartDataPoint {
  final String label;
  final double value;
  final Color? color;

  ChartDataPoint({required this.label, required this.value, this.color});
}

class MetricChartComponent extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String kind; // 'line' or 'bar'
  final List<ChartDataPoint> series;
  final ThemeTokens theme;

  const MetricChartComponent({
    super.key,
    required this.title,
    this.subtitle,
    required this.kind,
    required this.series,
    required this.theme,
  });

  static void register(CatalogRegistry registry) {
    registry.register('MetricChart', ({
      required props,
      required children,
      bindings,
      events,
      theme,
      required context,
      onEvent,
    }) {
      final rawSeries = props['series'] as List<dynamic>? ?? [];
      final dataPoints = rawSeries.map((item) {
        if (item is Map) {
          final label = (item['label'] ?? '').toString();
          final value = (item['value'] as num?)?.toDouble() ?? 0.0;
          final colorStr = item['color'] as String?;
          Color? color;
          if (colorStr != null) {
            try {
              color = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
            } catch (_) {}
          }
          return ChartDataPoint(label: label, value: value, color: color);
        } else if (item is num) {
          return ChartDataPoint(label: '', value: item.toDouble());
        }
        return ChartDataPoint(label: '', value: 0.0);
      }).toList();

      return MetricChartComponent(
        title: props['title'] as String? ?? '指标趋势',
        subtitle: props['subtitle'] as String?,
        kind: props['kind'] as String? ?? 'line',
        series: dataPoints,
        theme: theme ?? ThemeTokens.minimal,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (series.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(t.baseSpacing),
        decoration: BoxDecoration(
          color: t.surface.withAlpha(220),
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.accent.withAlpha(30)),
        ),
        child: const Center(child: Text('暂无图表数据', style: TextStyle(color: Colors.grey))),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(t.baseSpacing),
      decoration: BoxDecoration(
        color: t.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.accent.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: t.accent.withAlpha(10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: t.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14 * t.fontScale,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: t.onSurface.withAlpha(120),
                          fontSize: 11 * t.fontScale,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                kind == 'bar' ? Icons.bar_chart : Icons.show_chart,
                color: t.accent,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart Canvas
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: kind == 'bar'
                  ? BarChartPainter(series: series, accentColor: t.accent, onSurface: t.onSurface)
                  : LineChartPainter(series: series, accentColor: t.accent, onSurface: t.onSurface),
            ),
          ),
          // X-Axis Labels Row
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: series.map((pt) {
              return Expanded(
                child: Text(
                  pt.label,
                  style: TextStyle(
                    color: t.onSurface.withAlpha(100),
                    fontSize: 9 * t.fontScale,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<ChartDataPoint> series;
  final Color accentColor;
  final Color onSurface;

  LineChartPainter({
    required this.series,
    required this.accentColor,
    required this.onSurface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = series.map((pt) => pt.value).toList();
    double maxValue = values.reduce(max);
    double minValue = values.reduce(min);
    
    // Add margin to scale range
    if (maxValue == minValue) {
      maxValue += 1.0;
      minValue -= 1.0;
    } else {
      final range = maxValue - minValue;
      maxValue += range * 0.15;
      minValue = max(0, minValue - range * 0.15);
    }
    final range = maxValue - minValue;

    // Draw Grid Lines (horizontal)
    final gridPaint = Paint()
      ..color = onSurface.withAlpha(15)
      ..strokeWidth = 1.0;

    final numGridLines = 3;
    for (int i = 0; i <= numGridLines; i++) {
      final y = size.height * i / numGridLines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Determine coordinates for points
    final widthStep = size.width / (series.length > 1 ? series.length - 1 : 1);
    final List<Offset> points = [];
    for (int i = 0; i < series.length; i++) {
      final x = i * widthStep;
      final ratio = (series[i].value - minValue) / range;
      final y = size.height - (ratio * size.height);
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    // 1. Draw Neon Under-Fill Gradient Area
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final pt in points) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withAlpha(45),
          accentColor.withAlpha(0),
        ],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(fillPath, fillPaint);

    // 2. Draw Smooth Bezier Neon Line
    final linePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2.0, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2.0, p2.dy);
      linePath.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p2.dx, p2.dy,
      );
    }
    
    // Draw glowing aura/shadow
    final glowPaint = Paint()
      ..color = accentColor.withAlpha(80)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawPath(linePath, glowPaint);
    canvas.drawPath(linePath, linePaint);

    // 3. Draw Data Points (circles)
    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    final dotOuterPaint = Paint()
      ..color = onSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final pt in points) {
      canvas.drawCircle(pt, 5.0, dotPaint);
      canvas.drawCircle(pt, 5.0, dotOuterPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BarChartPainter extends CustomPainter {
  final List<ChartDataPoint> series;
  final Color accentColor;
  final Color onSurface;

  BarChartPainter({
    required this.series,
    required this.accentColor,
    required this.onSurface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = series.map((pt) => pt.value).toList();
    double maxValue = values.reduce(max);
    if (maxValue <= 0) maxValue = 1.0;
    
    // Grid
    final gridPaint = Paint()
      ..color = onSurface.withAlpha(15)
      ..strokeWidth = 1.0;

    final numGridLines = 3;
    for (int i = 0; i <= numGridLines; i++) {
      final y = size.height * i / numGridLines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final barCount = series.length;
    final spacingRatio = 0.35;
    final totalSpacingRatio = spacingRatio * (barCount + 1);
    final totalBarWidthRatio = 1.0 - totalSpacingRatio;
    final singleBarWidth = (size.width * totalBarWidthRatio) / barCount;
    final spacingWidth = (size.width * spacingRatio);

    for (int i = 0; i < barCount; i++) {
      final pt = series[i];
      final ratio = pt.value / maxValue;
      final barHeight = ratio * size.height;
      
      final left = (i * (singleBarWidth + spacingWidth / barCount)) + (spacingWidth / (barCount + 1));
      final top = size.height - barHeight;
      final right = left + singleBarWidth;
      final bottom = size.height;

      final barColor = pt.color ?? accentColor;

      final rect = Rect.fromLTRB(left, top, right, bottom);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barColor,
            barColor.withAlpha(100),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        rrect,
        Paint()
          ..color = barColor.withAlpha(60)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      canvas.drawRRect(rrect, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
