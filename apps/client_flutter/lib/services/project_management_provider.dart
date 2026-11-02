import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/building_asset_models.dart';

const String _kProjectManagementKey = 'project_management_projects_v1';
const _uuid = Uuid();

final projectManagementProvider =
    StateNotifierProvider<ProjectManagementNotifier, List<BuildingProject>>((ref) {
  return ProjectManagementNotifier();
});

class ProjectManagementNotifier extends StateNotifier<List<BuildingProject>> {
  ProjectManagementNotifier() : super([]) {
    _loadFromStorage();
  }

  static List<BuildingProject> get defaultProjects => [
        BuildingProject(
          id: 'proj_tech_park_01',
          name: '高新科技产业园区一期',
          description: '包含中央智慧办公塔楼与配套工业仓储中心',
          location: '上海张江高科技园区 B-12',
          buildings: [
            ProjectBuilding(
              id: 'bld_preset_01',
              buildingName: 'A1 智慧办公主楼',
              sourceType: AssetSourceType.preset,
              buildingTypeId: 'asset_preset_office_tower',
              modelName: 'office_tower_v1.gltf',
              modelPath: 'assets/models/office_tower_v1.gltf',
              events: [
                BuildingEvent(
                  id: 'evt_office_smoke',
                  name: '烟雾告警',
                  code: 'SMOKE_ALARM',
                  type: 'alarm',
                  description: '探测到办公区烟雾浓度异常',
                ),
                BuildingEvent(
                  id: 'evt_office_access',
                  name: '门禁刷卡',
                  code: 'ACCESS_CARD_SWIPE',
                  type: 'access',
                  description: '大堂门禁闸机成功刷卡通过',
                ),
              ],
              behaviors: [
                BuildingBehavior(
                  id: 'bhv_office_evacuate',
                  name: '开启应急排烟',
                  code: 'ACTIVATE_EMERGENCY_EXHAUST',
                  actionType: 'evacuate',
                  target: 'HVAC_Exhaust_Sys',
                ),
              ],
              animations: [
                BuildingAnimation(
                  id: 'anim_office_explode',
                  name: '楼层分层展开',
                  code: 'FLOOR_EXPLODE_VIEW',
                  animationType: 'explode',
                  durationMs: 1500,
                  loop: false,
                ),
              ],
            ),
            ProjectBuilding(
              id: 'bld_custom_01',
              buildingName: 'B3 自建无人实验楼',
              sourceType: AssetSourceType.custom,
              buildingTypeId: null,
              modelName: 'custom_lab_building.gltf',
              modelPath: '/uploads/models/custom_lab_building.gltf',
              events: [
                BuildingEvent(
                  id: 'evt_custom_radiation',
                  name: '辐射及化学泄漏监测',
                  code: 'RAD_LEAK_ALERT',
                  type: 'alarm',
                  description: '实验室感应器触发化学物质泄漏微增提示',
                ),
              ],
              behaviors: [
                BuildingBehavior(
                  id: 'bhv_custom_nitrogen',
                  name: '触发惰性气体灭火',
                  code: 'INERT_GAS_SUPPRESSION',
                  actionType: 'trigger_alarm',
                  target: 'Lab_Safety_Sys_09',
                ),
              ],
              animations: [
                BuildingAnimation(
                  id: 'anim_custom_glow',
                  name: '隔离舱警示发光',
                  code: 'ISOLATION_GLOW',
                  animationType: 'pulse_alarm',
                  durationMs: 600,
                  loop: true,
                ),
              ],
            ),
          ],
        ),
        BuildingProject(
          id: 'proj_smart_community_02',
          name: '未来城智慧示范社区',
          description: '集住宅、医院和社区服务中心于一体的数字化社区',
          location: '杭州余杭未来科技城 05号地块',
          buildings: [
            ProjectBuilding(
              id: 'bld_preset_02',
              buildingName: '1号楼 智慧精装住宅',
              sourceType: AssetSourceType.preset,
              buildingTypeId: 'asset_preset_residential',
              modelName: 'residential_block.gltf',
              modelPath: 'assets/models/residential_block.gltf',
              events: [
                BuildingEvent(
                  id: 'evt_res_water',
                  name: '水管漏水监测',
                  code: 'WATER_LEAKAGE',
                  type: 'sensor',
                  description: '管道水压异常及渗漏检测',
                ),
              ],
              behaviors: [
                BuildingBehavior(
                  id: 'bhv_res_valve_close',
                  name: '紧急关断主水阀',
                  code: 'CLOSE_MAIN_WATER_VALVE',
                  actionType: 'switch_device',
                  target: 'Water_Valve_01',
                ),
              ],
              animations: [
                BuildingAnimation(
                  id: 'anim_res_highlight',
                  name: '故障单元高亮',
                  code: 'HIGHLIGHT_UNIT',
                  animationType: 'highlight_unit',
                  durationMs: 1200,
                  loop: true,
                ),
              ],
            ),
          ],
        ),
      ];

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kProjectManagementKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        state = list.map((e) => BuildingProject.fromJson(e)).toList();
      } else {
        state = defaultProjects;
        await _saveToStorage();
      }
    } catch (_) {
      state = defaultProjects;
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_kProjectManagementKey, jsonStr);
    } catch (_) {}
  }

  Future<void> addProject(String name, String description, String location) async {
    final newProj = BuildingProject(
      id: 'proj_${_uuid.v4().substring(0, 8)}',
      name: name,
      description: description,
      location: location,
      buildings: [],
    );
    state = [...state, newProj];
    await _saveToStorage();
  }

  /// Add building derived from an Asset Definition building type preset
  Future<void> addBuildingFromPreset({
    required String projectId,
    required BuildingTypeAsset presetAsset,
    required String customBuildingName,
  }) async {
    final newBuilding = ProjectBuilding(
      id: 'bld_${_uuid.v4().substring(0, 8)}',
      buildingName: customBuildingName.isNotEmpty ? customBuildingName : presetAsset.typeName,
      sourceType: AssetSourceType.preset,
      buildingTypeId: presetAsset.id,
      modelName: presetAsset.modelName,
      modelPath: presetAsset.modelPath,
      // Inherit preset events, behaviors, animations
      events: presetAsset.events.map((e) => e.copyWith(id: 'evt_${_uuid.v4().substring(0, 8)}')).toList(),
      behaviors: presetAsset.behaviors.map((b) => b.copyWith(id: 'bhv_${_uuid.v4().substring(0, 8)}')).toList(),
      animations: presetAsset.animations.map((a) => a.copyWith(id: 'anim_${_uuid.v4().substring(0, 8)}')).toList(),
    );

    _addBuildingToProject(projectId, newBuilding);
  }

  /// Add building with a custom uploaded building model
  Future<void> addBuildingFromCustomUpload({
    required String projectId,
    required String buildingName,
    required String modelName,
    required String modelPath,
  }) async {
    final newBuilding = ProjectBuilding(
      id: 'bld_${_uuid.v4().substring(0, 8)}',
      buildingName: buildingName,
      sourceType: AssetSourceType.custom,
      buildingTypeId: null,
      modelName: modelName,
      modelPath: modelPath,
      events: [],
      behaviors: [],
      animations: [],
    );

    _addBuildingToProject(projectId, newBuilding);
  }

  void _addBuildingToProject(String projectId, ProjectBuilding building) {
    state = state.map((proj) {
      if (proj.id == projectId) {
        return proj.copyWith(buildings: [...proj.buildings, building]);
      }
      return proj;
    }).toList();
    _saveToStorage();
  }

  /// Update building events, behaviors, and animations when edited by user in Project Management
  Future<void> updateBuildingDefinitions({
    required String projectId,
    required String buildingId,
    List<BuildingEvent>? events,
    List<BuildingBehavior>? behaviors,
    List<BuildingAnimation>? animations,
  }) async {
    state = state.map((proj) {
      if (proj.id == projectId) {
        final updatedBuildings = proj.buildings.map((bld) {
          if (bld.id == buildingId) {
            return bld.copyWith(
              events: events ?? bld.events,
              behaviors: behaviors ?? bld.behaviors,
              animations: animations ?? bld.animations,
            );
          }
          return bld;
        }).toList();
        return proj.copyWith(buildings: updatedBuildings);
      }
      return proj;
    }).toList();

    await _saveToStorage();
  }

  Future<void> deleteBuilding({
    required String projectId,
    required String buildingId,
  }) async {
    state = state.map((proj) {
      if (proj.id == projectId) {
        return proj.copyWith(
          buildings: proj.buildings.where((b) => b.id != buildingId).toList(),
        );
      }
      return proj;
    }).toList();

    await _saveToStorage();
  }
}
