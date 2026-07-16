import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui_node.dart';
import '../catalog/catalog_registry.dart';
import '../catalog/theme_tokens.dart';
import '../render_backend/render_backend.dart';

class GenUiSurface extends ConsumerWidget {
  final UiNode root;
  final ThemeTokens? theme;
  final EventCallback? onEvent;

  const GenUiSurface({
    super.key,
    required this.root,
    this.theme,
    this.onEvent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(renderBackendProvider);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: backend.render(
          root, 
          context, 
          theme: theme, 
          onEvent: onEvent
        ),
      ),
    );
  }
}
