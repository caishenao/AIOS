import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/building_asset_models.dart';
import '../../services/asset_definition_provider.dart';
import '../../services/project_management_provider.dart';

class AddBuildingDialog extends ConsumerStatefulWidget {
  final String projectId;

  const AddBuildingDialog({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<AddBuildingDialog> createState() => _AddBuildingDialogState();
}

class _AddBuildingDialogState extends ConsumerState<AddBuildingDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Preset Selection State
  BuildingTypeAsset? _selectedPresetAsset;
  final TextEditingController _presetBuildingNameCtrl = TextEditingController();

  // Custom Model Upload State
  final TextEditingController _customNameCtrl = TextEditingController();
  final TextEditingController _customModelNameCtrl = TextEditingController();
  final TextEditingController _customModelPathCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _presetBuildingNameCtrl.dispose();
    _customNameCtrl.dispose();
    _customModelNameCtrl.dispose();
    _customModelPathCtrl.dispose();
    super.dispose();
  }

  void _submitPresetBuilding() {
    if (_selectedPresetAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个资产定义中的建筑类型模型')),
      );
      return;
    }

    final customName = _presetBuildingNameCtrl.text.trim();

    ref.read(projectManagementProvider.notifier).addBuildingFromPreset(
          projectId: widget.projectId,
          presetAsset: _selectedPresetAsset!,
          customBuildingName: customName.isNotEmpty
              ? customName
              : _selectedPresetAsset!.typeName,
        );

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('成功添加【${customName.isNotEmpty ? customName : _selectedPresetAsset!.typeName}】（已自动继承模型及关联事件/行为/动画）'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _submitCustomBuilding() {
    final bldName = _customNameCtrl.text.trim();
    final modelName = _customModelNameCtrl.text.trim();
    final modelPath = _customModelPathCtrl.text.trim();

    if (bldName.isEmpty || modelName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整的建筑名称和模型名称')),
      );
      return;
    }

    ref.read(projectManagementProvider.notifier).addBuildingFromCustomUpload(
          projectId: widget.projectId,
          buildingName: bldName,
          modelName: modelName,
          modelPath: modelPath.isNotEmpty ? modelPath : '/uploads/models/$modelName',
        );

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('成功上传并新增自定义模型建筑【$bldName】！点击建筑可自定义事件与行为。'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final presetAssets = ref.watch(assetDefinitionProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 650,
        height: 540,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                Icon(Icons.add_business_rounded, color: cs.primary, size: 28),
                const SizedBox(width: 12),
                const Text(
                  '项目管理 — 新增项目建筑',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.domain_add, size: 18),
                      SizedBox(width: 8),
                      Text('从资产定义选择建筑类型模型'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('使用自定义上传建筑模型'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tab View Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Preset from Asset Definition
                  _buildPresetTab(cs, presetAssets),
                  // Tab 2: Custom Upload Model
                  _buildCustomUploadTab(cs),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Footer buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {
                    if (_tabController.index == 0) {
                      _submitPresetBuilding();
                    } else {
                      _submitCustomBuilding();
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('确认新增建筑'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetTab(ColorScheme cs, List<BuildingTypeAsset> presetAssets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择已在【资产定义】中注册的标准建筑类型，将自动继承对应模型及其预置的事件、行为与动画：',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: presetAssets.isEmpty
              ? const Center(child: Text('暂无可用资产定义'))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: presetAssets.length,
                  itemBuilder: (context, index) {
                    final asset = presetAssets[index];
                    final isSelected = _selectedPresetAsset?.id == asset.id;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedPresetAsset = asset;
                          if (_presetBuildingNameCtrl.text.isEmpty) {
                            _presetBuildingNameCtrl.text = asset.typeName;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primaryContainer.withAlpha(180)
                              : cs.surfaceContainerHighest.withAlpha(80),
                          border: Border.all(
                            color: isSelected ? cs.primary : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.domain,
                                    color: isSelected ? cs.primary : cs.secondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    asset.typeName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? cs.onPrimaryContainer
                                          : cs.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle,
                                      color: cs.primary, size: 18),
                              ],
                            ),
                            Text(
                              '模型: ${asset.modelName}',
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                _ChipBadge(
                                  label: '${asset.events.length} 事件',
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                _ChipBadge(
                                  label: '${asset.behaviors.length} 行为',
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 4),
                                _ChipBadge(
                                  label: '${asset.animations.length} 动画',
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _presetBuildingNameCtrl,
          decoration: const InputDecoration(
            labelText: '自定义项目内建筑命名（选填）',
            hintText: '如：1号楼 智慧办公塔楼',
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomUploadTab(ColorScheme cs) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '上传您自制的建筑 3D/2D 模型文件（GLTF/OBJ/FBX），在项目中创建自定义建筑并配置动态能力：',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customNameCtrl,
            decoration: const InputDecoration(
              labelText: '建筑名称 *',
              hintText: '如：C4 研发实验楼 / 独立发电机房',
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customModelNameCtrl,
            decoration: const InputDecoration(
              labelText: '模型名称 *',
              hintText: '如：custom_factory_v2.gltf',
              prefixIcon: Icon(Icons.view_in_ar),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customModelPathCtrl,
                  decoration: const InputDecoration(
                    labelText: '模型存储路径 / Web URL',
                    hintText: '/uploads/models/custom_factory_v2.gltf',
                    prefixIcon: Icon(Icons.folder_open),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    if (_customNameCtrl.text.isEmpty) {
                      _customNameCtrl.text = '自研实验厂房';
                    }
                    _customModelNameCtrl.text = 'custom_lab_v1.gltf';
                    _customModelPathCtrl.text =
                        '/storage/models/custom_lab_v1.gltf';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('模拟加载上传的 3D 建筑模型成功！')),
                  );
                },
                icon: const Icon(Icons.file_upload),
                label: const Text('选取文件'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '提示：使用自定义上传模型的建筑添加后，可在项目管理列表中点击该建筑，为其定义专属的事件规则、联动行为与视效动画。',
                    style: TextStyle(fontSize: 12, color: Colors.purple),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ChipBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
