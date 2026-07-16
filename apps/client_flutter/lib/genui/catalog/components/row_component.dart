import 'package:flutter/material.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

class RowComponent extends StatelessWidget {
  final List<Widget> childrenWidgets;
  final double spacing;
  final ThemeTokens theme;

  const RowComponent({
    super.key,
    required this.childrenWidgets,
    required this.spacing,
    required this.theme,
  });

  static void register(CatalogRegistry registry) {
    registry.register('Row', ({
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

      return RowComponent(
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
      spacedChildren.add(Expanded(child: childrenWidgets[i]));
      if (i < childrenWidgets.length - 1) {
        spacedChildren.add(SizedBox(width: spacing));
      }
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: spacedChildren,
    );
  }
}
