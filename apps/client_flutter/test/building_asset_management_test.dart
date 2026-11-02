import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_steward/models/building_asset_models.dart';
import 'package:home_steward/services/asset_definition_provider.dart';
import 'package:home_steward/services/project_management_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Building Asset Definition & Models Tests', () {
    test('Default asset presets should contain preset building types with events/behaviors/animations', () {
      final presets = AssetDefinitionNotifier.defaultPresets;

      expect(presets.length, greaterThanOrEqualTo(4));

      final officeTower = presets.firstWhere((p) => p.id == 'asset_preset_office_tower');
      expect(officeTower.typeName, equals('智能办公大楼'));
      expect(officeTower.modelName, equals('office_tower_v1.gltf'));
      expect(officeTower.events.isNotEmpty, isTrue);
      expect(officeTower.behaviors.isNotEmpty, isTrue);
      expect(officeTower.animations.isNotEmpty, isTrue);
    });

    test('ProjectBuilding and BuildingProject JSON serialization', () {
      final building = ProjectBuilding(
        id: 'bld_101',
        buildingName: '主研发楼',
        sourceType: AssetSourceType.preset,
        buildingTypeId: 'asset_preset_office_tower',
        modelName: 'office_tower_v1.gltf',
        modelPath: 'assets/models/office_tower_v1.gltf',
        events: [
          BuildingEvent(
            id: 'evt_1',
            name: '烟雾告警',
            code: 'SMOKE_ALARM',
            type: 'alarm',
            description: '探测到烟雾',
          ),
        ],
        behaviors: [
          BuildingBehavior(
            id: 'bhv_1',
            name: '排烟联动',
            code: 'EXHAUST',
            actionType: 'evacuate',
            target: 'HVAC',
          ),
        ],
        animations: [
          BuildingAnimation(
            id: 'anim_1',
            name: '楼层展开',
            code: 'FLOOR_EXPLODE',
            animationType: 'explode',
            durationMs: 1000,
          ),
        ],
      );

      final jsonMap = building.toJson();
      final restored = ProjectBuilding.fromJson(jsonMap);

      expect(restored.id, equals('bld_101'));
      expect(restored.buildingName, equals('主研发楼'));
      expect(restored.sourceType, equals(AssetSourceType.preset));
      expect(restored.events.length, equals(1));
      expect(restored.events.first.code, equals('SMOKE_ALARM'));
      expect(restored.behaviors.first.code, equals('EXHAUST'));
      expect(restored.animations.first.code, equals('FLOOR_EXPLODE'));
    });
  });

  group('Project Management Notifier Tests', () {
    test('Add building from Asset Definition preset inherits model and definitions', () async {
      final notifier = ProjectManagementNotifier();
      await notifier.addProject('测试园区', '包含多栋建筑', '北京');

      final projects = notifier.state;
      expect(projects.isNotEmpty, isTrue);
      final projId = projects.last.id;

      final preset = AssetDefinitionNotifier.defaultPresets.first;

      await notifier.addBuildingFromPreset(
        projectId: projId,
        presetAsset: preset,
        customBuildingName: 'A1大楼',
      );

      final updatedProjects = notifier.state;
      final updatedProj = updatedProjects.firstWhere((p) => p.id == projId);

      expect(updatedProj.buildings.length, equals(1));
      final addedBuilding = updatedProj.buildings.first;
      expect(addedBuilding.buildingName, equals('A1大楼'));
      expect(addedBuilding.sourceType, equals(AssetSourceType.preset));
      expect(addedBuilding.modelName, equals(preset.modelName));
      expect(addedBuilding.events.length, equals(preset.events.length));
      expect(addedBuilding.behaviors.length, equals(preset.behaviors.length));
      expect(addedBuilding.animations.length, equals(preset.animations.length));
    });

    test('Add building with custom uploaded model and define events/behaviors/animations', () async {
      final notifier = ProjectManagementNotifier();
      await notifier.addProject('智慧工厂', '工业4.0厂区', '上海');

      final projId = notifier.state.last.id;

      // Add custom building with user's uploaded model
      await notifier.addBuildingFromCustomUpload(
        projectId: projId,
        buildingName: 'C3 自建实验车间',
        modelName: 'custom_factory_v3.gltf',
        modelPath: '/user/uploads/custom_factory_v3.gltf',
      );

      var proj = notifier.state.firstWhere((p) => p.id == projId);
      expect(proj.buildings.length, equals(1));
      var building = proj.buildings.first;
      expect(building.sourceType, equals(AssetSourceType.custom));
      expect(building.modelName, equals('custom_factory_v3.gltf'));
      expect(building.events.isEmpty, isTrue);

      // Define custom events, behaviors, and animations for the custom uploaded building
      final customEvents = [
        BuildingEvent(
          id: 'evt_c1',
          name: '危险化学气体浓度超标',
          code: 'GAS_LEAK_WARNING',
          type: 'alarm',
          description: '检测到气体微量渗漏',
        ),
      ];
      final customBehaviors = [
        BuildingBehavior(
          id: 'bhv_c1',
          name: '自动隔离关断门',
          code: 'CLOSE_ISOLATION_DOORS',
          actionType: 'switch_device',
          target: 'Door_Iso_Sys',
        ),
      ];
      final customAnimations = [
        BuildingAnimation(
          id: 'anim_c1',
          name: '区域红色警报闪烁',
          code: 'RED_FLASH',
          animationType: 'pulse_alarm',
          durationMs: 500,
          loop: true,
        ),
      ];

      await notifier.updateBuildingDefinitions(
        projectId: projId,
        buildingId: building.id,
        events: customEvents,
        behaviors: customBehaviors,
        animations: customAnimations,
      );

      proj = notifier.state.firstWhere((p) => p.id == projId);
      building = proj.buildings.first;

      expect(building.events.length, equals(1));
      expect(building.events.first.code, equals('GAS_LEAK_WARNING'));
      expect(building.behaviors.first.code, equals('CLOSE_ISOLATION_DOORS'));
      expect(building.animations.first.code, equals('RED_FLASH'));
    });
  });
}
