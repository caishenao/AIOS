import 'dart:convert';

/// Source type of a building asset model (preset from Asset Definition vs custom uploaded model)
enum AssetSourceType {
  preset,
  custom,
}

/// Building Event Definition (事件定义)
class BuildingEvent {
  final String id;
  final String name;
  final String code;
  final String type; // e.g., 'alarm', 'sensor', 'access', 'status'
  final String description;

  BuildingEvent({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.description,
  });

  BuildingEvent copyWith({
    String? id,
    String? name,
    String? code,
    String? type,
    String? description,
  }) {
    return BuildingEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'type': type,
        'description': description,
      };

  factory BuildingEvent.fromJson(Map<String, dynamic> json) => BuildingEvent(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        type: json['type'] as String? ?? 'sensor',
        description: json['description'] as String? ?? '',
      );
}

/// Building Behavior Definition (行为定义)
class BuildingBehavior {
  final String id;
  final String name;
  final String code;
  final String actionType; // e.g., 'switch_device', 'trigger_alarm', 'evacuate', 'adjust_hvac'
  final String target; // Target device or system

  BuildingBehavior({
    required this.id,
    required this.name,
    required this.code,
    required this.actionType,
    required this.target,
  });

  BuildingBehavior copyWith({
    String? id,
    String? name,
    String? code,
    String? actionType,
    String? target,
  }) {
    return BuildingBehavior(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      actionType: actionType ?? this.actionType,
      target: target ?? this.target,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'actionType': actionType,
        'target': target,
      };

  factory BuildingBehavior.fromJson(Map<String, dynamic> json) => BuildingBehavior(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        actionType: json['actionType'] as String? ?? 'switch_device',
        target: json['target'] as String? ?? '',
      );
}

/// Building Animation Definition (动画定义)
class BuildingAnimation {
  final String id;
  final String name;
  final String code;
  final String animationType; // e.g., 'floor_explode', 'pulse_alarm', 'rotate', 'highlight_unit'
  final int durationMs;
  final bool loop;

  BuildingAnimation({
    required this.id,
    required this.name,
    required this.code,
    required this.animationType,
    required this.durationMs,
    this.loop = false,
  });

  BuildingAnimation copyWith({
    String? id,
    String? name,
    String? code,
    String? animationType,
    int? durationMs,
    bool? loop,
  }) {
    return BuildingAnimation(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      animationType: animationType ?? this.animationType,
      durationMs: durationMs ?? this.durationMs,
      loop: loop ?? this.loop,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'animationType': animationType,
        'durationMs': durationMs,
        'loop': loop,
      };

  factory BuildingAnimation.fromJson(Map<String, dynamic> json) => BuildingAnimation(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        animationType: json['animationType'] as String? ?? 'highlight_unit',
        durationMs: json['durationMs'] as int? ?? 1000,
        loop: json['loop'] as bool? ?? false,
      );
}

/// Building Type Asset defined in Asset Definition (资产定义中的建筑类型及其关联模型)
class BuildingTypeAsset {
  final String id;
  final String typeName; // e.g. "智能办公大楼"
  final String category; // e.g. "商业办公"
  final String modelName; // e.g. "office_tower_v1.gltf"
  final String modelPath;
  final String previewColorHex;
  final List<BuildingEvent> events;
  final List<BuildingBehavior> behaviors;
  final List<BuildingAnimation> animations;

  BuildingTypeAsset({
    required this.id,
    required this.typeName,
    required this.category,
    required this.modelName,
    required this.modelPath,
    required this.previewColorHex,
    required this.events,
    required this.behaviors,
    required this.animations,
  });

  BuildingTypeAsset copyWith({
    String? id,
    String? typeName,
    String? category,
    String? modelName,
    String? modelPath,
    String? previewColorHex,
    List<BuildingEvent>? events,
    List<BuildingBehavior>? behaviors,
    List<BuildingAnimation>? animations,
  }) {
    return BuildingTypeAsset(
      id: id ?? this.id,
      typeName: typeName ?? this.typeName,
      category: category ?? this.category,
      modelName: modelName ?? this.modelName,
      modelPath: modelPath ?? this.modelPath,
      previewColorHex: previewColorHex ?? this.previewColorHex,
      events: events ?? List.from(this.events),
      behaviors: behaviors ?? List.from(this.behaviors),
      animations: animations ?? List.from(this.animations),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'typeName': typeName,
        'category': category,
        'modelName': modelName,
        'modelPath': modelPath,
        'previewColorHex': previewColorHex,
        'events': events.map((e) => e.toJson()).toList(),
        'behaviors': behaviors.map((b) => b.toJson()).toList(),
        'animations': animations.map((a) => a.toJson()).toList(),
      };

  factory BuildingTypeAsset.fromJson(Map<String, dynamic> json) => BuildingTypeAsset(
        id: json['id'] as String? ?? '',
        typeName: json['typeName'] as String? ?? '',
        category: json['category'] as String? ?? '',
        modelName: json['modelName'] as String? ?? '',
        modelPath: json['modelPath'] as String? ?? '',
        previewColorHex: json['previewColorHex'] as String? ?? '#4A90E2',
        events: (json['events'] as List<dynamic>?)
                ?.map((e) => BuildingEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        behaviors: (json['behaviors'] as List<dynamic>?)
                ?.map((b) => BuildingBehavior.fromJson(b as Map<String, dynamic>))
                .toList() ??
            [],
        animations: (json['animations'] as List<dynamic>?)
                ?.map((a) => BuildingAnimation.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// A specific Building Instance inside a Project (项目管理中的建筑)
class ProjectBuilding {
  final String id;
  final String buildingName;
  final AssetSourceType sourceType;
  final String? buildingTypeId; // ID in Asset Definition if preset
  final String modelName;
  final String modelPath;
  final List<BuildingEvent> events;
  final List<BuildingBehavior> behaviors;
  final List<BuildingAnimation> animations;

  ProjectBuilding({
    required this.id,
    required this.buildingName,
    required this.sourceType,
    this.buildingTypeId,
    required this.modelName,
    required this.modelPath,
    required this.events,
    required this.behaviors,
    required this.animations,
  });

  ProjectBuilding copyWith({
    String? id,
    String? buildingName,
    AssetSourceType? sourceType,
    String? buildingTypeId,
    String? modelName,
    String? modelPath,
    List<BuildingEvent>? events,
    List<BuildingBehavior>? behaviors,
    List<BuildingAnimation>? animations,
  }) {
    return ProjectBuilding(
      id: id ?? this.id,
      buildingName: buildingName ?? this.buildingName,
      sourceType: sourceType ?? this.sourceType,
      buildingTypeId: buildingTypeId ?? this.buildingTypeId,
      modelName: modelName ?? this.modelName,
      modelPath: modelPath ?? this.modelPath,
      events: events ?? List.from(this.events),
      behaviors: behaviors ?? List.from(this.behaviors),
      animations: animations ?? List.from(this.animations),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'buildingName': buildingName,
        'sourceType': sourceType.name,
        'buildingTypeId': buildingTypeId,
        'modelName': modelName,
        'modelPath': modelPath,
        'events': events.map((e) => e.toJson()).toList(),
        'behaviors': behaviors.map((b) => b.toJson()).toList(),
        'animations': animations.map((a) => a.toJson()).toList(),
      };

  factory ProjectBuilding.fromJson(Map<String, dynamic> json) => ProjectBuilding(
        id: json['id'] as String? ?? '',
        buildingName: json['buildingName'] as String? ?? '',
        sourceType: AssetSourceType.values.firstWhere(
          (e) => e.name == json['sourceType'],
          orElse: () => AssetSourceType.preset,
        ),
        buildingTypeId: json['buildingTypeId'] as String?,
        modelName: json['modelName'] as String? ?? '',
        modelPath: json['modelPath'] as String? ?? '',
        events: (json['events'] as List<dynamic>?)
                ?.map((e) => BuildingEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        behaviors: (json['behaviors'] as List<dynamic>?)
                ?.map((b) => BuildingBehavior.fromJson(b as Map<String, dynamic>))
                .toList() ??
            [],
        animations: (json['animations'] as List<dynamic>?)
                ?.map((a) => BuildingAnimation.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Building Project (项目)
class BuildingProject {
  final String id;
  final String name;
  final String description;
  final String location;
  final List<ProjectBuilding> buildings;

  BuildingProject({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.buildings,
  });

  BuildingProject copyWith({
    String? id,
    String? name,
    String? description,
    String? location,
    List<ProjectBuilding>? buildings,
  }) {
    return BuildingProject(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      buildings: buildings ?? List.from(this.buildings),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'location': location,
        'buildings': buildings.map((b) => b.toJson()).toList(),
      };

  factory BuildingProject.fromJson(Map<String, dynamic> json) => BuildingProject(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        location: json['location'] as String? ?? '',
        buildings: (json['buildings'] as List<dynamic>?)
                ?.map((b) => ProjectBuilding.fromJson(b as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
