import 'package:json_annotation/json_annotation.dart';
import '../genui/surface/ui_node.dart';

part 'a2ui_messages.g.dart';

@JsonSerializable(createFactory: false)
abstract class A2UIMessage {
  final String type;

  const A2UIMessage(this.type);

  static A2UIMessage fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'render':
        return A2UIRenderMessage.fromJson(json);
      case 'patch':
        return A2UIPatchMessage.fromJson(json);
      case 'data_update':
        return A2UIDataUpdateMessage.fromJson(json);
      case 'event_ack':
        return A2UIEventAckMessage.fromJson(json);
      default:
        throw ArgumentError('Unknown message type: ${json['type']}');
    }
  }

  Map<String, dynamic> toJson();
}

@JsonSerializable()
class A2UIRenderMessage extends A2UIMessage {
  @JsonKey(name: 'surfaceId')
  final String surfaceId;
  
  @JsonKey(name: 'styleSkill')
  final String? styleSkill;
  
  @JsonKey(name: 'uiTree')
  final UiNode uiTree;

  const A2UIRenderMessage({
    required this.surfaceId,
    this.styleSkill,
    required this.uiTree,
  }) : super('render');

  factory A2UIRenderMessage.fromJson(Map<String, dynamic> json) => _$A2UIRenderMessageFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$A2UIRenderMessageToJson(this);
}

@JsonSerializable()
class A2UIPatchMessage extends A2UIMessage {
  @JsonKey(name: 'surfaceId')
  final String surfaceId;
  final String path;
  final List<Map<String, dynamic>> operations;

  const A2UIPatchMessage({
    required this.surfaceId,
    required this.path,
    required this.operations,
  }) : super('patch');

  factory A2UIPatchMessage.fromJson(Map<String, dynamic> json) => _$A2UIPatchMessageFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$A2UIPatchMessageToJson(this);
}

@JsonSerializable()
class A2UIDataUpdateMessage extends A2UIMessage {
  @JsonKey(name: 'surfaceId')
  final String surfaceId;
  final Map<String, dynamic> bindings;

  const A2UIDataUpdateMessage({
    required this.surfaceId,
    required this.bindings,
  }) : super('data_update');

  factory A2UIDataUpdateMessage.fromJson(Map<String, dynamic> json) => _$A2UIDataUpdateMessageFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$A2UIDataUpdateMessageToJson(this);
}

@JsonSerializable()
class A2UIEventAckMessage extends A2UIMessage {
  @JsonKey(name: 'eventId')
  final String eventId;
  final String status;

  const A2UIEventAckMessage({
    required this.eventId,
    required this.status,
  }) : super('event_ack');

  factory A2UIEventAckMessage.fromJson(Map<String, dynamic> json) => _$A2UIEventAckMessageFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$A2UIEventAckMessageToJson(this);
}

// --- Client to Server ---

@JsonSerializable()
class A2UIClientEvent {
  final String type = 'user_event';
  final String action;
  final Map<String, dynamic> payload;

  const A2UIClientEvent({
    required this.action,
    this.payload = const {},
  });

  Map<String, dynamic> toJson() => _$A2UIClientEventToJson(this);
}

@JsonSerializable()
class A2UIConfirmResponse {
  final String type = 'confirm_response';
  @JsonKey(name: 'confirmationId')
  final String confirmationId;
  final bool confirmed;

  const A2UIConfirmResponse({
    required this.confirmationId,
    required this.confirmed,
  });

  Map<String, dynamic> toJson() => _$A2UIConfirmResponseToJson(this);
}
