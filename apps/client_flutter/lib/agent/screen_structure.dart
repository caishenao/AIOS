/// Screen Structure — unified data model for Screen-Parser output.
///
/// Represents the structured UI tree extracted from any screen via
/// Flutter Semantics (Tier 1), Platform Accessibility APIs (Tier 2),
/// or OmniParser vision model (Tier 3).
library;

import 'dart:convert';

/// Bounding box in screen coordinates.
class BoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const BoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Center X coordinate.
  double get centerX => left + width / 2;

  /// Center Y coordinate.
  double get centerY => top + height / 2;

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'centerX': centerX,
    'centerY': centerY,
  };

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );

  @override
  String toString() => 'BoundingBox($left, $top, ${width}x$height)';
}

/// A single node in the parsed UI tree.
class ScreenNode {
  /// Semantic role: 'button', 'text', 'input', 'image', 'slider',
  /// 'checkbox', 'switch', 'header', 'container', 'scrollable', 'link', etc.
  final String role;

  /// Visible text label or accessibility label.
  final String? label;

  /// Current value (e.g. text field content, slider position).
  final String? value;

  /// Usage hint (e.g. "Double tap to activate").
  final String? hint;

  /// Bounding box in screen coordinates.
  final BoundingBox bounds;

  /// Available actions: 'tap', 'long_press', 'scroll_up', 'scroll_down',
  /// 'set_text', 'increase', 'decrease', 'dismiss', etc.
  final List<String> actions;

  /// Whether this element is interactive (tappable, editable, etc.).
  final bool interactive;

  /// Whether this element is currently enabled.
  final bool enabled;

  /// Whether this element is currently focused.
  final bool focused;

  /// Child nodes.
  final List<ScreenNode> children;

  const ScreenNode({
    required this.role,
    this.label,
    this.value,
    this.hint,
    required this.bounds,
    this.actions = const [],
    this.interactive = false,
    this.enabled = true,
    this.focused = false,
    this.children = const [],
  });

  /// Total count of all descendant nodes (recursive).
  int get totalDescendants {
    int count = children.length;
    for (final child in children) {
      count += child.totalDescendants;
    }
    return count;
  }

  /// Find all interactive elements in the subtree.
  List<ScreenNode> findInteractive() {
    final result = <ScreenNode>[];
    if (interactive) result.add(this);
    for (final child in children) {
      result.addAll(child.findInteractive());
    }
    return result;
  }

  /// Find nodes matching a label pattern (case-insensitive).
  List<ScreenNode> findByLabel(String pattern) {
    final result = <ScreenNode>[];
    final lowerPattern = pattern.toLowerCase();
    if (label != null && label!.toLowerCase().contains(lowerPattern)) {
      result.add(this);
    }
    for (final child in children) {
      result.addAll(child.findByLabel(pattern));
    }
    return result;
  }

  /// Find nodes by role.
  List<ScreenNode> findByRole(String targetRole) {
    final result = <ScreenNode>[];
    if (role == targetRole) result.add(this);
    for (final child in children) {
      result.addAll(child.findByRole(targetRole));
    }
    return result;
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'role': role,
      'bounds': bounds.toJson(),
    };
    if (label != null && label!.isNotEmpty) map['label'] = label;
    if (value != null && value!.isNotEmpty) map['value'] = value;
    if (hint != null && hint!.isNotEmpty) map['hint'] = hint;
    if (actions.isNotEmpty) map['actions'] = actions;
    if (interactive) map['interactive'] = true;
    if (!enabled) map['enabled'] = false;
    if (focused) map['focused'] = true;
    if (children.isNotEmpty) {
      map['children'] = children.map((c) => c.toJson()).toList();
    }
    return map;
  }

  factory ScreenNode.fromJson(Map<String, dynamic> json) => ScreenNode(
    role: json['role'] as String? ?? 'unknown',
    label: json['label'] as String?,
    value: json['value'] as String?,
    hint: json['hint'] as String?,
    bounds: json['bounds'] != null
        ? BoundingBox.fromJson(json['bounds'] as Map<String, dynamic>)
        : const BoundingBox(left: 0, top: 0, width: 0, height: 0),
    actions: (json['actions'] as List<dynamic>?)?.cast<String>() ?? const [],
    interactive: json['interactive'] as bool? ?? false,
    enabled: json['enabled'] as bool? ?? true,
    focused: json['focused'] as bool? ?? false,
    children: (json['children'] as List<dynamic>?)
        ?.map((c) => ScreenNode.fromJson(c as Map<String, dynamic>))
        .toList() ?? const [],
  );

  @override
  String toString() => 'ScreenNode($role, label=$label, bounds=$bounds)';
}

/// Metadata about the screen capture.
class ScreenMeta {
  /// Screen width in logical pixels.
  final double screenWidth;

  /// Screen height in logical pixels.
  final double screenHeight;

  /// Device pixel ratio.
  final double pixelRatio;

  /// Title of the active window / app.
  final String? windowTitle;

  /// Platform: 'windows', 'android', 'linux', 'macos', 'ios', 'web'.
  final String platform;

  const ScreenMeta({
    required this.screenWidth,
    required this.screenHeight,
    this.pixelRatio = 1.0,
    this.windowTitle,
    required this.platform,
  });

  Map<String, dynamic> toJson() => {
    'screenWidth': screenWidth,
    'screenHeight': screenHeight,
    'pixelRatio': pixelRatio,
    if (windowTitle != null) 'windowTitle': windowTitle,
    'platform': platform,
  };

  factory ScreenMeta.fromJson(Map<String, dynamic> json) => ScreenMeta(
    screenWidth: (json['screenWidth'] as num).toDouble(),
    screenHeight: (json['screenHeight'] as num).toDouble(),
    pixelRatio: (json['pixelRatio'] as num?)?.toDouble() ?? 1.0,
    windowTitle: json['windowTitle'] as String?,
    platform: json['platform'] as String? ?? 'unknown',
  );
}

/// Complete screen parse result.
class ScreenStructure {
  /// Source tier: 'flutter_semantics', 'platform_a11y', 'omniparser'.
  final String source;

  /// Parse latency in milliseconds.
  final int latencyMs;

  /// Root node of the UI tree.
  final ScreenNode rootNode;

  /// Screen metadata.
  final ScreenMeta meta;

  /// Timestamp of the parse.
  final DateTime timestamp;

  const ScreenStructure({
    required this.source,
    required this.latencyMs,
    required this.rootNode,
    required this.meta,
    required this.timestamp,
  });

  /// Total number of elements in the tree.
  int get totalElements => 1 + rootNode.totalDescendants;

  /// All interactive elements in the tree.
  List<ScreenNode> get interactiveElements => rootNode.findInteractive();

  /// Compact JSON for LLM consumption (omits empty fields).
  String toCompactJson() => jsonEncode(toJson());

  /// Summary string for quick overview.
  String get summary =>
      'ScreenStructure(source=$source, latency=${latencyMs}ms, '
      'elements=$totalElements, interactive=${interactiveElements.length})';

  Map<String, dynamic> toJson() => {
    'source': source,
    'latencyMs': latencyMs,
    'totalElements': totalElements,
    'interactiveCount': interactiveElements.length,
    'meta': meta.toJson(),
    'timestamp': timestamp.toIso8601String(),
    'root': rootNode.toJson(),
  };

  factory ScreenStructure.fromJson(Map<String, dynamic> json) =>
      ScreenStructure(
        source: json['source'] as String,
        latencyMs: json['latencyMs'] as int? ?? 0,
        rootNode: ScreenNode.fromJson(json['root'] as Map<String, dynamic>),
        meta: ScreenMeta.fromJson(json['meta'] as Map<String, dynamic>),
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );
}
