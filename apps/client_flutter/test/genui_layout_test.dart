import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_steward/genui/surface/ui_node.dart';
import 'package:home_steward/genui/surface/genui_surface.dart';
import 'package:home_steward/genui/catalog/catalog_registry.dart';
import 'package:home_steward/genui/catalog/components/info_card.dart';
import 'package:home_steward/genui/catalog/components/device_tile.dart';
import 'package:home_steward/genui/catalog/components/column_component.dart';
import 'package:home_steward/genui/catalog/components/row_component.dart';
import 'package:home_steward/genui/catalog/components/list_view_component.dart';
import 'package:home_steward/genui/catalog/components/media_player_component.dart';
import 'package:home_steward/genui/catalog/components/stubs.dart';

void main() {
  testWidgets('Test GenUiSurface layout with LLM JSON', (WidgetTester tester) async {
    final registry = CatalogRegistry.instance;
    InfoCardComponent.register(registry);
    DeviceTileComponent.register(registry);
    ColumnComponent.register(registry);
    RowComponent.register(registry);
    ListViewComponent.register(registry);
    MediaPlayerComponent.register(registry);
    WeatherCardComponent.register(registry);

    final jsonStr = '''
{"root":{"children":[{"children":[{"children":[{"component":"WeatherCard","props":{"condition":"晴朗","location":"北京","temp":"22°C","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"variant":"compact"}},{"component":"InfoCard","props":{"body":"所有设备运行正常 | 在线设备: 24/24","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"title":"系统状态","variant":"compact"}}],"component":"Column","props":{"theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12}}},{"children":[{"component":"DeviceTile","props":{"controllable":true,"name":"客厅主灯","state":"开启","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"type":"light","variant":"compact"}},{"component":"DeviceTile","props":{"controllable":true,"name":"空调","state":"制冷 24°C","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"type":"climate","variant":"compact"}}],"component":"Column","props":{"theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12}}},{"children":[{"component":"DeviceTile","props":{"controllable":true,"name":"卧室灯带","state":"关闭","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"type":"light","variant":"compact"}},{"component":"DeviceTile","props":{"controllable":true,"name":"智能门锁","state":"已锁定","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"type":"lock","variant":"compact"}}],"component":"Column","props":{"theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12}}}],"component":"Row","props":{"theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12}}},{"children":[{"component":"MediaPlayer","props":{"streamUrl":"https://example.com/camera/front-door","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"type":"video","variant":"thumbnail"}},{"component":"MediaPlayer","props":{"streamUrl":"https://example.com/camera/backyard","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"type":"video","variant":"thumbnail"}}],"component":"Row","props":{"theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12}}},{"children":[{"component":"DeviceTile","props":{"controllable":true,"name":"扫地机器人","state":"清扫中 - 客厅","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"type":"vacuum","variant":"compact"}},{"component":"DeviceTile","props":{"controllable":false,"name":"洗衣机","state":"待机","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"type":"washer","variant":"compact"}},{"component":"DeviceTile","props":{"controllable":true,"name":"窗帘","state":"50% 打开","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"type":"curtain","variant":"compact"}}],"component":"Row","props":{"theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12}}},{"component":"InfoCard","props":{"body":"今日用电: 12.5 kWh | 本月: 345.2 kWh | 较上月节省 8%","theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12},"title":"能耗统计","variant":"compact"}}],"component":"Column","props":{"theme":{"color.accent":"#3B82F6","color.background":"#0A0A12","color.surface":"#12121C","radius.card":12,"spacing.base":12}}},"styleSkill":"ui-style-dashboard","surfaceId":"main"}
    ''';

    final data = jsonDecode(jsonStr);
    
    // mimic _sanitizeUiNode
    Map<String, dynamic> sanitize(Map<String, dynamic> node) {
      final sanitized = Map<String, dynamic>.from(node);
      if (sanitized['props'] is Map) {
        final props = Map<String, dynamic>.from(sanitized['props']);
        if (props.containsKey('children')) {
          sanitized['children'] = props.remove('children');
          sanitized['props'] = props;
        }
      }
      if (sanitized['children'] is List) {
        sanitized['children'] = (sanitized['children'] as List).map((child) {
          if (child is Map) return sanitize(Map<String, dynamic>.from(child));
          return child;
        }).toList();
      }
      return sanitized;
    }
    
    final sanitizedRoot = sanitize(Map<String, dynamic>.from(data['root']));
    final uiNode = UiNode.fromJson(sanitizedRoot);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GenUiSurface(root: uiNode),
          ),
        ),
      ),
    ));

    // expect no exceptions
    expect(find.byType(GenUiSurface), findsOneWidget);
  });
}
