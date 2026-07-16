/// Flutter Semantics Parser — Tier 1 Screen-Parser.
///
/// Traverses the in-memory Flutter SemanticsNode tree and exports
/// a structured [ScreenNode] representation. This is the fastest tier
/// (< 1ms) and works only for the Flutter app's own UI.
library;

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../screen_structure.dart';

class FlutterSemanticsParser {
  /// Parse the current Flutter app's semantics tree.
  ///
  /// Returns null if the semantics tree is not available.
  /// [maxDepth] limits recursion depth to control output size.
  /// [interactiveOnly] filters to only interactive elements.
  ScreenStructure? parse({
    int maxDepth = 15,
    bool interactiveOnly = false,
  }) {
    final stopwatch = Stopwatch()..start();

    // Ensure semantics are enabled
    final binding = WidgetsBinding.instance;
    binding.ensureSemantics();

    final semanticsOwner = binding.pipelineOwner.semanticsOwner;
    if (semanticsOwner == null) {
      return null;
    }

    final rootNode = semanticsOwner.rootSemanticsNode;
    if (rootNode == null) {
      return null;
    }

    // Get screen dimensions
    final view = ui.PlatformDispatcher.instance.implicitView;
    final screenWidth = view != null
        ? view.physicalSize.width / view.devicePixelRatio
        : 0.0;
    final screenHeight = view != null
        ? view.physicalSize.height / view.devicePixelRatio
        : 0.0;
    final pixelRatio = view?.devicePixelRatio ?? 1.0;

    // Convert semantics tree
    final parsedRoot = _convertNode(rootNode, 0, maxDepth, interactiveOnly);

    stopwatch.stop();

    if (parsedRoot == null) {
      return null;
    }

    return ScreenStructure(
      source: 'flutter_semantics',
      latencyMs: stopwatch.elapsedMilliseconds,
      rootNode: parsedRoot,
      meta: ScreenMeta(
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        pixelRatio: pixelRatio,
        windowTitle: 'Home Steward',
        platform: _getPlatformName(),
      ),
      timestamp: DateTime.now(),
    );
  }

  /// Recursively convert a [SemanticsNode] to a [ScreenNode].
  ScreenNode? _convertNode(
    SemanticsNode node,
    int depth,
    int maxDepth,
    bool interactiveOnly,
  ) {
    if (depth > maxDepth) return null;

    final data = node.getSemanticsData();
    final rect = node.rect;
    final transform = node.transform;

    // Calculate global position by applying transform
    double left = rect.left;
    double top = rect.top;
    if (transform != null) {
      // Extract translation from the 4x4 matrix
      left += transform.getTranslation().x;
      top += transform.getTranslation().y;
    }

    // Determine role from flags and actions
    final role = _inferRole(data);
    final actions = _extractActions(data);
    final isInteractive = actions.isNotEmpty;

    // Build children
    final children = <ScreenNode>[];
    node.visitChildren((SemanticsNode child) {
      final childNode = _convertNode(child, depth + 1, maxDepth, interactiveOnly);
      if (childNode != null) {
        children.add(childNode);
      }
      return true; // continue traversal
    });

    // Skip non-interactive nodes if filtering
    if (interactiveOnly && !isInteractive && children.isEmpty) {
      return null;
    }

    // Skip decorative nodes (no label, no value, no actions, no meaningful children)
    final label = data.label.isNotEmpty ? data.label : null;
    final value = data.value.isNotEmpty ? data.value : null;
    final hint = data.hint.isNotEmpty ? data.hint : null;

    if (label == null &&
        value == null &&
        hint == null &&
        !isInteractive &&
        children.isEmpty) {
      return null;
    }

    return ScreenNode(
      role: role,
      label: label,
      value: value,
      hint: hint,
      bounds: BoundingBox(
        left: left,
        top: top,
        width: rect.width,
        height: rect.height,
      ),
      actions: actions,
      interactive: isInteractive,
      enabled: !data.hasFlag(SemanticsFlag.isEnabled) || data.hasFlag(SemanticsFlag.isEnabled),
      focused: data.hasFlag(SemanticsFlag.isFocused),
      children: children,
    );
  }

  /// Infer semantic role from [SemanticsData] flags.
  String _inferRole(SemanticsData data) {
    if (data.hasFlag(SemanticsFlag.isButton)) return 'button';
    if (data.hasFlag(SemanticsFlag.isTextField)) return 'input';
    if (data.hasFlag(SemanticsFlag.isSlider)) return 'slider';
    if (data.hasFlag(SemanticsFlag.isToggled)) return 'switch';
    if (data.hasFlag(SemanticsFlag.hasCheckedState)) return 'checkbox';
    if (data.hasFlag(SemanticsFlag.isHeader)) return 'header';
    if (data.hasFlag(SemanticsFlag.isImage)) return 'image';
    if (data.hasFlag(SemanticsFlag.isLink)) return 'link';
    if (data.hasFlag(SemanticsFlag.hasImplicitScrolling)) return 'scrollable';
    if (data.hasFlag(SemanticsFlag.isLiveRegion)) return 'live_region';
    if (data.label.isNotEmpty) return 'text';
    return 'container';
  }

  /// Extract available actions from [SemanticsData].
  List<String> _extractActions(SemanticsData data) {
    final actions = <String>[];
    if (data.hasAction(SemanticsAction.tap)) actions.add('tap');
    if (data.hasAction(SemanticsAction.longPress)) actions.add('long_press');
    if (data.hasAction(SemanticsAction.scrollUp)) actions.add('scroll_up');
    if (data.hasAction(SemanticsAction.scrollDown)) actions.add('scroll_down');
    if (data.hasAction(SemanticsAction.scrollLeft)) actions.add('scroll_left');
    if (data.hasAction(SemanticsAction.scrollRight)) actions.add('scroll_right');
    if (data.hasAction(SemanticsAction.increase)) actions.add('increase');
    if (data.hasAction(SemanticsAction.decrease)) actions.add('decrease');
    if (data.hasAction(SemanticsAction.setText)) actions.add('set_text');
    if (data.hasAction(SemanticsAction.copy)) actions.add('copy');
    if (data.hasAction(SemanticsAction.cut)) actions.add('cut');
    if (data.hasAction(SemanticsAction.paste)) actions.add('paste');
    if (data.hasAction(SemanticsAction.dismiss)) actions.add('dismiss');
    if (data.hasAction(SemanticsAction.focus)) actions.add('focus');
    return actions;
  }

  /// Get platform name string.
  String _getPlatformName() {
    // Use defaultTargetPlatform which works on all platforms including web
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
