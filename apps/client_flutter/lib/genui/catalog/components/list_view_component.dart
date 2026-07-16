import 'package:flutter/material.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

class ListViewComponent extends StatelessWidget {
  final List<Widget> childrenWidgets;
  final double spacing;
  final ThemeTokens theme;

  const ListViewComponent({
    super.key,
    required this.childrenWidgets,
    required this.spacing,
    required this.theme,
  });

  static void register(CatalogRegistry registry) {
    registry.register('ListView', ({
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

      return ListViewComponent(
        childrenWidgets: builtChildren,
        spacing: space,
        theme: t,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (childrenWidgets.isEmpty) return const SizedBox();
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // Usually part of a larger scroll view
      itemCount: childrenWidgets.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing),
      itemBuilder: (context, index) => childrenWidgets[index],
    );
  }
}
