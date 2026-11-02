import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/building_asset_models.dart';
import '../services/project_management_provider.dart';
import 'widgets/add_building_dialog.dart';
import 'widgets/building_configurator_dialog.dart';

class ProjectManagementPage extends ConsumerStatefulWidget {
  const ProjectManagementPage({super.key});

  @override
  ConsumerState<ProjectManagementPage> createState() =>
      _ProjectManagementPageState();
}

class _ProjectManagementPageState
    extends ConsumerState<ProjectManagementPage> {
  String? _selectedProjectId;

  void _showCreateProjectDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建新项目'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '项目名称',
                hintText: '如：智慧园区三期',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: '项目描述',
                hintText: '如：高新产业研发中心及配套楼宇',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(
                labelText: '项目地址',
                hintText: '如：北京市海淀区中关村南大街',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              ref.read(projectManagementProvider.notifier).addProject(
                    nameCtrl.text.trim(),
                    descCtrl.text.trim(),
                    locCtrl.text.trim(),
                  );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('创建新项目成功！'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _openAddBuildingDialog(String projectId) {
    showDialog(
      context: context,
      builder: (ctx) => AddBuildingDialog(projectId: projectId),
    );
  }

  void _openBuildingConfigurator(String projectId, ProjectBuilding building) {
    showDialog(
      context: context,
      builder: (ctx) => BuildingConfiguratorDialog(
        projectId: projectId,
        building: building,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final projects = ref.watch(projectManagementProvider);

    if (projects.isNotEmpty &&
        (_selectedProjectId == null ||
            !projects.any((p) => p.id == _selectedProjectId))) {
      _selectedProjectId = projects.first.id;
    }

    final activeProject = projects.firstWhere(
      (p) => p.id == _selectedProjectId,
      orElse: () => projects.isNotEmpty
          ? projects.first
          : BuildingProject(
              id: '',
              name: '未选择项目',
              description: '',
              location: '',
              buildings: [],
            ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('项目管理 — 建筑及模型配置'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.library_add_outlined),
            tooltip: '资产定义管理',
            onPressed: () => Navigator.of(context).pushNamed('/asset-definition'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Sidebar: Project List
          Container(
            width: 280,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '项目列表 (${projects.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        tooltip: '新建项目',
                        onPressed: _showCreateProjectDialog,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final proj = projects[index];
                      final isSelected = proj.id == activeProject.id;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: cs.primaryContainer.withAlpha(100),
                        leading: Icon(
                          Icons.apartment_rounded,
                          color: isSelected ? cs.primary : cs.onSurfaceVariant,
                        ),
                        title: Text(
                          proj.name,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${proj.buildings.length} 栋建筑 | ${proj.location}',
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedProjectId = proj.id;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main Area: Buildings in Active Project
          Expanded(
            child: projects.isEmpty
                ? _buildEmptyProjectsView(cs)
                : Column(
                    children: [
                      // Active Project Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          border: Border(
                            bottom: BorderSide(color: cs.outline.withAlpha(30)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeProject.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${activeProject.description}  •  ${activeProject.location}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: () =>
                                  _openAddBuildingDialog(activeProject.id),
                              icon: const Icon(Icons.add_business_rounded),
                              label: const Text('新增建筑'),
                            ),
                          ],
                        ),
                      ),

                      // Buildings Grid / List
                      Expanded(
                        child: activeProject.buildings.isEmpty
                            ? _buildEmptyBuildingsView(cs, activeProject.id)
                            : ListView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: activeProject.buildings.length,
                                itemBuilder: (context, index) {
                                  final bld = activeProject.buildings[index];
                                  final isCustom = bld.sourceType ==
                                      AssetSourceType.custom;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: InkWell(
                                      onTap: () => _openBuildingConfigurator(
                                        activeProject.id,
                                        bld,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: isCustom
                                                        ? Colors.purple
                                                            .withAlpha(40)
                                                        : cs.primaryContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    isCustom
                                                        ? Icons.cloud_upload
                                                        : Icons.location_city,
                                                    color: isCustom
                                                        ? Colors.purple
                                                        : cs.primary,
                                                    size: 24,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            bld.buildingName,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          _TagBadge(
                                                            label: isCustom
                                                                ? '自定义上传模型'
                                                                : '资产预设继承',
                                                            color: isCustom
                                                                ? Colors.purple
                                                                : cs.primary,
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '模型名称: ${bld.modelName} (${bld.modelPath})',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: cs
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _openBuildingConfigurator(
                                                    activeProject.id,
                                                    bld,
                                                  ),
                                                  icon: const Icon(
                                                      Icons.settings_outlined,
                                                      size: 16),
                                                  label: const Text('定义与配置'),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () {
                                                    ref
                                                        .read(
                                                            projectManagementProvider
                                                                .notifier)
                                                        .deleteBuilding(
                                                          projectId:
                                                              activeProject.id,
                                                          buildingId: bld.id,
                                                        );
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            const Divider(height: 1),
                                            const SizedBox(height: 12),

                                            // Sub-items summary
                                            Row(
                                              children: [
                                                _MetricSummaryChip(
                                                  icon: Icons
                                                      .notifications_active_outlined,
                                                  label: '事件定义',
                                                  count: bld.events.length,
                                                  color: Colors.red,
                                                ),
                                                const SizedBox(width: 16),
                                                _MetricSummaryChip(
                                                  icon: Icons.bolt_outlined,
                                                  label: '联动行为',
                                                  count: bld.behaviors.length,
                                                  color: Colors.blue,
                                                ),
                                                const SizedBox(width: 16),
                                                _MetricSummaryChip(
                                                  icon: Icons
                                                      .animation_outlined,
                                                  label: '视效动画',
                                                  count: bld.animations.length,
                                                  color: Colors.orange,
                                                ),
                                                const Spacer(),
                                                Text(
                                                  '点击卡片可深入编辑规则 >',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: cs.primary,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProjectsView(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business_outlined, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text('暂无项目，请点击左上角创建新项目', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showCreateProjectDialog,
            icon: const Icon(Icons.add),
            label: const Text('创建第一个项目'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBuildingsView(ColorScheme cs, String projectId) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.domain_disabled, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('该项目中暂未添加任何建筑',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('您可以选择资产定义中预设的建筑类型，或上传自定义建筑 3D 模型'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _openAddBuildingDialog(projectId),
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('新增建筑'),
          ),
        ],
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TagBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _MetricSummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _MetricSummaryChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          '$count 项',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
