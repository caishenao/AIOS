import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfw/rfw.dart';
import 'package:rfw/formats.dart';
import '../surface/ui_node.dart';
import '../catalog/theme_tokens.dart';
import '../catalog/catalog_registry.dart';
import '../../config/capability_registry.dart';

abstract class RenderBackend {
  Widget render(UiNode root, BuildContext context, {ThemeTokens? theme, EventCallback? onEvent});
  List<String> get supportedComponents;
}

class JsonRenderBackend implements RenderBackend {
  final CatalogRegistry _registry;

  JsonRenderBackend(this._registry);

  @override
  Widget render(UiNode root, BuildContext context, {ThemeTokens? theme, EventCallback? onEvent}) {
    return _registry.build(root, context, theme: theme, onEvent: onEvent);
  }

  @override
  List<String> get supportedComponents => _registry.componentNames;
}

class RfwRenderBackend implements RenderBackend {
  final Runtime _runtime = Runtime();
  final Set<String> _registeredLibraryIds = {};

  RfwRenderBackend(List<A2AAgentEntry> agents) {
    _runtime.update(const LibraryName(['core']), createCoreWidgets());
    _runtime.update(const LibraryName(['material']), createMaterialWidgets());

    // Register each daemon's RFW widgets
    for (final agent in agents) {
      final widgets = agent.rfwWidgets;
      if (widgets != null && widgets.isNotEmpty) {
        try {
          final library = parseLibraryFile(widgets);
          final libraryName = LibraryName(['daemon_${agent.id}']);
          _runtime.update(libraryName, library);
          _registeredLibraryIds.add(agent.id);
        } catch (e) {
          debugPrint('Failed to parse RFW library for agent ${agent.name}: $e');
        }
      }
    }
  }

  @override
  Widget render(UiNode root, BuildContext context, {ThemeTokens? theme, EventCallback? onEvent}) {
    return _buildWidget(root, context, onEvent);
  }

  Widget _buildWidget(UiNode node, BuildContext context, EventCallback? onEvent) {
    // 1. Check if the component name specifies a custom remote library
    // Format could be: "daemon_123.DaemonSensorCard"
    String? targetLibrary;
    String targetWidgetName = node.component;

    if (node.component.contains('.')) {
      final parts = node.component.split('.');
      targetLibrary = parts[0];
      targetWidgetName = parts[1];
    }

    if (targetLibrary != null) {
      final libraryName = LibraryName([targetLibrary]);
      return _renderRfwWidget(libraryName, targetWidgetName, node.props, onEvent);
    }

    // 2. Otherwise, check if ANY registered daemon library defines this widget
    for (final id in _registeredLibraryIds) {
      final libraryName = LibraryName(['daemon_$id']);
      if (node.component == 'DaemonSensorCard') {
        return _renderRfwWidget(libraryName, 'DaemonSensorCard', node.props, onEvent);
      }
    }

    // 3. Fallback: render layout components recursively
    final childrenWidgets = node.children.map((child) => _buildWidget(child, context, onEvent)).toList();
    
    if (node.component == 'Column') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: childrenWidgets,
      );
    } else if (node.component == 'Row') {
      return Row(
        children: childrenWidgets,
      );
    } else if (node.component == 'ListView') {
      return ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: childrenWidgets,
      );
    }

    // Fallback to precompiled CatalogRegistry for leaf component
    return CatalogRegistry.instance.build(node, context, onEvent: onEvent);
  }

  Widget _renderRfwWidget(LibraryName libraryName, String widgetName, Map<String, dynamic> props, EventCallback? onEvent) {
    final data = DynamicContent();
    props.forEach((key, val) {
      data.update(key, val);
    });

    return RemoteWidget(
      runtime: _runtime,
      widget: FullyQualifiedWidgetName(libraryName, widgetName),
      data: data,
      onEvent: (eventName, eventArgs) {
        if (onEvent != null) {
          onEvent(eventName, Map<String, dynamic>.from(eventArgs));
        }
      },
    );
  }

  @override
  List<String> get supportedComponents => ['DaemonSensorCard'];
}

enum RenderBackendType {
  json,
  rfw,
}

final activeRenderBackendTypeProvider = StateProvider<RenderBackendType>((ref) {
  return RenderBackendType.json;
});

final renderBackendProvider = Provider<RenderBackend>((ref) {
  final type = ref.watch(activeRenderBackendTypeProvider);
  switch (type) {
    case RenderBackendType.json:
      return JsonRenderBackend(CatalogRegistry.instance);
    case RenderBackendType.rfw:
      final agents = ref.watch(a2aAgentRegistryProvider);
      return RfwRenderBackend(agents);
  }
});
