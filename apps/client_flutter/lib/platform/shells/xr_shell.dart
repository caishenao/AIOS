import 'package:flutter/material.dart';
import '../../genui/surface/ui_node.dart';

/// Wraps the UI for XR/Glasses.
/// Implements the "Voice-first + Single Card" fallback.
class XrShell extends StatelessWidget {
  final UiNode root;
  final Widget Function(UiNode) surfaceBuilder;

  const XrShell({
    super.key, 
    required this.root,
    required this.surfaceBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Traverse the UI tree and extract ONLY the first InfoCard, ConfirmDialog, or MediaPlayer
    // and ignore all ListViews, Rows, Columns, etc.
    final importantNode = _findImportantNode(root);

    return Scaffold(
      backgroundColor: Colors.transparent, // XR is often see-through
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.black87, // High contrast background for XR
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withAlpha(50)),
          ),
          child: importantNode != null 
              ? surfaceBuilder(importantNode)
              : const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Listening...', style: TextStyle(color: Colors.white, fontSize: 24)),
                ),
        ),
      ),
    );
  }

  UiNode? _findImportantNode(UiNode node) {
    const importantComponents = ['InfoCard', 'ConfirmDialog', 'WeatherCard', 'MediaPlayer'];
    
    if (importantComponents.contains(node.component)) {
      return node;
    }

    if (node.children != null) {
      for (final child in node.children!) {
        final found = _findImportantNode(child);
        if (found != null) return found;
      }
    }
    return null;
  }
}
