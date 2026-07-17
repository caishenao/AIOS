import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_steward/genui/surface/ui_node.dart';
import 'package:home_steward/genui/surface/genui_surface.dart';
import 'package:home_steward/genui/catalog/catalog_registry.dart';
import 'package:home_steward/genui/catalog/components/metric_chart.dart';

void main() {
  testWidgets('Test MetricChartComponent rendering with series', (WidgetTester tester) async {
    final registry = CatalogRegistry.instance;
    MetricChartComponent.register(registry);

    final uiNodeLine = UiNode(
      component: 'MetricChart',
      props: {
        'title': '今日温度趋势',
        'subtitle': '最高: 32°C, 最低: 22°C',
        'kind': 'line',
        'series': [
          {'label': '10:00', 'value': 24.0},
          {'label': '12:00', 'value': 28.0},
          {'label': '14:00', 'value': 32.0},
          {'label': '16:00', 'value': 30.0},
        ],
      },
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: GenUiSurface(
            root: uiNodeLine,
          ),
        ),
      ),
    ));

    // Verify title and subtitle
    expect(find.text('今日温度趋势'), findsOneWidget);
    expect(find.text('最高: 32°C, 最低: 22°C'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    
    // Pump Bar Chart
    final uiNodeBar = UiNode(
      component: 'MetricChart',
      props: {
        'title': '能耗柱状图',
        'subtitle': '总用电量: 15 kWh',
        'kind': 'bar',
        'series': [
          {'label': '客厅', 'value': 5.4},
          {'label': '主卧', 'value': 6.2},
          {'label': '厨房', 'value': 3.4},
        ],
      },
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: GenUiSurface(
            root: uiNodeBar,
          ),
        ),
      ),
    ));

    expect(find.text('能耗柱状图'), findsOneWidget);
    expect(find.text('总用电量: 15 kWh'), findsOneWidget);
    expect(find.text('客厅'), findsOneWidget);
    expect(find.text('厨房'), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });
}
