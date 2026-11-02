import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../config/capability_registry.dart';
import '../config/chat_history.dart';
import '../agent/chat_provider.dart';
import '../genui/surface/ui_node.dart';
import '../platform/device_form_factor.dart';
import '../agent/discovery_service.dart';
import '../agent/bridge_service.dart';
import '../config/llm_config.dart';
import '../config/tts_config.dart';
import '../genui/render_backend/render_backend.dart';

class ConfigPage extends ConsumerWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(capabilityRegistryProvider);
    final skills = ref.watch(agentSkillRegistryProvider);
    final a2aAgents = ref.watch(a2aAgentRegistryProvider);
    final formFactor = ref.watch(formFactorProvider);
    final llmConfig = ref.watch(llmConfigProvider);
    final ttsConfig = ref.watch(ttsConfigProvider);
    final isScanning = ref.watch(discoveryServiceProvider).isScanning;
    final cs = Theme.of(context).colorScheme;

    final history = ref.watch(chatHistoryProvider);
    final searchQuery = ref.watch(chatHistorySearchQueryProvider);
    final filteredHistory = history.where((e) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      final userMatch = e.userMessage.toLowerCase().contains(q);
      final replyMatch = e.textReply?.toLowerCase().contains(q) ?? false;
      final uiMatch = e.uiTree?.toString().toLowerCase().contains(q) ?? false;
      return userMatch || replyMatch || uiMatch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '系统设置',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: cs.onSurface),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // Section 1: LLM Engine Config
          _buildSectionHeader('LLM 认知核心', context,
            trailing: IconButton(
              icon: Icon(Icons.edit_note, color: cs.primary, size: 22),
              onPressed: () => _showLlmConfigDialog(context, ref, llmConfig),
            ),
          ),
          _buildCard(
            context,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(
                llmConfig.provider.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface, letterSpacing: 0.5),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '模型: ${llmConfig.model}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontFamily: 'monospace'),
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.psychology, color: cs.primary, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Form Factor
          _buildSectionHeader('设备形态', context),
          _buildCard(
            context,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DeviceFormFactor>(
                  isExpanded: true,
                  value: formFactor,
                  dropdownColor: cs.surface,
                  style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
                  items: DeviceFormFactor.values.map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.name.toUpperCase(), style: const TextStyle(letterSpacing: 1.0, fontSize: 13)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(formFactorProvider.notifier).setFormFactor(val);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: MCP Servers Config
          _buildSectionHeader(
            'MCP 服务节点',
            context,
            trailing: IconButton(
              icon: Icon(Icons.add_circle_outline, color: cs.primary, size: 22),
              onPressed: () => _showAddServerDialog(context, ref),
            ),
          ),
          if (servers.isEmpty)
            _buildEmptyState('未注册任何活跃的 MCP 服务。', context)
          else
            for (final server in servers)
              Dismissible(
                key: ValueKey(server.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                onDismissed: (_) {
                  ref.read(capabilityRegistryProvider.notifier).removeServer(server.id);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已移除 ${server.name}')));
                },
                child: _buildCard(
                  context,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(server.name, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                    subtitle: Text(
                      '${server.transport.toUpperCase()} · ${server.endpoint}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.api_outlined, color: Colors.green, size: 18),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 24),

          // Section 4: Skills Catalog
          _buildSectionHeader(
            '智能体技能',
            context,
            trailing: IconButton(
              icon: Icon(Icons.add_circle_outline, color: cs.primary, size: 22),
              onPressed: () => _showAddSkillDialog(context, ref),
            ),
          ),
          if (skills.isEmpty)
            _buildEmptyState('未加载任何本地技能。', context)
          else
            for (final skill in skills)
              Dismissible(
                key: ValueKey(skill.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                onDismissed: (_) {
                  ref.read(agentSkillRegistryProvider.notifier).removeSkill(skill.id);
                },
                child: _buildCard(
                  context,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(skill.name, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                    subtitle: Text(skill.description, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    trailing: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.secondary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.offline_bolt_outlined, color: cs.secondary, size: 18),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 24),

          // Section 5: A2A Cluster
          _buildSectionHeader(
            '去中心化集群 (A2A)',
            context,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isScanning)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    isScanning ? Icons.portable_wifi_off : Icons.wifi_find,
                    color: cs.primary,
                    size: 22,
                  ),
                  onPressed: () {
                    final discovery = ref.read(discoveryServiceProvider);
                    final bridge = ref.read(bridgeServiceProvider);
                    if (discovery.isScanning) {
                      discovery.stopScanning();
                      bridge.stopBridging();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('离线: 集群网格已停止')));
                    } else {
                      discovery.startScanning();
                      bridge.startBridging();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('在线: 正在扫描集群网格...')));
                    }
                  },
                ),
              ],
            ),
          ),
          if (a2aAgents.isEmpty)
            _buildEmptyState(
              isScanning ? '正在扫描网络寻找 AIOS 集群...' : '集群扫描仪已离线。',
              context,
            )
          else
            for (final agent in a2aAgents)
              Dismissible(
                key: ValueKey(agent.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                onDismissed: (_) {
                  ref.read(a2aAgentRegistryProvider.notifier).removeAgent(agent.id);
                },
                child: _buildCard(
                  context,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(agent.name, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                    subtitle: Text(
                      '${agent.endpoint}\n${agent.description}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (agent.pairingToken != null && agent.pairingToken!.isNotEmpty) ...[
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => _showPairingDialog(context, ref, agent),
                            child: const Text('已配对', style: TextStyle(color: Colors.green, fontSize: 12)),
                          ),
                        ] else ...[
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => _showPairingDialog(context, ref, agent),
                            child: const Text('未配对', style: TextStyle(color: Colors.orange, fontSize: 12)),
                          ),
                        ],
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.redAccent.withAlpha(160), size: 20),
                          onPressed: () {
                            ref.read(a2aAgentRegistryProvider.notifier).removeAgent(agent.id);
                          },
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
          const SizedBox(height: 24),

          // Section 6: Voice Config
          _buildSectionHeader('语音播报配置', context),
          _buildCard(
            context,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('自动语音播报', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('收到智能体回复时自动朗读', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                    value: ttsConfig.enabled,
                    activeTrackColor: cs.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => ref.read(ttsConfigProvider.notifier).setEnabled(val),
                  ),
                  Divider(color: cs.outline.withAlpha(30)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('播报语言', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: ttsConfig.language,
                            dropdownColor: cs.surface,
                            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
                            items: const [
                              DropdownMenuItem(value: 'zh-CN', child: Text('中文 (普通话)')),
                              DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(ttsConfigProvider.notifier).setLanguage(val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: cs.outline.withAlpha(30)),
                  _buildSliderRow('语速', ttsConfig.rate, 0.1, 1.0, (val) {
                    ref.read(ttsConfigProvider.notifier).setRate(val);
                  }, cs),
                  Divider(color: cs.outline.withAlpha(30)),
                  _buildSliderRow('音高', ttsConfig.pitch, 0.5, 2.0, (val) {
                    ref.read(ttsConfigProvider.notifier).setPitch(val);
                  }, cs),
                  Divider(color: cs.outline.withAlpha(30)),
                  _buildSliderRow('音量', ttsConfig.volume, 0.0, 1.0, (val) {
                    ref.read(ttsConfigProvider.notifier).setVolume(val);
                  }, cs),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 7: Render Backend Config
          _buildSectionHeader('UI 渲染后端', context),
          _buildCard(
            context,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('渲染引擎模式', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<RenderBackendType>(
                      value: ref.watch(activeRenderBackendTypeProvider),
                      dropdownColor: cs.surface,
                      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: RenderBackendType.json, child: Text('JSON (Dynamic)')),
                        DropdownMenuItem(value: RenderBackendType.rfw, child: Text('RFW (Remote)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(activeRenderBackendTypeProvider.notifier).state = val;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 8: Dialogue History
          _buildSectionHeader(
            '历史对话',
            context,
            trailing: history.isEmpty ? null : TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
              label: const Text('清空', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              onPressed: () => _showClearHistoryConfirmDialog(context, ref),
            ),
          ),

          // Search Bar
          _buildCard(
            context,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: TextField(
                style: TextStyle(color: cs.onSurface, fontSize: 13),
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: cs.onSurfaceVariant, size: 20),
                  hintText: '搜索历史对话记录...',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant.withAlpha(120), fontSize: 13),
                  border: InputBorder.none,
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: cs.onSurfaceVariant, size: 18),
                          onPressed: () => ref.read(chatHistorySearchQueryProvider.notifier).state = '',
                        )
                      : null,
                ),
                onChanged: (val) {
                  ref.read(chatHistorySearchQueryProvider.notifier).state = val;
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (filteredHistory.isEmpty)
            _buildEmptyState(
              searchQuery.isNotEmpty ? '未找到符合搜索条件的历史记录。' : '暂无对话历史记录。',
              context,
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredHistory.length,
              itemBuilder: (context, index) {
                final entry = filteredHistory[index];
                return Dismissible(
                  key: ValueKey(entry.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                  onDismissed: (_) {
                    ref.read(chatHistoryProvider.notifier).deleteEntry(entry.id);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除该条对话记录')));
                  },
                  child: _buildCard(
                    context,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      title: Text(
                        entry.userMessage,
                        style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            entry.textReply != null
                                ? entry.textReply!
                                : (entry.uiTree != null ? '[UI 界面: ${entry.uiTree!['component'] ?? '组件'}]' : '（无回复内容）'),
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(entry.timestamp),
                            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withAlpha(120)),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.zoom_in, color: cs.primary, size: 20),
                            onPressed: () => _showHistoryDetailDialog(context, ref, entry),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.redAccent.withAlpha(150), size: 20),
                            onPressed: () {
                              ref.read(chatHistoryProvider.notifier).deleteEntry(entry.id);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除该条对话记录')));
                            },
                          ),
                        ],
                      ),
                      onTap: () => _showHistoryDetailDialog(context, ref, entry),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared Widgets
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title, BuildContext context, {Widget? trailing}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child, EdgeInsetsGeometry? margin}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      margin: margin ?? EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withAlpha(30)),
      ),
      child: child,
    );
  }

  Widget _buildEmptyState(String msg, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          msg,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(value.toStringAsFixed(2), style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: cs.primary,
              inactiveTrackColor: cs.outline.withAlpha(40),
              thumbColor: cs.primary,
              overlayColor: cs.primary.withAlpha(30),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  void _showAddServerDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final endpointController = TextEditingController();
    String transport = 'http';

    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.outline.withAlpha(40)),
          ),
          title: Text('添加 MCP 服务节点', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: '名称 (例如 Home Assistant)',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline.withAlpha(60))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: transport,
                dropdownColor: cs.surface,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: '传输协议',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                ),
                items: const [
                  DropdownMenuItem(value: 'http', child: Text('HTTP / SSE 端点')),
                  DropdownMenuItem(value: 'stdio', child: Text('本地标准输入输出')),
                  DropdownMenuItem(value: 'mqtt', child: Text('MQTT 桥接器')),
                ],
                onChanged: (val) => transport = val ?? 'http',
              ),
              TextField(
                controller: endpointController,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: '端点 URL / 本地执行命令路径',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline.withAlpha(60))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.white),
              onPressed: () {
                final entry = McpServerEntry(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  transport: transport,
                  endpoint: endpointController.text.trim(),
                  auth: 'none',
                );
                ref.read(capabilityRegistryProvider.notifier).addServer(entry);
                Navigator.pop(context);
              },
              child: const Text('添加节点'),
            ),
          ],
        );
      },
    );
  }

  void _showAddSkillDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final endpointController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.outline.withAlpha(40)),
          ),
          title: Text('安装核心技能', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: '技能标识符 (例如 ui-style-minimal)',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline.withAlpha(60))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)),
                ),
              ),
              TextField(
                controller: descController,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: '技能描述',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline.withAlpha(60))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)),
                ),
              ),
              TextField(
                controller: endpointController,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: '技能端点 / 注册表路径',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline.withAlpha(60))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.secondary, foregroundColor: Colors.white),
              onPressed: () {
                final entry = AgentSkillEntry(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  endpoint: endpointController.text.trim(),
                );
                ref.read(agentSkillRegistryProvider.notifier).addSkill(entry);
                Navigator.pop(context);
              },
              child: const Text('安装'),
            ),
          ],
        );
      },
    );
  }

  void _showLlmConfigDialog(BuildContext context, WidgetRef ref, LlmConfig config) {
    final baseUrlController = TextEditingController(text: config.baseUrl);
    final apiKeyController = TextEditingController(text: config.apiKey);
    final modelController = TextEditingController(text: config.model);
    String provider = config.provider;

    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: cs.outline.withAlpha(40)),
              ),
              title: Text('配置本地 LLM 引擎', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: provider,
                      dropdownColor: cs.surface,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: '服务商',
                        labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
                        DropdownMenuItem(value: 'openai', child: Text('OpenAI API (或兼容的端点)')),
                        DropdownMenuItem(value: 'claude', child: Text('Claude / Anthropic')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          provider = val ?? 'gemini';
                        });
                      },
                    ),
                    if (provider != 'gemini')
                      TextField(
                        controller: baseUrlController,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Base URL (可选)',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline.withAlpha(60))),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)),
                        ),
                      ),
                    TextField(
                      controller: apiKeyController,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'API Token 密钥',
                        labelStyle: TextStyle(color: cs.onSurfaceVariant),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline.withAlpha(60))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)),
                      ),
                      obscureText: true,
                    ),
                    TextField(
                      controller: modelController,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: '模型标识符名称',
                        labelStyle: TextStyle(color: cs.onSurfaceVariant),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline.withAlpha(60))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.white),
                  onPressed: () {
                    final updatedConfig = config.copyWith(
                      provider: provider,
                      baseUrl: baseUrlController.text.trim(),
                      apiKey: apiKeyController.text.trim(),
                      model: modelController.text.trim(),
                    );
                    ref.read(llmConfigProvider.notifier).setConfig(updatedConfig);
                    Navigator.pop(context);
                  },
                  child: const Text('保存设置'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showClearHistoryConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.redAccent, width: 0.5),
          ),
          title: Text('清空历史对话', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
          content: Text(
            '确定要清空所有的历史对话记录吗？此操作不可逆。',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                ref.read(chatHistoryProvider.notifier).clearHistory();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('历史对话记录已清空')),
                );
              },
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
  }

  List<String> _extractComponents(Map<String, dynamic> node) {
    final list = <String>[];
    final comp = node['component'] as String?;
    if (comp != null) list.add(comp);
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          list.addAll(_extractComponents(child));
        }
      }
    }
    return list;
  }

  void _showHistoryDetailDialog(BuildContext context, WidgetRef ref, ChatHistoryEntry entry) {
    final componentsList = entry.uiTree != null ? _extractComponents(entry.uiTree!) : <String>[];

    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.outline.withAlpha(40)),
          ),
          title: Row(
            children: [
              Icon(Icons.history_toggle_off, color: cs.primary),
              const SizedBox(width: 10),
              Text('对话详情', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('用户指令', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.userMessage,
                    style: TextStyle(color: cs.onSurface, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),
                Text('助手回复', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (entry.textReply != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      entry.textReply!,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.4),
                    ),
                  )
                else
                  Text(
                    componentsList.isNotEmpty
                        ? '界面输出: ${componentsList.join(" ➔ ")}'
                        : '（无文字回复）',
                    style: TextStyle(color: cs.onSurfaceVariant.withAlpha(100), fontSize: 13),
                  ),
                if (entry.uiTree != null) ...[
                  const SizedBox(height: 20),
                  Text('卡片数据细节', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withAlpha(30)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(entry.uiTree),
                        style: TextStyle(color: Colors.green.shade400, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '时间: ${_formatDateTime(entry.timestamp)}',
                  style: TextStyle(color: cs.onSurfaceVariant.withAlpha(120), fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('关闭', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            if (entry.uiTree != null || entry.textReply != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.restore_page_outlined, size: 18),
                label: const Text('应用并返回'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ref.read(latestUiTreeProvider.notifier).state =
                      entry.uiTree != null ? UiNode.fromJson(entry.uiTree!) : null;
                  ref.read(latestTextReplyProvider.notifier).state = entry.textReply;
                  Navigator.pop(context);
                  context.go('/');
                },
              ),
          ],
        );
      },
    );
  }

  void _showPairingDialog(BuildContext context, WidgetRef ref, A2AAgentEntry agent) {
    final controller = TextEditingController(text: agent.pairingToken ?? '');
    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.secondary.withAlpha(60)),
          ),
          title: Text(
            '配对节点: ${agent.name}',
            style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '请输入该无界面守护节点启动时控制台输出的配对 Token：',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: TextStyle(color: cs.onSurface, fontFamily: 'Courier', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Pairing Token (UUID)',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant.withAlpha(80)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outline.withAlpha(40)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.secondary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                ref.read(a2aAgentRegistryProvider.notifier).updatePairingToken(agent.id, controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已更新节点 "${agent.name}" 的配对 Token')),
                );
              },
              child: const Text('保存并配对'),
            ),
          ],
        );
      },
    );
  }
}
