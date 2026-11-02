import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/building_asset_models.dart';
import '../../services/project_management_provider.dart';

const _uuid = Uuid();

class BuildingConfiguratorDialog extends ConsumerStatefulWidget {
  final String projectId;
  final ProjectBuilding building;

  const BuildingConfiguratorDialog({
    super.key,
    required this.projectId,
    required this.building,
  });

  @override
  ConsumerState<BuildingConfiguratorDialog> createState() =>
      _BuildingConfiguratorDialogState();
}

class _BuildingConfiguratorDialogState
    extends ConsumerState<BuildingConfiguratorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<BuildingEvent> _events;
  late List<BuildingBehavior> _behaviors;
  late List<BuildingAnimation> _animations;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _events = List.from(widget.building.events);
    _behaviors = List.from(widget.building.behaviors);
    _animations = List.from(widget.building.animations);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    ref.read(projectManagementProvider.notifier).updateBuildingDefinitions(
          projectId: widget.projectId,
          buildingId: widget.building.id,
          events: _events,
          behaviors: _behaviors,
          animations: _animations,
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已保存【${widget.building.buildingName}】的事件、行为与动画定义'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ── Event Editor ────────────────────────────────────────────────────────
  void _addOrEditEvent([BuildingEvent? existingEvent, int? index]) {
    final nameCtrl = TextEditingController(text: existingEvent?.name ?? '');
    final codeCtrl = TextEditingController(text: existingEvent?.code ?? '');
    final typeCtrl = TextEditingController(text: existingEvent?.type ?? 'alarm');
    final descCtrl = TextEditingController(text: existingEvent?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existingEvent == null ? '新增建筑事件' : '编辑建筑事件'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '事件名称',
                  hintText: '如：烟雾告警 / 水管渗漏',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: '事件编码 (Code)',
                  hintText: '如：SMOKE_ALARM_01',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: ['alarm', 'sensor', 'access', 'status'].contains(typeCtrl.text)
                    ? typeCtrl.text
                    : 'alarm',
                decoration: const InputDecoration(labelText: '事件类型'),
                items: const [
                  DropdownMenuItem(value: 'alarm', child: Text('告警事件 (Alarm)')),
                  DropdownMenuItem(value: 'sensor', child: Text('传感事件 (Sensor)')),
                  DropdownMenuItem(value: 'access', child: Text('门禁/通行 (Access)')),
                  DropdownMenuItem(value: 'status', child: Text('状态变更 (Status)')),
                ],
                onChanged: (val) {
                  if (val != null) typeCtrl.text = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '描述细节',
                  hintText: '详细描述触发条件或影响范围',
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
              if (nameCtrl.text.trim().isEmpty) return;
              final newEvt = BuildingEvent(
                id: existingEvent?.id ?? 'evt_${_uuid.v4().substring(0, 8)}',
                name: nameCtrl.text.trim(),
                code: codeCtrl.text.trim().toUpperCase(),
                type: typeCtrl.text.trim(),
                description: descCtrl.text.trim(),
              );
              setState(() {
                if (index != null) {
                  _events[index] = newEvt;
                } else {
                  _events.add(newEvt);
                }
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ── Behavior Editor ──────────────────────────────────────────────────────
  void _addOrEditBehavior([BuildingBehavior? existingBehavior, int? index]) {
    final nameCtrl = TextEditingController(text: existingBehavior?.name ?? '');
    final codeCtrl = TextEditingController(text: existingBehavior?.code ?? '');
    final actionCtrl = TextEditingController(
        text: existingBehavior?.actionType ?? 'switch_device');
    final targetCtrl = TextEditingController(text: existingBehavior?.target ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existingBehavior == null ? '新增建筑行为' : '编辑建筑行为'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '行为名称',
                  hintText: '如：开启应急排烟 / 封锁闸机',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: '行为编码 (Code)',
                  hintText: '如：ACTIVATE_EXHAUST_SYS',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: [
                  'switch_device',
                  'trigger_alarm',
                  'evacuate',
                  'adjust_hvac'
                ].contains(actionCtrl.text)
                    ? actionCtrl.text
                    : 'switch_device',
                decoration: const InputDecoration(labelText: '动作分类'),
                items: const [
                  DropdownMenuItem(value: 'switch_device', child: Text('开关设备 (Switch)')),
                  DropdownMenuItem(value: 'trigger_alarm', child: Text('触发警报 (Alarm)')),
                  DropdownMenuItem(value: 'evacuate', child: Text('应急疏散 (Evacuate)')),
                  DropdownMenuItem(value: 'adjust_hvac', child: Text('调节暖通 (HVAC)')),
                ],
                onChanged: (val) {
                  if (val != null) actionCtrl.text = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                decoration: const InputDecoration(
                  labelText: '作用目标系统/设备',
                  hintText: '如：HVAC_Exhaust_Sys_01',
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
              if (nameCtrl.text.trim().isEmpty) return;
              final newBhv = BuildingBehavior(
                id: existingBehavior?.id ?? 'bhv_${_uuid.v4().substring(0, 8)}',
                name: nameCtrl.text.trim(),
                code: codeCtrl.text.trim().toUpperCase(),
                actionType: actionCtrl.text.trim(),
                target: targetCtrl.text.trim(),
              );
              setState(() {
                if (index != null) {
                  _behaviors[index] = newBhv;
                } else {
                  _behaviors.add(newBhv);
                }
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ── Animation Editor ────────────────────────────────────────────────────
  void _addOrEditAnimation([BuildingAnimation? existingAnim, int? index]) {
    final nameCtrl = TextEditingController(text: existingAnim?.name ?? '');
    final codeCtrl = TextEditingController(text: existingAnim?.code ?? '');
    final typeCtrl = TextEditingController(
        text: existingAnim?.animationType ?? 'highlight_unit');
    final durationCtrl = TextEditingController(
        text: (existingAnim?.durationMs ?? 1000).toString());
    bool loop = existingAnim?.loop ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(existingAnim == null ? '新增模型动画' : '编辑模型动画'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '动画名称',
                    hintText: '如：楼层分层展开 / 警报闪烁',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: '动画编码 (Code)',
                    hintText: '如：FLOOR_EXPLODE_VIEW',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: [
                    'explode',
                    'pulse_alarm',
                    'rotate',
                    'highlight_unit'
                  ].contains(typeCtrl.text)
                      ? typeCtrl.text
                      : 'highlight_unit',
                  decoration: const InputDecoration(labelText: '动画模式'),
                  items: const [
                    DropdownMenuItem(value: 'explode', child: Text('楼层拆解/展开 (Explode)')),
                    DropdownMenuItem(value: 'pulse_alarm', child: Text('警报红光闪烁 (Pulse)')),
                    DropdownMenuItem(value: 'rotate', child: Text('3D 旋转巡航 (Rotate)')),
                    DropdownMenuItem(value: 'highlight_unit', child: Text('目标单元高亮 (Highlight)')),
                  ],
                  onChanged: (val) {
                    if (val != null) typeCtrl.text = val;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '播放时长 (毫秒 ms)',
                    hintText: '1000',
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('循环播放'),
                  value: loop,
                  onChanged: (val) {
                    setModalState(() {
                      loop = val ?? false;
                    });
                  },
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
                if (nameCtrl.text.trim().isEmpty) return;
                final newAnim = BuildingAnimation(
                  id: existingAnim?.id ?? 'anim_${_uuid.v4().substring(0, 8)}',
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim().toUpperCase(),
                  animationType: typeCtrl.text.trim(),
                  durationMs: int.tryParse(durationCtrl.text) ?? 1000,
                  loop: loop,
                );
                setState(() {
                  if (index != null) {
                    _animations[index] = newAnim;
                  } else {
                    _animations.add(newAnim);
                  }
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCustom = widget.building.sourceType == AssetSourceType.custom;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCustom ? Colors.purple.withAlpha(40) : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isCustom ? Icons.cloud_upload_outlined : Icons.domain,
                    color: isCustom ? Colors.purple : cs.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.building.buildingName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCustom
                                  ? Colors.purple.withAlpha(30)
                                  : cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isCustom ? '自定义模型' : '资产预设继承',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCustom ? Colors.purple : cs.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '模型文件: ${widget.building.modelName} (${widget.building.modelPath})',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
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
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_active_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('事件定义 (${_events.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('行为联动 (${_behaviors.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.animation_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('动画播放 (${_animations.length})'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tab View Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Events Tab
                  _buildEventsTab(cs),
                  // Behaviors Tab
                  _buildBehaviorsTab(cs),
                  // Animations Tab
                  _buildAnimationsTab(cs),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bottom Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _saveChanges,
                  icon: const Icon(Icons.check),
                  label: const Text('保存修改'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsTab(ColorScheme cs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '在项目管理中对建筑触发的信号与异常规则进行定义',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              ElevatedButton.icon(
                onPressed: () => _addOrEditEvent(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('定义新事件'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _events.isEmpty
              ? _buildEmptyState('暂未定义任何事件规则', '点击右上角“定义新事件”添加告警或传感机制')
              : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final item = _events[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: cs.surfaceContainerHighest.withAlpha(120),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getEventTypeColor(item.type).withAlpha(40),
                          child: Icon(
                            _getEventTypeIcon(item.type),
                            color: _getEventTypeColor(item.type),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '编码: ${item.code} | 类型: ${item.type}\n${item.description}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _addOrEditEvent(item, index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              onPressed: () {
                                setState(() => _events.removeAt(index));
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBehaviorsTab(ColorScheme cs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '定义事件触发后建筑内部设备的自动化联动行为',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              ElevatedButton.icon(
                onPressed: () => _addOrEditBehavior(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('定义新行为'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _behaviors.isEmpty
              ? _buildEmptyState('暂未定义任何行为联动', '点击右上角“定义新行为”设定设备自动控制')
              : ListView.builder(
                  itemCount: _behaviors.length,
                  itemBuilder: (context, index) {
                    final item = _behaviors[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: cs.surfaceContainerHighest.withAlpha(120),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primary.withAlpha(40),
                          child: Icon(Icons.bolt, color: cs.primary, size: 20),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '编码: ${item.code} | 动作: ${item.actionType}\n目标系统: ${item.target}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _addOrEditBehavior(item, index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              onPressed: () {
                                setState(() => _behaviors.removeAt(index));
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAnimationsTab(ColorScheme cs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '定义模型在孪生场景中的动态渲染与视效动画',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              ElevatedButton.icon(
                onPressed: () => _addOrEditAnimation(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('定义新动画'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _animations.isEmpty
              ? _buildEmptyState('暂未定义任何模型动画', '点击右上角“定义新动画”设定拆解或高亮动效')
              : ListView.builder(
                  itemCount: _animations.length,
                  itemBuilder: (context, index) {
                    final item = _animations[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: cs.surfaceContainerHighest.withAlpha(120),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withAlpha(40),
                          child: const Icon(Icons.play_circle_outline,
                              color: Colors.orange, size: 20),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '编码: ${item.code} | 模式: ${item.animationType}\n时长: ${item.durationMs}ms | 循环: ${item.loop ? "是" : "否"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _addOrEditAnimation(item, index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              onPressed: () {
                                setState(() => _animations.removeAt(index));
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String sub) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_clear_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Color _getEventTypeColor(String type) {
    switch (type) {
      case 'alarm':
        return Colors.red;
      case 'sensor':
        return Colors.blue;
      case 'access':
        return Colors.green;
      case 'status':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getEventTypeIcon(String type) {
    switch (type) {
      case 'alarm':
        return Icons.warning_amber_rounded;
      case 'sensor':
        return Icons.sensors;
      case 'access':
        return Icons.badge_outlined;
      case 'status':
        return Icons.info_outline;
      default:
        return Icons.notifications_none;
    }
  }
}
