import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../agent/chat_provider.dart';
import '../voice/stt_service.dart';
import '../genui/surface/genui_surface.dart';
import '../genui/catalog/theme_tokens.dart';
import '../config/capability_registry.dart';
import '../agent/discovery_service.dart';
import '../agent/bridge_service.dart';
import '../agent/local_agent_service.dart';
import '../agent/hitl_provider.dart';
import '../genui/surface/ui_node.dart';
import '../voice/tts_service.dart';
import '../config/tts_config.dart';
import '../voice/voice_waveform.dart';

class IntegratedMainPage extends ConsumerStatefulWidget {
  const IntegratedMainPage({super.key});

  @override
  ConsumerState<IntegratedMainPage> createState() => _IntegratedMainPageState();
}

class _IntegratedMainPageState extends ConsumerState<IntegratedMainPage> with TickerProviderStateMixin {
  final _textController = TextEditingController();
  bool _isKeyboardMode = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  late DiscoveryService _discoveryService;
  late BridgeService _bridgeService;

  @override
  void initState() {
    super.initState();
    _discoveryService = ref.read(discoveryServiceProvider);
    _bridgeService = ref.read(bridgeServiceProvider);
    
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // Sync STT text
    ref.listenManual(recognizedTextProvider, (previous, next) {
      if (!_isKeyboardMode && next.isNotEmpty) {
        _textController.text = next;
      }
    });

    // Auto submit on STT stop
    ref.listenManual(isListeningProvider, (previous, next) {
      if (next == true) {
        if (ref.read(isChatLoadingProvider)) {
          ref.read(chatProvider.notifier).cancelCurrentTask();
        }
        _pulseController.duration = const Duration(milliseconds: 600);
        _pulseController.repeat(reverse: true);
      } else {
        if (previous == true && _textController.text.trim().isNotEmpty) {
          _submit();
        }
        _pulseController.duration = const Duration(seconds: 3);
        _pulseController.repeat(reverse: true);
      }
    });

    ref.listenManual(latestTextReplyProvider, (previous, next) {
      if (next != null && next.isNotEmpty) {
        final ttsConfig = ref.read(ttsConfigProvider);
        if (ttsConfig.enabled) {
          ref.read(ttsServiceProvider).speak(next);
        }
      }
    });

    // Auto start cluster scanning at startup (unless running in web or widget tests)
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_discoveryService.isScanning) {
          _discoveryService.startScanning();
          _bridgeService.startBridging();
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _discoveryService.stopScanning();
    _bridgeService.stopBridging();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    ref.read(ttsServiceProvider).stop();
    setState(() => _isKeyboardMode = false);
    
    try {
      await ref.read(chatProvider.notifier).sendMessage(text);
      _textController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _submitAction(String command) async {
    ref.read(ttsServiceProvider).stop();
    setState(() => _isKeyboardMode = false);
    try {
      await ref.read(chatProvider.notifier).sendMessage(command);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作执行失败: $e')));
      }
    }
  }

  void _reset() {
    ref.read(sttServiceProvider).stopListening();
    ref.read(ttsServiceProvider).stop();
    _textController.clear();
    ref.read(latestUiTreeProvider.notifier).state = null;
    ref.read(latestTextReplyProvider.notifier).state = null;
    ref.read(chatProvider.notifier).state = null;
  }

  void _showDispatchDialog(A2AAgentEntry agent) {
    final taskController = TextEditingController();
    bool dialogLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E0E18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF00F0FF), width: 0.5),
              ),
              title: Row(
                children: [
                  const Icon(Icons.send_outlined, color: Color(0xFF00F0FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '调度任务给 ${agent.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: dialogLoading
                  ? const SizedBox(
                      height: 100,
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF00F0FF)),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '向该集群节点发送指令或提示词。它将执行任务并返回生成的界面/回复。',
                          style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: taskController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: '输入任务指令...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withAlpha(10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          maxLines: 3,
                          autofocus: true,
                        ),
                      ],
                    ),
              actions: dialogLoading
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('取消', style: TextStyle(color: Colors.white.withAlpha(150))),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F0FF),
                          foregroundColor: const Color(0xFF090A10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final task = taskController.text.trim();
                          if (task.isEmpty) return;

                          setDialogState(() {
                            dialogLoading = true;
                          });

                          try {
                            final rawResult = await ref.read(localAgentProvider).invokeA2AAgent(agent.id, task);
                            final Map<String, dynamic> result = jsonDecode(rawResult);

                            // Update providers on success
                            if (result.containsKey('reply')) {
                              ref.read(latestTextReplyProvider.notifier).state = result['reply'];
                            }
                            if (result.containsKey('uiTree') && result['uiTree'] != null) {
                              final node = UiNode.fromJson(result['uiTree'] as Map<String, dynamic>);
                              ref.read(latestUiTreeProvider.notifier).state = node;
                            }

                            if (mounted) {
                              Navigator.pop(context); // Close dialog
                              Navigator.pop(context); // Close drawer
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('成功在 ${agent.name} 调度了任务')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() {
                                dialogLoading = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('调度失败: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('发送'),
                      ),
                    ],
            );
          },
        );
      },
    ).then((_) => taskController.dispose());
  }

  Widget _buildEmptyNodesState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar_outlined, size: 48, color: const Color(0xFF00F0FF).withAlpha(50)),
          const SizedBox(height: 16),
          const Text(
            '正在搜索集群节点',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '正在扫描本地网络以发现其他活跃的 AIOS 设备...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F0FF)),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentTile(A2AAgentEntry agent) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Text(
          agent.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              agent.endpoint,
              style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('在线', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
              ],
            ),
          ],
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF00F0FF).withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF00F0FF).withAlpha(50)),
          ),
          child: IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF00F0FF), size: 18),
            tooltip: '调度任务',
            onPressed: () => _showDispatchDialog(agent),
          ),
        ),
      ),
    );
  }

  Widget _buildClusterDrawer() {
    final a2aAgents = ref.watch(a2aAgentRegistryProvider);
    final isScanning = ref.watch(discoveryServiceProvider).isScanning;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF090A15).withAlpha(220),
            border: const Border(right: BorderSide(color: Color(0xFF00F0FF), width: 0.5)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      _RadarPulse(active: isScanning),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AIOS 智能集群',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '去中心化智能体网格',
                              style: TextStyle(color: Color(0xFF00F0FF), fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),

                // Cluster Nodes list title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '已发现节点',
                        style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                      Text(
                        '${a2aAgents.length} 个在线',
                        style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Nodes List
                Expanded(
                  child: a2aAgents.isEmpty
                      ? _buildEmptyNodesState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          itemCount: a2aAgents.length,
                          itemBuilder: (context, index) {
                            final agent = a2aAgents[index];
                            return _buildAgentTile(agent);
                          },
                        ),
                ),

                // Footer stats
                const Divider(color: Colors.white10),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本地端点:',
                        style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'http://localhost (mDNS 广播中)',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isListening = ref.watch(isListeningProvider);
    final isLoading = ref.watch(isChatLoadingProvider);
    final uiTree = ref.watch(latestUiTreeProvider);
    final textReply = ref.watch(latestTextReplyProvider);

    final hasResult = uiTree != null || textReply != null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF090A10),
      drawer: _buildClusterDrawer(),
      body: Stack(
        children: [
          // Main column layout
          Column(
            children: [
              _buildTopBar(hasResult, isListening, isLoading),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      if (!hasResult) ...[
                        if (isListening)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                            child: VoiceWaveformWidget(isListening: isListening),
                          )
                        else
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            width: 240,
                            height: 240,
                            child: _buildGlowingSphere(),
                          ),
                        const SizedBox(height: 20),
                        // Status text
                        _buildStatusText(isListening, isLoading),
                        const SizedBox(height: 16),
                      ],

                      // Transcribed text (only when no result yet)
                      if (!hasResult && _textController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            '"${_textController.text}"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white, fontSize: 22,
                              fontWeight: FontWeight.bold, height: 1.4,
                            ),
                          ),
                        ),

                      // Action pills (only when idle)
                      if (!hasResult && !isLoading) ...[
                        const SizedBox(height: 32),
                        _buildActionPills(),
                      ],

                      // The generated UI result
                      if (hasResult) ...[
                        const SizedBox(height: 16),
                        _buildResultCard(uiTree, textReply),
                      ],

                      const SizedBox(height: 120), // space above bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom control bar (always visible at bottom)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40, left: 32, right: 32, top: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF090A10),
                    const Color(0xFF090A10).withAlpha(240),
                    Colors.transparent,
                  ],
                ),
              ),
              child: _isKeyboardMode && !hasResult
                  ? _buildTextInput()
                  : _buildBottomControls(isListening, hasResult),
            ),
          ),

          // HITL Confirmation Overlay
          _buildHitlOverlay(),
        ],
      ),
    );
  }

  Widget _buildHitlOverlay() {
    final hitlRequest = ref.watch(hitlProvider);
    if (hitlRequest == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // consume taps
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ),
          ),
          // Dialog container
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(28),
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 450),
              decoration: BoxDecoration(
                color: const Color(0xFF161824).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                  BoxShadow(
                    color: const Color(0xFF7C5CFF).withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C5CFF).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.security_outlined,
                          color: Color(0xFF8B6CFF),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          hitlRequest.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Agent 请求执行以下操作。为了您的安全，请核对命令/脚本内容：',
                    style: TextStyle(
                      color: Color(0xFFA0A5C0),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          hitlRequest.details,
                          style: const TextStyle(
                            color: Color(0xFFE2E4F0),
                            fontFamily: 'Courier',
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA0A5C0),
                          side: BorderSide(color: Colors.white.withOpacity(0.12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          ref.read(hitlProvider.notifier).reject();
                        },
                        child: const Text('拒绝并中止'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C5CFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          elevation: 8,
                          shadowColor: const Color(0xFF7C5CFF).withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          ref.read(hitlProvider.notifier).approve();
                        },
                        child: const Text('允许运行'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool hasResult, bool isListening, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.only(top: 50, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00F0FF).withAlpha(15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00F0FF).withAlpha(50)),
            ),
            child: IconButton(
              icon: const Icon(Icons.hub_outlined, color: Color(0xFF00F0FF)),
              tooltip: '智能集群侧栏',
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
          ),
          Row(
            children: [
              if (hasResult) ...[
                _buildMiniGlowingSphere(isListening, isLoading),
                const SizedBox(width: 12),
              ],
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                  tooltip: '设置',
                  onPressed: () => context.push('/config'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniGlowingSphere(bool isListening, bool isLoading) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        Color color1 = const Color(0xFFE0F7FA);
        Color color2 = const Color(0xFF4FC3F7);
        if (isLoading) {
          color1 = Colors.amber.shade100;
          color2 = Colors.amber;
        } else if (isListening) {
          color1 = Colors.greenAccent.shade100;
          color2 = Colors.greenAccent;
        }
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color1,
                  color2,
                  color2.withAlpha(100),
                  Colors.transparent,
                ],
                stops: const [0.1, 0.4, 0.8, 1.0],
               ),
               boxShadow: [
                 BoxShadow(
                   color: color2.withAlpha(80),
                   blurRadius: 10,
                   spreadRadius: 2,
                 ),
               ],
             ),
           ),
         );
       },
     );
   }

  Widget _buildGlowingSphere() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFE0F7FA),
                  Color(0xFF4FC3F7),
                  Color(0xFF0288D1),
                  Colors.transparent,
                ],
                stops: [0.1, 0.4, 0.8, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4FC3F7).withAlpha(100),
                  blurRadius: 80, spreadRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusText(bool isListening, bool isLoading) {
    String text;
    if (isLoading) {
      text = '思考中...';
    } else if (isListening) {
      text = '正在聆听...';
    } else {
      text = '准备就绪';
    }
    return Text(text,
      style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildActionPills() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionPill(icon: Icons.calendar_month, label: '日程', onTap: () {
          _textController.text = '帮我看看今天的日程';
          _submit();
        }),
        const SizedBox(width: 12),
        _ActionPill(icon: Icons.alarm, label: '提醒', onTap: () {
          _textController.text = '设置一个提醒';
          _submit();
        }),
        const SizedBox(width: 12),
        _ActionPill(icon: Icons.assignment, label: '总结', onTap: () {
          _textController.text = '帮我总结一下今天';
          _submit();
        }),
      ],
    );
  }

  Widget _buildResultCard(UiNode? uiTree, String? textReply) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(25)),
            ),
            child: uiTree != null
                ? GenUiSurface(
                    root: uiTree,
                    theme: ThemeTokens.minimal,
                    onEvent: (action, payload) {
                      final payloadJson = jsonEncode(payload);
                      final command = '执行操作: $action, 数据: $payloadJson';
                      _submitAction(command);
                    },
                  )
                : Text(
                    textReply ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(bool isListening, bool hasResult) {
    if (hasResult) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircularIconButton(icon: Icons.close, onPressed: _reset),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircularIconButton(
          icon: Icons.keyboard_alt_outlined,
          onPressed: () => setState(() => _isKeyboardMode = true),
        ),
        GestureDetector(
          onTap: () {
            if (isListening) {
              ref.read(sttServiceProvider).stopListening();
            } else {
              _textController.clear();
              ref.read(sttServiceProvider).startListening();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening
                  ? const Color(0xFFE0F7FA)
                  : const Color(0xFFE0F7FA).withAlpha(200),
              boxShadow: isListening ? [
                BoxShadow(color: const Color(0xFFE0F7FA).withAlpha(150), blurRadius: 40, spreadRadius: 10)
              ] : [],
            ),
            child: const Icon(Icons.mic, size: 32, color: Color(0xFF090A10)),
          ),
        ),
        _CircularIconButton(icon: Icons.close, onPressed: _reset),
      ],
    );
  }

  Widget _buildTextInput() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.white.withAlpha(15), shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.mic, color: Colors.white70),
            onPressed: () => setState(() => _isKeyboardMode = false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '输入文字指令...',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withAlpha(20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onSubmitted: (_) => _submit(),
            autofocus: true,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: const BoxDecoration(color: Color(0xFF00F0FF), shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF090A10)),
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionPill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF00F0FF)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _CircularIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(color: Colors.white.withAlpha(15), shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: Colors.white70), onPressed: onPressed),
    );
  }
}

class _RadarPulse extends StatefulWidget {
  final bool active;
  const _RadarPulse({required this.active});

  @override
  State<_RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<_RadarPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _RadarPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.active)
              ...List.generate(3, (index) {
                final progress = (_controller.value + index / 3) % 1.0;
                return Container(
                  width: 36 * progress,
                  height: 36 * progress,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00F0FF).withOpacity(1.0 - progress),
                      width: 1.5,
                    ),
                  ),
                );
              }),
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF00F0FF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0xFF00F0FF), blurRadius: 8, spreadRadius: 1),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
