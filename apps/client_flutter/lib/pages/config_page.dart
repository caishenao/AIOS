import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../config/capability_registry.dart';
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
    final theme = Theme.of(context);

    final cyberPrimary = const Color(0xFF00F0FF);
    final cyberSecondary = const Color(0xFF8A2BE2);
    final cyberAccent = const Color(0xFFFF007F); // Neon Pink
    final bgDark = const Color(0xFF090A10);
    final cardBg = const Color(0xFF121320);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: const Text(
          'AIOS 控制中心',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: cyberPrimary.withAlpha(40),
            height: 1,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Section 1: LLM Engine Config
          _buildSectionHeader('LLM 认知核心', cyberPrimary, context, 
            trailing: IconButton(
              icon: Icon(Icons.edit_note, color: cyberPrimary),
              onPressed: () => _showLlmConfigDialog(context, ref, llmConfig),
            ),
          ),
          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cyberPrimary.withAlpha(40)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              title: Text(
                llmConfig.provider.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  '模型: ${llmConfig.model}',
                  style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(150), fontFamily: 'monospace'),
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cyberPrimary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology, color: cyberPrimary),
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Section 2: Form Factor
          _buildSectionHeader('设备形态', cyberSecondary, context),
          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cyberSecondary.withAlpha(40)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DeviceFormFactor>(
                  isExpanded: true,
                  value: formFactor,
                  dropdownColor: cardBg,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  items: DeviceFormFactor.values.map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.name.toUpperCase(), style: const TextStyle(letterSpacing: 1.5, fontSize: 13)),
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
          const SizedBox(height: 32),
          
          // Section 3: MCP Servers Config
          _buildSectionHeader(
            '模型上下文协议 (MCP)', 
            cyberAccent, 
            context,
            trailing: IconButton(
              icon: Icon(Icons.add_box_outlined, color: cyberAccent),
              onPressed: () => _showAddServerDialog(context, ref),
            ),
          ),
          if (servers.isEmpty)
            _buildEmptyState('未注册任何活跃的 MCP 服务。', cyberAccent)
          else
            for (final server in servers)
              Dismissible(
                key: ValueKey(server.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.redAccent.withAlpha(180),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_sweep, color: Colors.white),
                ),
                onDismissed: (_) {
                  ref.read(capabilityRegistryProvider.notifier).removeServer(server.id);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已移除 ${server.name}')));
                },
                child: Card(
                  color: cardBg,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cyberAccent.withAlpha(30)),
                  ),
                  child: ListTile(
                    title: Text(server.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(
                      '${server.transport.toUpperCase()} • ${server.endpoint}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(140), fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.api_outlined, color: Colors.greenAccent),
                  ),
                ),
              ),
          const SizedBox(height: 32),
          
          // Section 4: Skills Catalog
          _buildSectionHeader(
            '智能体核心技能', 
            cyberSecondary, 
            context,
            trailing: IconButton(
              icon: Icon(Icons.add_box_outlined, color: cyberSecondary),
              onPressed: () => _showAddSkillDialog(context, ref),
            ),
          ),
          if (skills.isEmpty)
            _buildEmptyState('未加载任何本地技能。', cyberSecondary)
          else
            for (final skill in skills)
              Dismissible(
                key: ValueKey(skill.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.redAccent.withAlpha(180),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_sweep, color: Colors.white),
                ),
                onDismissed: (_) {
                  ref.read(agentSkillRegistryProvider.notifier).removeSkill(skill.id);
                },
                child: Card(
                  color: cardBg,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cyberSecondary.withAlpha(30)),
                  ),
                  child: ListTile(
                    title: Text(skill.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(skill.description, style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(140))),
                    trailing: Icon(Icons.offline_bolt_outlined, color: cyberSecondary),
                  ),
                ),
              ),
          const SizedBox(height: 32),
          
          // Section 5: A2A Cluster
          _buildSectionHeader(
            '去中心化集群 (A2A)', 
            cyberPrimary, 
            context,
            trailing: Row(
              children: [
                if (isScanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F0FF)),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    isScanning ? Icons.portable_wifi_off : Icons.wifi_find,
                    color: cyberPrimary,
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
              cyberPrimary,
            )
          else
            for (final agent in a2aAgents)
              Dismissible(
                key: ValueKey(agent.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.redAccent.withAlpha(180),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_sweep, color: Colors.white),
                ),
                onDismissed: (_) {
                  ref.read(a2aAgentRegistryProvider.notifier).removeAgent(agent.id);
                },
                child: Card(
                  color: cardBg,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cyberPrimary.withAlpha(40)),
                  ),
                  child: ListTile(
                    title: Text(agent.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(
                      '${agent.endpoint}\n${agent.description}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(140)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (agent.pairingToken != null && agent.pairingToken!.isNotEmpty) ...[
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => _showPairingDialog(context, ref, agent),
                            child: const Text('已配对', style: TextStyle(color: Colors.green, fontSize: 12)),
                          ),
                        ] else ...[
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => _showPairingDialog(context, ref, agent),
                            child: const Text('未配对', style: TextStyle(color: Colors.orange, fontSize: 12)),
                          ),
                        ],
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.redAccent.withAlpha(160)),
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
          const SizedBox(height: 32),

          // Section 6: Voice Config
          _buildSectionHeader('语音播报与配置', cyberPrimary, context),
          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cyberPrimary.withAlpha(40)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('自动语音播报', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('在收到智能体回复时自动朗读', style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 11)),
                    value: ttsConfig.enabled,
                    activeColor: cyberPrimary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => ref.read(ttsConfigProvider.notifier).setEnabled(val),
                  ),
                  const Divider(color: Colors.white10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('播报语言', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: ttsConfig.language,
                            dropdownColor: cardBg,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  const Divider(color: Colors.white10),
                  _buildSliderRow('语速', ttsConfig.rate, 0.1, 1.0, (val) {
                    ref.read(ttsConfigProvider.notifier).setRate(val);
                  }, cyberPrimary),
                  const Divider(color: Colors.white10),
                  _buildSliderRow('音高', ttsConfig.pitch, 0.5, 2.0, (val) {
                    ref.read(ttsConfigProvider.notifier).setPitch(val);
                  }, cyberPrimary),
                  const Divider(color: Colors.white10),
                  _buildSliderRow('音量', ttsConfig.volume, 0.0, 1.0, (val) {
                    ref.read(ttsConfigProvider.notifier).setVolume(val);
                  }, cyberPrimary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Section 7: Render Backend Config
          _buildSectionHeader('UI 渲染后端', cyberSecondary, context),
          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cyberSecondary.withAlpha(40)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('渲染引擎模式', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<RenderBackendType>(
                      value: ref.watch(activeRenderBackendTypeProvider),
                      dropdownColor: cardBg,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: RenderBackendType.json, child: Text('JSON (Dynamic Catalog)')),
                        DropdownMenuItem(value: RenderBackendType.rfw, child: Text('RFW (Remote Flutter Widgets)')),
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color accentColor, BuildContext context, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(15)),
      ),
      child: Center(
        child: Text(
          msg,
          style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 13),
        ),
      ),
    );
  }

  void _showAddServerDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final endpointController = TextEditingController();
    String transport = 'http';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E0E18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00F0FF), width: 0.5),
          ),
          title: const Text('添加 MCP 服务节点', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '名称 (例如 Home Assistant)',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withAlpha(30))),
                ),
              ),
              DropdownButtonFormField<String>(
                value: transport,
                dropdownColor: const Color(0xFF0E0E18),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '传输协议',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '端点 URL / 本地执行命令路径',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withAlpha(30))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: Colors.white.withAlpha(150))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00F0FF), foregroundColor: Colors.black),
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
        return AlertDialog(
          backgroundColor: const Color(0xFF0E0E18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF8A2BE2), width: 0.5),
          ),
          title: const Text('安装核心技能', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '技能标识符 (例如 ui-style-minimal)',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withAlpha(30))),
                ),
              ),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '技能描述',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withAlpha(30))),
                ),
              ),
              TextField(
                controller: endpointController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '技能端点 / 注册表路径',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withAlpha(30))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: Colors.white.withAlpha(150))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8A2BE2), foregroundColor: Colors.white),
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
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E0E18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF00F0FF), width: 0.5),
              ),
              title: const Text('配置本地 LLM 引擎', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: provider,
                      dropdownColor: const Color(0xFF0E0E18),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: '服务商',
                        labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
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
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Base URL (可选)',
                          labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withAlpha(30))),
                        ),
                      ),
                    TextField(
                      controller: apiKeyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'API Token 密钥',
                        labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withAlpha(30))),
                      ),
                      obscureText: true,
                    ),
                    TextField(
                      controller: modelController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: '模型标识符名称',
                        labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withAlpha(30))),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消', style: TextStyle(color: Colors.white.withAlpha(150))),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00F0FF), foregroundColor: Colors.black),
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

  Widget _buildSliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged, Color activeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(value.toStringAsFixed(2), style: TextStyle(color: activeColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: activeColor,
              inactiveTrackColor: Colors.white10,
              thumbColor: activeColor,
              overlayColor: activeColor.withAlpha(40),
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

  void _showPairingDialog(BuildContext context, WidgetRef ref, A2AAgentEntry agent) {
    final controller = TextEditingController(text: agent.pairingToken ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161824),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: const Color(0xFF7C5CFF).withOpacity(0.3)),
          ),
          title: Text(
            '配对节点: ${agent.name}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '请输入该无界面守护节点启动时控制台输出的配对 Token：',
                style: TextStyle(color: Color(0xFFA0A5C0), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Pairing Token (UUID)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7C5CFF)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Color(0xFFA0A5C0))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C5CFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
