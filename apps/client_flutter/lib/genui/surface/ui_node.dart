import 'package:json_annotation/json_annotation.dart';

part 'ui_node.g.dart';

@JsonSerializable()
class UiNode {
  final String component;
  final Map<String, dynamic> props;
  final Map<String, dynamic> bindings;
  final Map<String, String> events;
  final List<UiNode> children;

  UiNode({
    required this.component,
    this.props = const {},
    this.bindings = const {},
    this.events = const {},
    this.children = const [],
  });

  factory UiNode.fromJson(Map<String, dynamic> json) => _$UiNodeFromJson(json);
  Map<String, dynamic> toJson() => _$UiNodeToJson(this);
}
