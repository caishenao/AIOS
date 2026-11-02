import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/building_asset_models.dart';
import '../services/asset_definition_provider.dart';

const _uuid = Uuid();

class AssetDefinitionPage extends ConsumerStatefulWidget {
  const AssetDefinitionPage({super.key});

  @override
  ConsumerState<AssetDefinitionPage> createState() =>
      _AssetDefinitionPageState();
}

class _AssetDefinitionPageState extends ConsumerState<AssetDefinitionPage> {
  BuildingTypeAsset? _selectedAsset;

  void _showAddBuildingTypeDialog() {
    final typeNameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: '通用建筑');
    final modelNameCtrl = TextEditingController();
    final modelPathCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增资产定义 — 建筑类型模板'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeNameCtrl,
                decoration: const InputDecoration(
                  labelText: '建筑类型名称 *',
                  hintText: '如：智慧体育馆 / 数据中心机房',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: '分类分类',
                  hintText: '如：公共文体 / 基础设施',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelNameCtrl,
                decoration: const InputDecoration(
                  labelText: '标准 3D 模型文件名 *',
                  hintText: '如：stadium_model_v1.gltf',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelPathCtrl,
                decoration: const InputDecoration(
                  labelText: '模型资产路径 / URL',
                  hintText: 'assets/models/stadium_model_v1.gltf',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (typeNameCtrl.text.trim().isEmpty ||
                  modelNameCtrl.text.trim().isEmpty) {
                return;
              }

              final newAsset = BuildingTypeAsset(
                id: 'asset_type_${_uuid.v4().substring(0, 8)}',
                typeName: typeNameCtrl.text.trim(),
                category: categoryCtrl.text.trim(),
                modelName: modelNameCtrl.text.trim(),
                modelPath: modelPathCtrl.text.trim().isNotEmpty
                    ? modelPathCtrl.text.trim()
                    : 'assets/models/${modelNameCtrl.text.trim()}',
                previewColorHex: '#4A90E2',
                events: [
                  BuildingEvent(
                    id: 'evt_${_uuid.v4().substring(0, 8)}',
                    name: '常规运行监测',
                    code: 'NORMAL_STATUS',
                    type: 'status',
                    description: '建筑设备基础运行状态上报',
                  ),
                ],
                behaviors: [
                  BuildingBehavior(
                    id: 'bhv_${_uuid.v4().substring(0, 8)}',
                    name: '智能节能模式',
                    code: 'ENERGY_SAVING_MODE',
                    actionType: 'adjust_hvac',
                    target: 'Main_Power_Sys',
                  ),
                ],
                animations: [
                  BuildingAnimation(
                    id: 'anim_${_uuid.v4().substring(0, 8)}',
                    name: '外立面巡视',
                    code: 'FACADE_PATROL',
                    animationType: 'rotate',
                    durationMs: 2000,
                    loop: true,
                  ),
                ],
              );

              ref
                  .read(assetDefinitionProvider.notifier)
                  .addBuildingTypeAsset(newAsset);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已新增资产定义类型【${newAsset.typeName}】'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('保存资产定义'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assetTypes = ref.watch(assetDefinitionProvider);

    if (assetTypes.isNotEmpty &&
        (_selectedAsset == null ||
            !assetTypes.any((a) => a.id == _selectedAsset?.id))) {
      _selectedAsset = assetTypes.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产定义 — 建筑类型与模型模板管理'),
        centerTitle: false,
        actions: [
          FilledButton.icon(
            onPressed: _showAddBuildingTypeDialog,
            icon: const Icon(Icons.add),
            label: const Text('新增建筑类型模板'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Sidebar List of Asset Types
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(
                right: BorderSide(color: cs.outline.withAlpha(40)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '资产定义模板库 (${assetTypes.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: assetTypes.length,
                    itemBuilder: (context, index) {
                      final item = assetTypes[index];
                      final isSelected = _selectedAsset?.id == item.id;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: cs.primaryContainer.withAlpha(100),
                        leading: CircleAvatar(
                          backgroundColor: cs.primary.withAlpha(40),
                          child: Icon(Icons.domain, color: cs.primary, size: 20),
                        ),
                        title: Text(
                          item.typeName,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${item.category} | 模型: ${item.modelName}',
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedAsset = item;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main Detail Area
          Expanded(
            child: _selectedAsset == null
                ? const Center(child: Text('请在左侧选择建筑类型'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card 1: Asset Header Info
                        Card(
                          elevation: 0,
                          color: cs.surfaceContainerHighest.withAlpha(120),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.business,
                                    size: 32,
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedAsset!.typeName,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '所属分类: ${_selectedAsset!.category}  |  关联模型: ${_selectedAsset!.modelName}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        '模型文件路径: ${_selectedAsset!.modelPath}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(assetDefinitionProvider.notifier)
                                        .deleteBuildingTypeAsset(
                                            _selectedAsset!.id);
                                    setState(() {
                                      _selectedAsset = null;
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  label: const Text('删除此类型',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Section 1: Predefined Events
                        _buildSectionHeader(
                          cs,
                          title: '预设事件定义 (${_selectedAsset!.events.length})',
                          icon: Icons.notifications_active_outlined,
                        ),
                        const SizedBox(height: 12),
                        ..._selectedAsset!.events.map(
                          (evt) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.warning_amber_rounded,
                                  color: Colors.red),
                              title: Text(evt.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '编码: ${evt.code} | 类型: ${evt.type}\n${evt.description}'),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Section 2: Predefined Behaviors
                        _buildSectionHeader(
                          cs,
                          title: '预设行为联动 (${_selectedAsset!.behaviors.length})',
                          icon: Icons.bolt_outlined,
                        ),
                        const SizedBox(height: 12),
                        ..._selectedAsset!.behaviors.map(
                          (bhv) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading:
                                  const Icon(Icons.bolt, color: Colors.blue),
                              title: Text(bhv.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '编码: ${bhv.code} | 动作: ${bhv.actionType}\n目标系统: ${bhv.target}'),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Section 3: Predefined Animations
                        _buildSectionHeader(
                          cs,
                          title: '预设模型动画 (${_selectedAsset!.animations.length})',
                          icon: Icons.animation_outlined,
                        ),
                        const SizedBox(height: 12),
                        ..._selectedAsset!.animations.map(
                          (anim) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.play_circle_outline,
                                  color: Colors.orange),
                              title: Text(anim.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '编码: ${anim.code} | 模式: ${anim.animationType} | 时长: ${anim.durationMs}ms'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ColorScheme cs,
      {required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
