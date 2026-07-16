import 'package:flutter/material.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

class ColumnComponent extends StatelessWidget {
  final List<Widget> childrenWidgets;
  final double spacing;
  final ThemeTokens theme;

  const ColumnComponent({
    super.key,
    required this.childrenWidgets,
    required this.spacing,
    required this.theme,
  });

  static void register(CatalogRegistry registry) {
    registry.register('Column', ({
      required props,
      required children,
      bindings,
      events,
      theme,
      required context,
      onEvent,
    }) {
      final t = theme ?? ThemeTokens.minimal;
      final space = (props['spacing'] as num?)?.toDouble() ?? t.baseSpacing;
      
      final builtChildren = children.map((childNode) => 
        registry.build(childNode, context, theme: t, onEvent: onEvent)
      ).toList();

      return ColumnComponent(
        childrenWidgets: builtChildren,
        spacing: space,
        theme: t,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (childrenWidgets.isEmpty) return const SizedBox();
    
    final spacedChildren = <Widget>[];
    for (int i = 0; i < childrenWidgets.length; i++) {
      spacedChildren.add(childrenWidgets[i]);
      if (i < childrenWidgets.length - 1) {
        spacedChildren.add(SizedBox(height: spacing));
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: spacedChildren,
    );
  }
}
