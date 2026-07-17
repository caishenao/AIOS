import 'package:flutter/material.dart';
import '../surface/ui_node.dart';
import 'theme_tokens.dart';

import 'components/info_card.dart';
import 'components/device_tile.dart';
import 'components/column_component.dart';
import 'components/row_component.dart';
import 'components/list_view_component.dart';
import 'components/media_player.dart';
import 'components/email_dashboard.dart';
import 'components/map_navigation.dart';
import 'components/product_card.dart';
import 'components/stubs.dart';

typedef EventCallback = void Function(String action, Map<String, dynamic> payload);

typedef CatalogComponentBuilder = Widget Function({
  required Map<String, dynamic> props,
  required List<UiNode> children,
  Map<String, dynamic>? bindings,
  Map<String, String>? events,
  ThemeTokens? theme,
  required BuildContext context,
  EventCallback? onEvent,
});

class CatalogRegistry {
  static final CatalogRegistry instance = CatalogRegistry._();
  CatalogRegistry._();
  
  final Map<String, CatalogComponentBuilder> _builders = {};
  
  void register(String name, CatalogComponentBuilder builder) {
    _builders[name] = builder;
  }
  
  Widget build(UiNode node, BuildContext context, {ThemeTokens? theme, EventCallback? onEvent}) {
    final builder = _builders[node.component];
    if (builder == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: Colors.red.withAlpha(50),
        child: Text('Unknown component: ${node.component}', style: const TextStyle(color: Colors.red)),
      );
    }
    
    ThemeTokens? nodeTheme = theme;
    if (node.props.containsKey('theme')) {
      final parsedTheme = ThemeTokens.fromJson(node.props['theme'] as Map<String, dynamic>?);
      nodeTheme = theme?.merge(parsedTheme) ?? parsedTheme;
    }
    
    try {
      return builder(
        props: node.props,
        children: node.children,
        bindings: node.bindings,
        events: node.events,
        theme: nodeTheme,
        context: context,
        onEvent: onEvent,
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(50),
          border: Border.all(color: Colors.red.withAlpha(100)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Render Error [${node.component}]:\n$e', 
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      );
    }
  }
  
  bool has(String name) => _builders.containsKey(name);
  
  List<String> get componentNames => _builders.keys.toList();
  
  void registerAll() {
    InfoCardComponent.register(this);
    DeviceTileComponent.register(this);
    ColumnComponent.register(this);
    RowComponent.register(this);
    ListViewComponent.register(this);
    CatalogMediaPlayer.register(this);
    EmailDashboardComponent.register(this);
    MapNavigationComponent.register(this);
    ProductCardComponent.register(this);
    
    // Stubs
    WeatherCardComponent.register(this);
    MetricChartComponent.register(this);
    SectionComponent.register(this);
    ConfirmDialogComponent.register(this);
    TextInputComponent.register(this);
    SliderComponent.register(this);
    ToggleComponent.register(this);
  }
}
