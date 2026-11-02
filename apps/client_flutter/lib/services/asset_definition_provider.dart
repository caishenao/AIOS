import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/building_asset_models.dart';

const String _kAssetDefinitionKey = 'asset_definition_building_types_v1';

final assetDefinitionProvider =
    StateNotifierProvider<AssetDefinitionNotifier, List<BuildingTypeAsset>>((ref) {
  return AssetDefinitionNotifier();
});

class AssetDefinitionNotifier extends StateNotifier<List<BuildingTypeAsset>> {
  AssetDefinitionNotifier() : super([]) {
    _loadFromStorage();
  }

  static List<BuildingTypeAsset> get defaultPresets => [
        BuildingTypeAsset(
          id: 'asset_preset_office_tower',
          typeName: '智能办公大楼',
          category: '商业办公',
          modelName: 'office_tower_v1.gltf',
          modelPath: 'assets/models/office_tower_v1.gltf',
          previewColorHex: '#4A90E2',
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
            BuildingEvent(
              id: 'evt_office_hvac',
              name: '空调故障',
              code: 'HVAC_FAULT',
              type: 'status',
              description: '中央空调风机盘管故障报警',
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
            BuildingBehavior(
              id: 'bhv_office_lockdown',
              name: '联动自动封锁闸机',
              code: 'LOCKDOWN_GATES',
              actionType: 'switch_device',
              target: 'Main_Gate_Access',
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
            BuildingAnimation(
              id: 'anim_office_pulse',
              name: '报警红色脉冲闪烁',
              code: 'ALARM_RED_PULSE',
              animationType: 'pulse_alarm',
              durationMs: 800,
              loop: true,
            ),
          ],
        ),
        BuildingTypeAsset(
          id: 'asset_preset_residential',
          typeName: '智慧住宅楼',
          category: '居住社区',
          modelName: 'residential_block.gltf',
          modelPath: 'assets/models/residential_block.gltf',
          previewColorHex: '#50E3C2',
          events: [
            BuildingEvent(
              id: 'evt_res_water',
              name: '水管漏水监测',
              code: 'WATER_LEAKAGE',
              type: 'sensor',
              description: '管道水压异常及渗漏检测',
            ),
            BuildingEvent(
              id: 'evt_res_intrusion',
              name: '周界入侵告警',
              code: 'PERIMETER_INTRUSION',
              type: 'alarm',
              description: '住宅红外围界触发警报',
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
            BuildingBehavior(
              id: 'bhv_res_notify_guard',
              name: '呼叫物业安防台',
              code: 'NOTIFY_PROPERTY_GUARD',
              actionType: 'trigger_alarm',
              target: 'Security_Console',
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
        BuildingTypeAsset(
          id: 'asset_preset_warehouse',
          typeName: '工业仓储中心',
          category: '物流仓储',
          modelName: 'warehouse_center.gltf',
          modelPath: 'assets/models/warehouse_center.gltf',
          previewColorHex: '#F5A623',
          events: [
            BuildingEvent(
              id: 'evt_wh_temp_high',
              name: '库区超温报警',
              code: 'HIGH_TEMPERATURE',
              type: 'alarm',
              description: '冷链仓储温度超过阈值上限',
            ),
            BuildingEvent(
              id: 'evt_wh_conveyor_jam',
              name: '传送带堵塞',
              code: 'CONVEYOR_JAMMED',
              type: 'status',
              description: '自动化分拣传送带发生卡料',
            ),
          ],
          behaviors: [
            BuildingBehavior(
              id: 'bhv_wh_boost_cooling',
              name: '启动应急强冷风机',
              code: 'BOOST_COOLING_FANS',
              actionType: 'adjust_hvac',
              target: 'Cooling_Rack_Group',
            ),
          ],
          animations: [
            BuildingAnimation(
              id: 'anim_wh_heatmap',
              name: '温度热力图叠层',
              code: 'HEATMAP_OVERLAY',
              animationType: 'rotate',
              durationMs: 2000,
              loop: true,
            ),
          ],
        ),
        BuildingTypeAsset(
          id: 'asset_preset_hospital',
          typeName: '智慧医疗大楼',
          category: '公共卫生',
          modelName: 'hospital_main_building.gltf',
          modelPath: 'assets/models/hospital_main_building.gltf',
          previewColorHex: '#BD10E0',
          events: [
            BuildingEvent(
              id: 'evt_hosp_power',
              name: '后备电源切入',
              code: 'UPS_POWER_SWITCH',
              type: 'status',
              description: '市电中断，手术室UPS电源成功启动',
            ),
          ],
          behaviors: [
            BuildingBehavior(
              id: 'bhv_hosp_elevator_priority',
              name: '急诊电梯一键直达',
              code: 'PRIORITY_ELEVATOR',
              actionType: 'switch_device',
              target: 'Elevator_Medical_01',
            ),
          ],
          animations: [
            BuildingAnimation(
              id: 'anim_hosp_green_channel',
              name: '绿色救援通道动画',
              code: 'GREEN_CHANNEL_ANIM',
              animationType: 'highlight_unit',
              durationMs: 1000,
              loop: true,
            ),
          ],
        ),
      ];

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kAssetDefinitionKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        state = list.map((e) => BuildingTypeAsset.fromJson(e)).toList();
      } else {
        // Load default presets
        state = defaultPresets;
        await _saveToStorage();
      }
    } catch (_) {
      state = defaultPresets;
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_kAssetDefinitionKey, jsonStr);
    } catch (_) {}
  }

  Future<void> addBuildingTypeAsset(BuildingTypeAsset asset) async {
    state = [...state, asset];
    await _saveToStorage();
  }

  Future<void> updateBuildingTypeAsset(BuildingTypeAsset asset) async {
    state = state.map((item) => item.id == asset.id ? asset : item).toList();
    await _saveToStorage();
  }

  Future<void> deleteBuildingTypeAsset(String id) async {
    state = state.where((item) => item.id != id).toList();
    await _saveToStorage();
  }

  BuildingTypeAsset? getById(String id) {
    try {
      return state.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
