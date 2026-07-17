import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import '../genui/surface/ui_node.dart';
import '../config/llm_config.dart';
import '../config/capability_registry.dart';
import 'ui_skills.dart';
import 'user_profile_provider.dart';
import 'screen_parser.dart';
import 'screen_structure.dart';
import 'hitl_provider.dart';
import 'package:flutter/foundation.dart';


final localAgentProvider = Provider<LocalAgentService>((ref) {
  return LocalAgentService(ref);
});

class LocalAgentService {
  final Ref ref;
  gemini.ChatSession? _geminiSession;
  List<Map<String, dynamic>> _messageHistory = [];
  CancelableOperation<AgentResponse>? _currentTask;
  String _cachedLocationContext = "Location: Unknown";
  String _cachedWeatherContext = "Weather: Unknown";
  DateTime? _lastCacheTime;

  LocalAgentService(this.ref);

  String _getSystemInstruction() {
    final profileFacts = ref.read(userProfileProvider);
    final profileStr = profileFacts.isEmpty 
        ? "No user profile facts known yet." 
        : profileFacts.map((f) => "- $f").join("\n");

    final now = DateTime.now();
    final timeStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} (星期${['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1]})";

    final meshNodes = ref.read(a2aAgentRegistryProvider);
    final meshStr = meshNodes.isEmpty
        ? "No headless daemons or peer agents discovered in the local network yet."
        : meshNodes.map((n) {
            var nodeStr = "- Node ID: ${n.id}, Name: ${n.name}, Endpoint: ${n.endpoint}, Capabilities: ${n.skills.join(', ')}";
            if (n.devices.isNotEmpty) {
              nodeStr += "\n  Connected IoT Devices:\n" + n.devices.map((d) => "    * Device ID: ${d['id']}, Name: ${d['name']}, Type: ${d['type']}, State: ${d['state'] ?? d['temperature'] ?? d['target_temp'] ?? ''}").join("\n");
            }
            return nodeStr;
          }).join("\n");

    return '''
You are Home Steward, a smart home AI assistant.
You can answer user questions directly in plain text.

<SystemContext>
- Current Time: $timeStr
- $_cachedLocationContext
- $_cachedWeatherContext
</SystemContext>

<DiscoveredClusterNodes>
$meshStr
</DiscoveredClusterNodes>

<UserProfile>
$profileStr
</UserProfile>
If you learn new preferences, routines, or facts about the user from this conversation, use the `update_memory` tool to save them. This helps you build a long-term user profile.

If the user asks for a UI (like weather, device controls, or a dashboard), or if a visual interface is better, you MUST use the `render_ui` tool to generate an A2UI compliant JSON tree.
Available components:
- `InfoCard` (props: title, body)
- `WeatherCard` (props: location, temp, condition)
- `DeviceTile` (props: name, state, type, controllable)
- `MediaPlayer` (props: streamUrl, type, title, poster, variant)
- `EmailDashboard` (props: emails: Array<{id, sender, subject, snippet, date, read}>, unreadCount, selectedEmailId)
- `MapNavigation` (props: startLocation, endLocation, steps: Array<string>, etaMinutes, distanceKm, coordinates: Array<[longitude, latitude]> of route points)
- `ProductCard` (props: title, price, description, imageUrl, buyUrl, buttonText)
- `ConfirmDialog` (props: title, message, confirmAction, cancelAction, confirmText, cancelText, payload: Map)
- `MetricChart` (props: title, subtitle, kind: 'line' | 'bar', series: Array<{label: string, value: number, color?: string}>)
- `ListView`, `Row`, `Column` (props: children)

If a task requires another agent, use the `call_a2a_agent` tool.

You also have the `get_screen_structure` tool, which parses the active screen UI structure into a clean JSON tree.
- Prefer `get_screen_structure` over screenshot-based VLM understanding when you need to find text, buttons, input fields, or their positions on the screen. It is extremely fast and returns compact UI node coordinates.
- Use coordinates to interact with elements via simulation tools.

${UiSkills.combinedSkillsDoc}
''';

  }

  void cancelCurrentTask() {
    _currentTask?.cancel();
    _currentTask = null;
  }

  Future<AgentResponse> sendMessage(String text) async {
    cancelCurrentTask();
    await _updateLocationAndWeatherContext();
    final config = ref.read(llmConfigProvider);
    
    Future<AgentResponse> taskFuture;
    if (config.provider == 'gemini') {
      taskFuture = _sendGeminiMessage(text, config);
    } else if (config.provider == 'openai') {
      taskFuture = _sendOpenAIMessage(text, config);
    } else if (config.provider == 'claude') {
      taskFuture = _sendClaudeMessage(text, config);
    } else {
      taskFuture = Future.value(AgentResponse(textReply: 'Unknown provider: ${config.provider}'));
    }

    _currentTask = CancelableOperation.fromFuture(
      taskFuture,
      onCancel: () => AgentResponse(textReply: 'Task cancelled by user.'),
    );

    try {
      final response = await _currentTask!.valueOrCancellation(AgentResponse(textReply: 'Task cancelled.'));
      _currentTask = null;
      
      if (response != null && response.textReply != null) {
        final reply = response.textReply!;
        if (reply.startsWith('Error:') || 
            reply.startsWith('OpenAI API Error:') ||
            reply.startsWith('Claude API Error:') ||
            reply.contains('SocketException') || 
            reply.contains('Timeout') || 
            reply.contains('Failed host lookup')) {
          debugPrint('Detected network/LLM failure: "$reply". Falling back to local offline mode.');
          return _sendOfflineMessage(text);
        }
      }
      
      return response ?? AgentResponse(textReply: 'Task cancelled.');
    } catch (e) {
      debugPrint('Online LLM exception: $e. Falling back to local offline mode.');
      _currentTask = null;
      return _sendOfflineMessage(text);
    }
  }

  Future<AgentResponse> _sendOfflineMessage(String text) async {
    final registry = ref.read(a2aAgentRegistryProvider);
    final targetAgent = registry.isNotEmpty ? registry.first : null;
    
    if (targetAgent != null) {
      final baseUrl = targetAgent.endpoint;
      final headers = {
        'Content-Type': 'application/json',
        if (targetAgent.pairingToken != null) 'Authorization': 'Bearer ${targetAgent.pairingToken}',
      };

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/offline-chat'),
          headers: headers,
          body: jsonEncode({
            'messages': [
              {'role': 'user', 'content': text}
            ]
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choice = data['choices'][0];
          final message = choice['message'];
          final replyContent = message['content'] as String? ?? '完成';
          final toolCalls = message['tool_calls'] as List<dynamic>? ?? [];

          for (final call in toolCalls) {
            final func = call['function'];
            final name = func['name'] as String;
            final args = jsonDecode(func['arguments']) as Map<String, dynamic>;

            if (name == 'control_iot_device') {
              await _executeDaemonTool('daemon_control_iot_device', {
                'agentId': targetAgent.id,
                'deviceId': args['deviceId'],
                'action': args['action'],
              });
            } else if (name == 'get_iot_data') {
              await _executeDaemonTool('daemon_get_iot_data', {
                'agentId': targetAgent.id,
              });
            }
          }

          return AgentResponse(textReply: replyContent);
        }
      } catch (e) {
        debugPrint('Failed to query daemon offline-chat: $e. Falling back to pure client-side parser.');
      }
    }

    final cleanedText = text.toLowerCase();
    String? reply;
    
    if (targetAgent != null) {
      if (cleanedText.contains('开') && cleanedText.contains('灯')) {
        await _executeDaemonTool('daemon_control_iot_device', {
          'agentId': targetAgent.id,
          'deviceId': 'living_room_light',
          'action': 'on',
        });
        reply = '【本地应急模式】已为您打开客厅主灯。';
      } else if (cleanedText.contains('关') && cleanedText.contains('灯')) {
        await _executeDaemonTool('daemon_control_iot_device', {
          'agentId': targetAgent.id,
          'deviceId': 'living_room_light',
          'action': 'off',
        });
        reply = '【本地应急模式】已为您关闭客厅主灯。';
      } else if (cleanedText.contains('开') && cleanedText.contains('空调')) {
        await _executeDaemonTool('daemon_control_iot_device', {
          'agentId': targetAgent.id,
          'deviceId': 'bedroom_ac',
          'action': 'on',
        });
        reply = '【本地应急模式】已为您打开卧室空调。';
      } else if (cleanedText.contains('关') && cleanedText.contains('空调')) {
        await _executeDaemonTool('daemon_control_iot_device', {
          'agentId': targetAgent.id,
          'deviceId': 'bedroom_ac',
          'action': 'off',
        });
        reply = '【本地应急模式】已为您关闭卧室空调。';
      }
    }

    return AgentResponse(
      textReply: reply ?? '【本地应急模式】离线状态且无网关连接，无法执行指令。支持：开灯、关灯、开空调、关空调。',
    );
  }

  Future<String> invokeA2AAgent(String agentId, String intent) async {
    return _invokeA2AAgent(agentId, intent);
  }

  Future<String> _invokeA2AAgent(String agentId, String intent) async {
    final registry = ref.read(a2aAgentRegistryProvider);
    final targetAgent = registry.cast<A2AAgentEntry?>().firstWhere((e) => e!.id == agentId, orElse: () => null);
    
    if (targetAgent == null) {
      return 'Error: Agent with ID $agentId not found in registry.';
    }
    
    try {
      final response = await http.post(
        Uri.parse(targetAgent.endpoint),
        headers: {
          'Content-Type': 'application/json',
          if (targetAgent.auth != 'none') 'Authorization': 'Bearer ${targetAgent.auth}'
        },
        body: jsonEncode({'intent': intent}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body; 
      } else {
        return 'Error: A2A agent returned status ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      return 'Error: Failed to reach agent $agentId. Exception: $e';
    }
  }

  Map<String, dynamic> _sanitizeUiNode(Map<String, dynamic> node) {
    final sanitized = Map<String, dynamic>.from(node);
    
    if (sanitized['props'] is Map) {
      final props = Map<String, dynamic>.from(sanitized['props']);
      if (props.containsKey('children')) {
        sanitized['children'] = props.remove('children');
        sanitized['props'] = props;
      }
    }
    
    if (sanitized['children'] is List) {
      sanitized['children'] = (sanitized['children'] as List).map((child) {
        if (child is Map) return _sanitizeUiNode(Map<String, dynamic>.from(child));
        return child;
      }).toList();
    }
    return sanitized;
  }

  Future<String> _getHardwareInfo() async {
    return jsonEncode({
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'localHostname': Platform.localHostname,
      'numberOfProcessors': Platform.numberOfProcessors,
    });
  }

  Future<String> _readLocalFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return 'Error: File not found';
      return await file.readAsString();
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  Future<String> _sendExternalRequest(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      // Truncate if too long to avoid token limits
      String body = response.body;
      if (body.length > 2000) body = body.substring(0, 2000) + '... (truncated)';
      return 'Status: ${response.statusCode}\nBody: $body';
    } catch (e) {
      return 'Error sending request: $e';
    }
  }

  Future<String> _webSearch(String query) async {
    try {
      final queryEscaped = Uri.encodeComponent(query);
      final url = Uri.parse('https://html.duckduckgo.com/html/?q=$queryEscaped');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return 'Error: Search request returned status ${response.statusCode}';
      }

      final html = response.body;
      final results = <Map<String, String>>[];
      final resultBlocks = html.split('<div class="result body');
      
      for (var i = 1; i < resultBlocks.length; i++) {
        final block = resultBlocks[i];
        final urlMatch = RegExp(r'href="([^"]+)"').firstMatch(block);
        final titleMatch = RegExp(r'class="result__a"[^>]*>(.*?)</a>', dotAll: true).firstMatch(block);
        final snippetMatch = RegExp(r'class="result__snippet"[^>]*>(.*?)</a>', dotAll: true).firstMatch(block)
                          ?? RegExp(r'class="result__snippet"[^>]*>(.*?)</span>', dotAll: true).firstMatch(block);
                          
        if (urlMatch != null && titleMatch != null) {
          var link = urlMatch.group(1) ?? '';
          if (link.startsWith('//')) {
            link = 'https:$link';
          }
          if (link.contains('uddg=')) {
            final uddg = link.split('uddg=').last.split('&').first;
            link = Uri.decodeComponent(uddg);
          }
          
          final title = _decodeHtml(titleMatch.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '');
          final snippet = _decodeHtml(snippetMatch?.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '');
          
          results.add({
            'title': title,
            'url': link,
            'snippet': snippet,
          });
          if (results.length >= 5) break;
        }
      }

      if (results.isEmpty) {
        return 'No search results found for: $query';
      }

      final sb = StringBuffer('Search results for "$query":\n\n');
      for (var i = 0; i < results.length; i++) {
        final res = results[i];
        sb.writeln('${i + 1}. [${res['title']}](${res['url']})');
        sb.writeln('   ${res['snippet']}\n');
      }
      return sb.toString();
    } catch (e) {
      return 'Error performing web search: $e';
    }
  }

  String _decodeHtml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  // --- GEMINI IMPLEMENTATION ---
  Future<AgentResponse> _sendGeminiMessage(String text, LlmConfig config) async {
    final apiKey = config.apiKey.isNotEmpty ? config.apiKey : const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    
    if (_geminiSession == null) {
      final renderUiTool = gemini.Tool(
        functionDeclarations: [
          gemini.FunctionDeclaration(
            'render_ui',
            'Render a native UI on the user\'s current device surface.',
            gemini.Schema(
              gemini.SchemaType.object,
              properties: {
                'surfaceId': gemini.Schema(gemini.SchemaType.string, description: "Target surface, default 'main'"),
                'styleSkill': gemini.Schema(gemini.SchemaType.string, description: "Style skill name"),
                'root': gemini.Schema(
                  gemini.SchemaType.object, 
                  description: "The UI tree root node",
                  properties: {
                    'component': gemini.Schema(gemini.SchemaType.string),
                    'props': gemini.Schema(gemini.SchemaType.object),
                    'children': gemini.Schema(gemini.SchemaType.array, items: gemini.Schema(gemini.SchemaType.object)),
                  },
                  requiredProperties: ['component']
                ),
              },
              requiredProperties: ['surfaceId', 'root'],
            ),
          ),
          gemini.FunctionDeclaration(
            'call_a2a_agent',
            'Call another agent to complete a sub-task.',
            gemini.Schema(
              gemini.SchemaType.object,
              properties: {
                'agentId': gemini.Schema(gemini.SchemaType.string, description: "ID of the target agent"),
                'intent': gemini.Schema(gemini.SchemaType.string, description: "Intent or prompt to pass to the agent"),
              },
              requiredProperties: ['agentId', 'intent'],
            ),
          ),
          gemini.FunctionDeclaration(
            'update_memory',
            'Save a new fact or preference about the user to long-term memory.',
            gemini.Schema(
              gemini.SchemaType.object,
              properties: {
                'fact': gemini.Schema(gemini.SchemaType.string, description: "The fact to remember (e.g. 'User likes warm lights', 'User wakes up at 7am')"),
              },
              requiredProperties: ['fact'],
            ),
          ),
          gemini.FunctionDeclaration(
            'get_hardware_info',
            'Get local hardware information (OS, processors, hostname).',
            gemini.Schema(gemini.SchemaType.object, properties: {}),
          ),
          gemini.FunctionDeclaration(
            'read_local_file',
            'Read the contents of a local file.',
            gemini.Schema(
              gemini.SchemaType.object,
              properties: {
                'path': gemini.Schema(gemini.SchemaType.string, description: 'Absolute path of the file to read'),
              },
              requiredProperties: ['path'],
            ),
          ),
          gemini.FunctionDeclaration(
            'send_external_request',
            'Send an HTTP GET request to an external URL.',
            gemini.Schema(
              gemini.SchemaType.object,
              properties: {
                'url': gemini.Schema(gemini.SchemaType.string, description: 'The URL to fetch'),
              },
              requiredProperties: ['url'],
            ),
          ),
          gemini.FunctionDeclaration(
            'get_screen_structure',
            'Get the structured UI tree (JSON) of the active screen/window using the local Screen-Parser. Extremely fast (<50ms). Use this to find text, buttons, and coordinates for automation rather than capture_screen.',
            gemini.Schema(
              gemini.SchemaType.object,
              properties: {
                'mode': gemini.Schema(gemini.SchemaType.string, description: "Parse mode: 'auto', 'flutter', 'platform', 'omniparser'"),
                'windowTitle': gemini.Schema(gemini.SchemaType.string, description: 'Optional target window title to focus/parse'),
                'maxDepth': gemini.Schema(gemini.SchemaType.integer, description: 'Optional maximum tree depth, default 10'),
                'interactiveOnly': gemini.Schema(gemini.SchemaType.boolean, description: 'Optional: only return interactive elements, default false'),
              },
            ),
          ),
          gemini.FunctionDeclaration(
            'web_search',
            'Search the web for general information, current events, weather, news, or reference data.',
            gemini.Schema(
              gemini.SchemaType.object,
              properties: {
                'query': gemini.Schema(gemini.SchemaType.string, description: 'The search query to look up'),
              },
              requiredProperties: ['query'],
            ),
          ),
          ..._getPlatformToolsGemini(),
          ..._getDaemonToolsGemini(),
        ],
      );

      final model = gemini.GenerativeModel(
        model: config.model.isNotEmpty ? config.model : 'gemini-1.5-pro-latest',
        apiKey: apiKey,
        tools: [renderUiTool],
        systemInstruction: gemini.Content.system(_getSystemInstruction()),
      );
      _geminiSession = model.startChat();
    }

    try {
      var response = await _geminiSession!.sendMessage(gemini.Content.text(text));
      
      while (true) {
        if (_currentTask?.isCanceled == true) return AgentResponse(textReply: 'Cancelled');
        final functionCalls = response.functionCalls.toList();
        if (functionCalls.isEmpty) {
          return AgentResponse(textReply: response.text);
        }

        bool needAnotherCall = false;
        List<gemini.FunctionResponse> responses = [];

        for (final call in functionCalls) {
          if (call.name == 'render_ui') {
            final args = call.args;
            final rootMap = args['root'];
            UiNode? uiNode;
            try {
              if (rootMap != null && rootMap is Map) {
                 final sanitizedMap = _sanitizeUiNode(Map<String, dynamic>.from(rootMap));
                 uiNode = UiNode.fromJson(sanitizedMap);
              }
              await _geminiSession!.sendMessage(gemini.Content.functionResponse('render_ui', {'status': 'rendered'}));
              return AgentResponse(uiTree: uiNode, textReply: null);
            } catch (e) {
              responses.add(gemini.FunctionResponse('render_ui', {'error': 'Format error: $e. Use {component: string, props: {}}'}));
              needAnotherCall = true;
            }
          } else if (call.name == 'call_a2a_agent') {
            final agentId = call.args['agentId'] as String;
            final intent = call.args['intent'] as String;
            final a2aResult = await _invokeA2AAgent(agentId, intent);
            
            responses.add(gemini.FunctionResponse('call_a2a_agent', {'result': a2aResult}));
            needAnotherCall = true;
          } else if (call.name == 'update_memory') {
            final fact = call.args['fact'] as String;
            await ref.read(userProfileProvider.notifier).addFact(fact);
            responses.add(gemini.FunctionResponse('update_memory', {'status': 'Memory updated'}));
            needAnotherCall = true;
          } else if (call.name == 'get_hardware_info') {
            final info = await _getHardwareInfo();
            responses.add(gemini.FunctionResponse('get_hardware_info', {'info': info}));
            needAnotherCall = true;
          } else if (call.name == 'read_local_file') {
            final content = await _readLocalFile(call.args['path'] as String);
            responses.add(gemini.FunctionResponse('read_local_file', {'content': content}));
            needAnotherCall = true;
          } else if (call.name == 'send_external_request') {
            final result = await _sendExternalRequest(call.args['url'] as String);
            responses.add(gemini.FunctionResponse('send_external_request', {'result': result}));
            needAnotherCall = true;
          } else if (call.name == 'get_screen_structure') {
            final args = call.args;
            final modeStr = args['mode'] as String? ?? 'auto';
            final mode = ScreenParserMode.values.firstWhere(
              (m) => m.name == modeStr,
              orElse: () => ScreenParserMode.auto,
            );
            final windowTitle = args['windowTitle'] as String?;
            final maxDepth = args['maxDepth'] as int? ?? 10;
            final interactiveOnly = args['interactiveOnly'] as bool? ?? false;
            
            final parser = ref.read(screenParserProvider);
            final structure = await parser.parseCurrentScreen(
              mode: mode,
              windowTitle: windowTitle,
              maxDepth: maxDepth,
              interactiveOnly: interactiveOnly,
            );
            
            responses.add(gemini.FunctionResponse(
              'get_screen_structure',
              structure != null ? structure.toJson() : {'error': 'Failed to parse screen'},
            ));
          } else if (call.name == 'web_search') {
            final query = call.args['query'] as String? ?? '';
            final searchResult = await _webSearch(query);
            responses.add(gemini.FunctionResponse('web_search', {'result': searchResult}));
            needAnotherCall = true;
          } else if (['exec_adb', 'adb_screenshot', 'adb_click', 'exec_powershell', 'capture_screen', 'simulate_mouse', 'simulate_keyboard', 'exec_shell'].contains(call.name)) {
            final toolResult = await _executePlatformTool(call.name, Map<String, dynamic>.from(call.args));
            responses.add(gemini.FunctionResponse(call.name, toolResult));
            needAnotherCall = true;
          } else if (call.name.startsWith('daemon_')) {
            final toolResult = await _executeDaemonTool(call.name, Map<String, dynamic>.from(call.args));
            responses.add(gemini.FunctionResponse(call.name, toolResult));
            needAnotherCall = true;
          }
        }
        
        if (needAnotherCall) {
           response = await _geminiSession!.sendMessage(gemini.Content.functionResponses(responses));
           continue;
        }
      }
    } catch (e) {
      return AgentResponse(textReply: "Error: $e");
    }
  }

  // --- OPENAI IMPLEMENTATION ---
  Future<AgentResponse> _sendOpenAIMessage(String text, LlmConfig config) async {
    _messageHistory.add({'role': 'user', 'content': text});
    
    final baseUrl = config.baseUrl.isNotEmpty ? config.baseUrl : 'https://api.openai.com/v1';
    final url = Uri.parse('$baseUrl/chat/completions');

    while (true) {
      if (_currentTask?.isCanceled == true) return AgentResponse(textReply: 'Cancelled');

      final payload = {
        'model': config.model.isNotEmpty ? config.model : 'gpt-4o',
        'messages': [
          {'role': 'system', 'content': _getSystemInstruction()},
          ..._messageHistory,
        ],
        'tools': [
          {
            'type': 'function',
            'function': {
              'name': 'render_ui',
              'description': 'Render a native UI on the user\'s current device surface.',
              'parameters': {
                'type': 'object',
                'properties': {
                  'surfaceId': {'type': 'string', 'description': "Target surface, default 'main'"},
                  'styleSkill': {'type': 'string', 'description': "Style skill name"},
                  'root': {
                    'type': 'object', 
                    'description': "The UI tree root node",
                    'properties': {
                      'component': {'type': 'string'},
                      'props': {'type': 'object'},
                      'children': {
                        'type': 'array',
                        'items': {'type': 'object'}
                      }
                    },
                    'required': ['component']
                  }
                },
                'required': ['surfaceId', 'root']
              }
            }
          },
          {
            'type': 'function',
            'function': {
              'name': 'call_a2a_agent',
              'description': 'Call another agent to complete a sub-task.',
              'parameters': {
                'type': 'object',
                'properties': {
                  'agentId': {'type': 'string', 'description': "ID of the target agent"},
                  'intent': {'type': 'string', 'description': "Intent or prompt to pass to the agent"}
                },
                'required': ['agentId', 'intent']
              }
            }
          },
          {
            'type': 'function',
            'function': {
              'name': 'update_memory',
              'description': 'Save a new fact or preference about the user to long-term memory.',
              'parameters': {
                'type': 'object',
                'properties': {
                  'fact': {'type': 'string', 'description': "The fact to remember"}
                },
                'required': ['fact']
              }
            }
          },
          {
            'type': 'function',
            'function': {
              'name': 'get_hardware_info',
              'description': 'Get local hardware information (OS, processors, hostname).',
              'parameters': {
                'type': 'object',
                'properties': {}
              }
            }
          },
          {
            'type': 'function',
            'function': {
              'name': 'read_local_file',
              'description': 'Read the contents of a local file.',
              'parameters': {
                'type': 'object',
                'properties': {
                  'path': {'type': 'string', 'description': 'Absolute path of the file to read'}
                },
                'required': ['path']
              }
            }
          },
          {
            'type': 'function',
            'function': {
              'name': 'send_external_request',
              'description': 'Send an HTTP GET request to an external URL.',
              'parameters': {
                'type': 'object',
                'properties': {
                  'url': {'type': 'string', 'description': 'The URL to fetch'}
                },
                'required': ['url']
              }
            }
          },
          {
            'type': 'function',
            'function': {
              'name': 'get_screen_structure',
              'description': 'Get the structured UI tree (JSON) of the active screen/window using the local Screen-Parser. Extremely fast (<50ms). Use this to find text, buttons, and coordinates for automation rather than capture_screen.',
              'parameters': {
                'type': 'object',
                'properties': {
                  'mode': {'type': 'string', 'description': "Parse mode: 'auto', 'flutter', 'platform', 'omniparser'", 'default': 'auto'},
                  'windowTitle': {'type': 'string', 'description': 'Optional target window title to focus/parse'},
                  'maxDepth': {'type': 'integer', 'description': 'Optional maximum tree depth, default 10'},
                  'interactiveOnly': {'type': 'boolean', 'description': 'Optional: only return interactive elements, default false'},
                }
              }
            }
          },
          {
            'type': 'function',
            'function': {
              'name': 'web_search',
              'description': 'Search the web for general information, current events, weather, news, or reference data.',
              'parameters': {
                'type': 'object',
                'properties': {
                  'query': {'type': 'string', 'description': 'The search query to look up'}
                },
                'required': ['query']
              }
            }
          },
          ..._getPlatformToolsOpenAI(),
        ]
      };

      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey}',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode != 200) {
          return AgentResponse(textReply: 'OpenAI API Error: ${response.body}');
        }

        final data = jsonDecode(response.body);
        final message = data['choices'][0]['message'];
        _messageHistory.add(message);

        if (message['tool_calls'] != null) {
          bool needsAnotherCall = false;
          for (final toolCall in message['tool_calls']) {
            final function = toolCall['function'];
            if (function['name'] == 'render_ui') {
              final args = jsonDecode(function['arguments']);
              final rootMap = args['root'];
              UiNode? uiNode;
              try {
                if (rootMap != null && rootMap is Map) {
                   final sanitizedMap = _sanitizeUiNode(Map<String, dynamic>.from(rootMap));
                   uiNode = UiNode.fromJson(sanitizedMap);
                }
                _messageHistory.add({
                  'role': 'tool',
                  'tool_call_id': toolCall['id'],
                  'content': '{"status": "rendered"}',
                });
                return AgentResponse(uiTree: uiNode, textReply: null);
              } catch (e) {
                _messageHistory.add({
                  'role': 'tool',
                  'tool_call_id': toolCall['id'],
                  'content': '{"error": "Format error: $e. Node must have {component: string, props: {}}"}',
                });
                needsAnotherCall = true;
              }
            } else if (function['name'] == 'call_a2a_agent') {
              final args = jsonDecode(function['arguments']);
              final a2aResult = await _invokeA2AAgent(args['agentId'], args['intent']);
              
              _messageHistory.add({
                'role': 'tool',
                'tool_call_id': toolCall['id'],
                'content': jsonEncode({'status': 'called', 'result': a2aResult}),
              });
              needsAnotherCall = true;
            } else if (function['name'] == 'update_memory') {
              final args = jsonDecode(function['arguments']);
              await ref.read(userProfileProvider.notifier).addFact(args['fact']);
              
              _messageHistory.add({
                'role': 'tool',
                'tool_call_id': toolCall['id'],
                'content': '{"status": "Memory updated"}',
              });
              needsAnotherCall = true;
            } else if (function['name'] == 'get_hardware_info') {
              final info = await _getHardwareInfo();
              _messageHistory.add({
                'role': 'tool',
                'tool_call_id': toolCall['id'],
                'content': jsonEncode({'info': info}),
              });
              needsAnotherCall = true;
            } else if (function['name'] == 'read_local_file') {
              final args = jsonDecode(function['arguments']);
              final content = await _readLocalFile(args['path']);
              _messageHistory.add({
                'role': 'tool',
                'tool_call_id': toolCall['id'],
                'content': jsonEncode({'content': content}),
              });
              needsAnotherCall = true;
            } else if (function['name'] == 'send_external_request') {
              final args = jsonDecode(function['arguments']);
              final result = await _sendExternalRequest(args['url']);
              _messageHistory.add({
                'role': 'tool',
                'tool_call_id': toolCall['id'],
                'content': jsonEncode({'result': result}),
              });
              needsAnotherCall = true;
            } else if (function['name'] == 'get_screen_structure') {
              final args = jsonDecode(function['arguments']);
              final modeStr = args['mode'] as String? ?? 'auto';
              final mode = ScreenParserMode.values.firstWhere(
                (m) => m.name == modeStr,
                orElse: () => ScreenParserMode.auto,
              );
              final windowTitle = args['windowTitle'] as String?;
              final maxDepth = args['maxDepth'] as int? ?? 10;
              final interactiveOnly = args['interactiveOnly'] as bool? ?? false;
              
              final parser = ref.read(screenParserProvider);
              final structure = await parser.parseCurrentScreen(
                mode: mode,
                windowTitle: windowTitle,
                maxDepth: maxDepth,
                interactiveOnly: interactiveOnly,
              );
              
              _messageHistory.add({
                'role': 'tool',
                'tool_call_id': toolCall['id'],
                'content': jsonEncode(structure != null ? structure.toJson() : {'error': 'Failed to parse screen'}),
              });
              needsAnotherCall = true;
            } else if (function['name'] == 'web_search') {
              final args = jsonDecode(function['arguments']);
              final query = args['query'] as String? ?? '';
              final searchResult = await _webSearch(query);
              _messageHistory.add({
                'role': 'tool',
                'tool_call_id': toolCall['id'],
                'content': jsonEncode({'result': searchResult}),
              });
              needsAnotherCall = true;
            } else if (['exec_adb', 'adb_screenshot', 'adb_click', 'exec_powershell', 'capture_screen', 'simulate_mouse', 'simulate_keyboard', 'exec_shell'].contains(function['name'])) {
              final args = jsonDecode(function['arguments']);
              final toolResult = await _executePlatformTool(function['name'], Map<String, dynamic>.from(args));
              _messageHistory.add({
                'role': 'tool',
                'tool_call_id': toolCall['id'],
                'content': jsonEncode(toolResult),
              });
              needsAnotherCall = true;
            } else if (function['name'].startsWith('daemon_')) {
              final args = jsonDecode(function['arguments']);
              final toolResult = await _executeDaemonTool(function['name'], Map<String, dynamic>.from(args));
              _messageHistory.add({
                'role': 'tool',
                'tool_call_id': toolCall['id'],
                'content': jsonEncode(toolResult),
              });
              needsAnotherCall = true;
            }
          }
          if (needsAnotherCall) continue;
        }

        return AgentResponse(textReply: message['content']);
      } catch (e) {
        return AgentResponse(textReply: "Error: $e");
      }
    }
  }

  // --- CLAUDE IMPLEMENTATION ---
  Future<AgentResponse> _sendClaudeMessage(String text, LlmConfig config) async {
    _messageHistory.add({'role': 'user', 'content': text});
    
    final baseUrl = config.baseUrl.isNotEmpty ? config.baseUrl : 'https://api.anthropic.com/v1';
    final url = Uri.parse('$baseUrl/messages');

    while (true) {
      if (_currentTask?.isCanceled == true) return AgentResponse(textReply: 'Cancelled');

      final payload = {
        'model': config.model.isNotEmpty ? config.model : 'claude-3-5-sonnet-20240620',
        'max_tokens': 1024,
        'system': _getSystemInstruction(),
        'messages': _messageHistory,
        'tools': [
          {
            'name': 'render_ui',
            'description': 'Render a native UI on the user\'s current device surface.',
            'input_schema': {
              'type': 'object',
              'properties': {
                'surfaceId': {'type': 'string', 'description': "Target surface, default 'main'"},
                'styleSkill': {'type': 'string', 'description': "Style skill name"},
                'root': {
                'type': 'object', 
                'description': "The UI tree root node",
                'properties': {
                  'component': {'type': 'string'},
                  'props': {'type': 'object'},
                  'children': {
                    'type': 'array',
                    'items': {'type': 'object'}
                  }
                },
                'required': ['component']
              }
            },
            'required': ['surfaceId', 'root']
            }
          },
          {
            'name': 'call_a2a_agent',
            'description': 'Call another agent to complete a sub-task.',
            'input_schema': {
              'type': 'object',
              'properties': {
                'agentId': {'type': 'string', 'description': "ID of the target agent"},
                'intent': {'type': 'string', 'description': "Intent or prompt to pass to the agent"}
              },
              'required': ['agentId', 'intent']
            }
          },
          {
            'name': 'update_memory',
            'description': 'Save a new fact or preference about the user to long-term memory.',
            'input_schema': {
              'type': 'object',
              'properties': {
                'fact': {'type': 'string', 'description': "The fact to remember"}
              },
              'required': ['fact']
            }
          },
          {
            'name': 'get_hardware_info',
            'description': 'Get local hardware information (OS, processors, hostname).',
            'input_schema': {
              'type': 'object',
              'properties': {}
            }
          },
          {
            'name': 'read_local_file',
            'description': 'Read the contents of a local file.',
            'input_schema': {
              'type': 'object',
              'properties': {
                'path': {'type': 'string', 'description': 'Absolute path of the file to read'}
              },
              'required': ['path']
            }
          },
          {
            'name': 'send_external_request',
            'description': 'Send an HTTP GET request to an external URL.',
            'input_schema': {
              'type': 'object',
              'properties': {
                'url': {'type': 'string', 'description': 'The URL to fetch'}
              },
              'required': ['url']
            }
          },
          {
            'name': 'get_screen_structure',
            'description': 'Get the structured UI tree (JSON) of the active screen/window using the local Screen-Parser. Extremely fast (<50ms). Use this to find text, buttons, and coordinates for automation rather than capture_screen.',
            'input_schema': {
              'type': 'object',
              'properties': {
                'mode': {'type': 'string', 'description': "Parse mode: 'auto', 'flutter', 'platform', 'omniparser'"},
                'windowTitle': {'type': 'string', 'description': 'Optional target window title to focus/parse'},
                'maxDepth': {'type': 'integer', 'description': 'Optional maximum tree depth, default 10'},
                'interactiveOnly': {'type': 'boolean', 'description': 'Optional: only return interactive elements, default false'},
              }
            }
          },
          {
            'name': 'web_search',
            'description': 'Search the web for general information, current events, weather, news, or reference data.',
            'input_schema': {
              'type': 'object',
              'properties': {
                'query': {'type': 'string', 'description': 'The search query to look up'}
              },
              'required': ['query']
            }
          },
          ..._getPlatformToolsClaude(),
        ]
      };

      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': config.apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode != 200) {
          return AgentResponse(textReply: 'Claude API Error: ${response.body}');
        }

        final data = jsonDecode(response.body);
        
        _messageHistory.add({
          'role': 'assistant',
          'content': data['content'],
        });

        bool needsAnotherCall = false;
        List<dynamic> toolResults = [];

        for (final contentBlock in data['content']) {
          if (contentBlock['type'] == 'tool_use') {
            if (contentBlock['name'] == 'render_ui') {
              final args = contentBlock['input'];
              final rootMap = args['root'];
              UiNode? uiNode;
              try {
                if (rootMap != null && rootMap is Map) {
                   final sanitizedMap = _sanitizeUiNode(Map<String, dynamic>.from(rootMap));
                   uiNode = UiNode.fromJson(sanitizedMap);
                }
                _messageHistory.add({
                  'role': 'user',
                  'content': [
                    {
                      'type': 'tool_result',
                      'tool_use_id': contentBlock['id'],
                      'content': 'rendered'
                    }
                  ]
                });
                return AgentResponse(uiTree: uiNode, textReply: null);
              } catch (e) {
                toolResults.add({
                  'type': 'tool_result',
                  'tool_use_id': contentBlock['id'],
                  'content': 'Format error: $e. Node must have {component: string, props: {}}'
                });
                needsAnotherCall = true;
              }
            } else if (contentBlock['name'] == 'call_a2a_agent') {
              final args = contentBlock['input'];
              final a2aResult = await _invokeA2AAgent(args['agentId'], args['intent']);
              
              toolResults.add({
                'type': 'tool_result',
                'tool_use_id': contentBlock['id'],
                'content': a2aResult
              });
              needsAnotherCall = true;
            } else if (contentBlock['name'] == 'update_memory') {
              final args = contentBlock['input'];
              await ref.read(userProfileProvider.notifier).addFact(args['fact']);
              
              toolResults.add({
                'type': 'tool_result',
                'tool_use_id': contentBlock['id'],
                'content': 'Memory updated'
              });
              needsAnotherCall = true;
            } else if (contentBlock['name'] == 'get_hardware_info') {
              final info = await _getHardwareInfo();
              toolResults.add({
                'type': 'tool_result',
                'tool_use_id': contentBlock['id'],
                'content': info
              });
              needsAnotherCall = true;
            } else if (contentBlock['name'] == 'read_local_file') {
              final args = contentBlock['input'];
              final content = await _readLocalFile(args['path']);
              toolResults.add({
                'type': 'tool_result',
                'tool_use_id': contentBlock['id'],
                'content': content
              });
              needsAnotherCall = true;
            } else if (contentBlock['name'] == 'send_external_request') {
              final args = contentBlock['input'];
              final result = await _sendExternalRequest(args['url']);
              toolResults.add({
                'type': 'tool_result',
                'tool_use_id': contentBlock['id'],
                'content': result
              });
              needsAnotherCall = true;
            } else if (contentBlock['name'] == 'get_screen_structure') {
              final args = contentBlock['input'];
              final modeStr = args['mode'] as String? ?? 'auto';
              final mode = ScreenParserMode.values.firstWhere(
                (m) => m.name == modeStr,
                orElse: () => ScreenParserMode.auto,
              );
              final windowTitle = args['windowTitle'] as String?;
              final maxDepth = args['maxDepth'] as int? ?? 10;
              final interactiveOnly = args['interactiveOnly'] as bool? ?? false;
              
              final parser = ref.read(screenParserProvider);
              final structure = await parser.parseCurrentScreen(
                mode: mode,
                windowTitle: windowTitle,
                maxDepth: maxDepth,
                interactiveOnly: interactiveOnly,
              );
              
              toolResults.add({
                'type': 'tool_result',
                'tool_use_id': contentBlock['id'],
                'content': jsonEncode(structure != null ? structure.toJson() : {'error': 'Failed to parse screen'}),
              });
              needsAnotherCall = true;
            } else if (contentBlock['name'] == 'web_search') {
              final args = contentBlock['input'];
              final query = args['query'] as String? ?? '';
              final searchResult = await _webSearch(query);
              toolResults.add({
                'type': 'tool_result',
                'tool_use_id': contentBlock['id'],
                'content': searchResult
              });
              needsAnotherCall = true;
            } else if (['exec_adb', 'adb_screenshot', 'adb_click', 'exec_powershell', 'capture_screen', 'simulate_mouse', 'simulate_keyboard', 'exec_shell'].contains(contentBlock['name'])) {
              final args = contentBlock['input'];
              final toolResult = await _executePlatformTool(contentBlock['name'], Map<String, dynamic>.from(args));
              toolResults.add({
                'type': 'tool_result',
                'tool_use_id': contentBlock['id'],
                'content': jsonEncode(toolResult)
              });
              needsAnotherCall = true;
            } else if (contentBlock['name'].startsWith('daemon_')) {
              final args = contentBlock['input'];
              final toolResult = await _executeDaemonTool(contentBlock['name'], Map<String, dynamic>.from(args));
              toolResults.add({
                'type': 'tool_result',
                'tool_use_id': contentBlock['id'],
                'content': jsonEncode(toolResult)
              });
              needsAnotherCall = true;
            }
          }
        }

        if (needsAnotherCall) {
          _messageHistory.add({
            'role': 'user',
            'content': toolResults,
          });
          continue;
        }

        final textBlock = data['content'].firstWhere((c) => c['type'] == 'text', orElse: () => null);
        return AgentResponse(textReply: textBlock?['text'] ?? 'Done');
      } catch (e) {
        return AgentResponse(textReply: "Error: $e");
      }
    }
  }

  List<Map<String, dynamic>> _getPlatformToolsOpenAI() {
    final list = <Map<String, dynamic>>[];
    if (Platform.isAndroid) {
      list.add({
        'type': 'function',
        'function': {
          'name': 'exec_adb',
          'description': 'Execute an adb command to control or query the connected Android device.',
          'parameters': {
            'type': 'object',
            'properties': {
              'command': {'type': 'string', 'description': "ADB command (e.g. 'devices', 'shell pm list packages')"}
            },
            'required': ['command']
          }
        }
      });
      list.add({
        'type': 'function',
        'function': {
          'name': 'adb_screenshot',
          'description': 'Capture a screenshot of the connected Android device.',
          'parameters': {
            'type': 'object',
            'properties': {
              'output_path': {'type': 'string', 'description': 'Output path on the host, default to screenshot.png'}
            }
          }
        }
      });
      list.add({
        'type': 'function',
        'function': {
          'name': 'adb_click',
          'description': 'Simulate a click/tap at coordinates (x, y) on the Android screen.',
          'parameters': {
            'type': 'object',
            'properties': {
              'x': {'type': 'integer', 'description': 'X coordinate'},
              'y': {'type': 'integer', 'description': 'Y coordinate'}
            },
            'required': ['x', 'y']
          }
        }
      });
    } else if (Platform.isWindows) {
      list.add({
        'type': 'function',
        'function': {
          'name': 'exec_powershell',
          'description': 'Execute a PowerShell script or command on the host Windows machine.',
          'parameters': {
            'type': 'object',
            'properties': {
              'script': {'type': 'string', 'description': 'PowerShell command or script to run'}
            },
            'required': ['script']
          }
        }
      });
      list.add({
        'type': 'function',
        'function': {
          'name': 'capture_screen',
          'description': 'Capture a screenshot of the host Windows screen.',
          'parameters': {
            'type': 'object',
            'properties': {
              'output_path': {'type': 'string', 'description': 'Output path for screenshot image'}
            }
          }
        }
      });
      list.add({
        'type': 'function',
        'function': {
          'name': 'simulate_mouse',
          'description': 'Simulate mouse movement and clicks on the host Windows machine.',
          'parameters': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['move', 'click', 'double_click', 'right_click'],
                'description': 'Mouse action to perform'
              },
              'x': {'type': 'integer', 'description': 'X coordinate'},
              'y': {'type': 'integer', 'description': 'Y coordinate'}
            },
            'required': ['action', 'x', 'y']
          }
        }
      });
      list.add({
        'type': 'function',
        'function': {
          'name': 'simulate_keyboard',
          'description': 'Simulate keyboard text input or key presses on the host Windows machine.',
          'parameters': {
            'type': 'object',
            'properties': {
              'text': {'type': 'string', 'description': "Text to send, supports SendKeys markup like '{ENTER}', '{TAB}', etc."}
            },
            'required': ['text']
          }
        }
      });
    } else if (Platform.isLinux) {
      list.add({
        'type': 'function',
        'function': {
          'name': 'exec_shell',
          'description': 'Execute a shell command on the host Linux machine.',
          'parameters': {
            'type': 'object',
            'properties': {
              'command': {'type': 'string', 'description': 'Shell command to run'}
            },
            'required': ['command']
          }
        }
      });
    }
    _addDaemonToolsOpenAI(list);
    return list;
  }

  List<Map<String, dynamic>> _getPlatformToolsClaude() {
    final list = <Map<String, dynamic>>[];
    if (Platform.isAndroid) {
      list.add({
        'name': 'exec_adb',
        'description': 'Execute an adb command to control or query the connected Android device.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'command': {'type': 'string', 'description': "ADB command (e.g. 'devices', 'shell pm list packages')"}
          },
          'required': ['command']
        }
      });
      list.add({
        'name': 'adb_screenshot',
        'description': 'Capture a screenshot of the connected Android device.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'output_path': {'type': 'string', 'description': 'Output path on the host, default to screenshot.png'}
          }
        }
      });
      list.add({
        'name': 'adb_click',
        'description': 'Simulate a click/tap at coordinates (x, y) on the Android screen.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'x': {'type': 'integer', 'description': 'X coordinate'},
            'y': {'type': 'integer', 'description': 'Y coordinate'}
          },
          'required': ['x', 'y']
        }
      });
    } else if (Platform.isWindows) {
      list.add({
        'name': 'exec_powershell',
        'description': 'Execute a PowerShell script or command on the host Windows machine.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'script': {'type': 'string', 'description': 'PowerShell command or script to run'}
          },
          'required': ['script']
        }
      });
      list.add({
        'name': 'capture_screen',
        'description': 'Capture a screenshot of the host Windows screen.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'output_path': {'type': 'string', 'description': 'Output path for screenshot image'}
          }
        }
      });
      list.add({
        'name': 'simulate_mouse',
        'description': 'Simulate mouse movement and clicks on the host Windows machine.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['move', 'click', 'double_click', 'right_click'],
              'description': 'Mouse action to perform'
            },
            'x': {'type': 'integer', 'description': 'X coordinate'},
            'y': {'type': 'integer', 'description': 'Y coordinate'}
          },
          'required': ['action', 'x', 'y']
        }
      });
      list.add({
        'name': 'simulate_keyboard',
        'description': 'Simulate keyboard text input or key presses on the host Windows machine.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'text': {'type': 'string', 'description': "Text to send, supports SendKeys markup like '{ENTER}', '{TAB}', etc."}
          },
          'required': ['text']
        }
      });
    } else if (Platform.isLinux) {
      list.add({
        'name': 'exec_shell',
        'description': 'Execute a shell command on the host Linux machine.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'command': {'type': 'string', 'description': 'Shell command to run'}
          },
          'required': ['command']
        }
      });
    }
    _addDaemonToolsClaude(list);
    return list;
  }

  List<gemini.FunctionDeclaration> _getPlatformToolsGemini() {
    final list = <gemini.FunctionDeclaration>[];
    if (Platform.isAndroid) {
      list.add(gemini.FunctionDeclaration(
        'exec_adb',
        'Execute an adb command to control or query the connected Android device.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'command': gemini.Schema(gemini.SchemaType.string, description: "ADB command (e.g. 'devices', 'shell pm list packages')"),
          },
          requiredProperties: ['command']
        )
      ));
      list.add(gemini.FunctionDeclaration(
        'adb_screenshot',
        'Capture a screenshot of the connected Android device.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'output_path': gemini.Schema(gemini.SchemaType.string, description: 'Output path on the host, default to screenshot.png'),
          }
        )
      ));
      list.add(gemini.FunctionDeclaration(
        'adb_click',
        'Simulate a click/tap at coordinates (x, y) on the Android screen.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'x': gemini.Schema(gemini.SchemaType.integer, description: 'X coordinate'),
            'y': gemini.Schema(gemini.SchemaType.integer, description: 'Y coordinate'),
          },
          requiredProperties: ['x', 'y']
        )
      ));
    } else if (Platform.isWindows) {
      list.add(gemini.FunctionDeclaration(
        'exec_powershell',
        'Execute a PowerShell script or command on the host Windows machine.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'script': gemini.Schema(gemini.SchemaType.string, description: 'PowerShell command or script to run'),
          },
          requiredProperties: ['script']
        )
      ));
      list.add(gemini.FunctionDeclaration(
        'capture_screen',
        'Capture a screenshot of the host Windows screen.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'output_path': gemini.Schema(gemini.SchemaType.string, description: 'Output path for screenshot image'),
          }
        )
      ));
      list.add(gemini.FunctionDeclaration(
        'simulate_mouse',
        'Simulate mouse movement and clicks on the host Windows machine.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'action': gemini.Schema(gemini.SchemaType.string, description: 'Mouse action: move, click, double_click, right_click'),
            'x': gemini.Schema(gemini.SchemaType.integer, description: 'X coordinate'),
            'y': gemini.Schema(gemini.SchemaType.integer, description: 'Y coordinate'),
          },
          requiredProperties: ['action', 'x', 'y']
        )
      ));
      list.add(gemini.FunctionDeclaration(
        'simulate_keyboard',
        'Simulate keyboard text input or key presses on the host Windows machine.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'text': gemini.Schema(gemini.SchemaType.string, description: "Text to send, supports SendKeys markup like '{ENTER}', '{TAB}', etc."),
          },
          requiredProperties: ['text']
        )
      ));
    } else if (Platform.isLinux) {
      list.add(gemini.FunctionDeclaration(
        'exec_shell',
        'Execute a shell command on the host Linux machine.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'command': gemini.Schema(gemini.SchemaType.string, description: 'Shell command to run'),
          },
          requiredProperties: ['command']
        )
      ));
    }
    list.addAll(_getDaemonToolsGemini());
    return list;
  }

  Future<Map<String, dynamic>> _getUpdatedScreenResult(Map<String, dynamic> initialResult) async {
    if (initialResult['status'] != 'success') {
      return initialResult;
    }
    
    // Wait for the UI to update
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      final parser = ref.read(screenParserProvider);
      final structure = await parser.parseCurrentScreen(mode: ScreenParserMode.auto);
      if (structure != null) {
        return {
          ...initialResult,
          'updated_screen': structure.toJson(),
        };
      }
    } catch (_) {
      // If parsing fails, just return initial result
    }
    return initialResult;
  }

  Future<Map<String, dynamic>> _executePlatformTool(String name, Map<String, dynamic> args) async {
    // ------------------ ANDROID ------------------
    if (Platform.isAndroid) {
      if (name == 'exec_adb') {
        var command = args['command'] as String? ?? '';
        if (command.startsWith('adb ')) {
          command = command.substring(4);
        }
        final approved = await ref.read(hitlProvider.notifier).requestConfirmation(
          '运行 ADB 指令',
          'adb $command',
        );
        if (!approved) {
          return {'status': 'error', 'message': 'User rejected ADB command execution.'};
        }
        try {
          final res = await Process.run('adb', command.split(' '));
          return {
            'status': 'success',
            'stdout': res.stdout,
            'stderr': res.stderr,
            'exit_code': res.exitCode
          };
        } catch (e) {
          return {'status': 'error', 'message': e.toString()};
        }
      } else if (name == 'adb_screenshot') {
        final outputPath = args['output_path'] as String? ?? 'screenshot.png';
        try {
          await Process.run('adb', ['shell', 'screencap', '-p', '/sdcard/screen_aios.png']);
          await Process.run('adb', ['pull', '/sdcard/screen_aios.png', outputPath]);
          await Process.run('adb', ['shell', 'rm', '/sdcard/screen_aios.png']);
          return {'status': 'success', 'message': 'Screenshot pulled to $outputPath'};
        } catch (e) {
          return {'status': 'error', 'message': e.toString()};
        }
      } else if (name == 'adb_click') {
        final x = args['x'] ?? 0;
        final y = args['y'] ?? 0;
        try {
          final res = await Process.run('adb', ['shell', 'input', 'tap', x.toString(), y.toString()]);
          return await _getUpdatedScreenResult({
            'status': 'success',
            'stdout': res.stdout,
            'stderr': res.stderr,
            'exit_code': res.exitCode
          });
        } catch (e) {
          return {'status': 'error', 'message': e.toString()};
        }
      }
    }
    // ------------------ WINDOWS ------------------
    else if (Platform.isWindows) {
      if (name == 'exec_powershell') {
        final script = args['script'] as String? ?? '';
        final approved = await ref.read(hitlProvider.notifier).requestConfirmation(
          '运行 PowerShell 脚本',
          script,
        );
        if (!approved) {
          return {'status': 'error', 'message': 'User rejected PowerShell execution.'};
        }
        try {
          final res = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
          return {
            'status': 'success',
            'stdout': res.stdout,
            'stderr': res.stderr,
            'exit_code': res.exitCode
          };
        } catch (e) {
          return {'status': 'error', 'message': e.toString()};
        }
      } else if (name == 'capture_screen') {
        final outputPath = args['output_path'] as String? ?? 'screenshot.png';
        final absolutePath = File(outputPath).absolute.path;
        final psScript = '''
        Add-Type -AssemblyName System.Windows.Forms;
        Add-Type -AssemblyName System.Drawing;
        \$screen = [System.Windows.Forms.Screen]::PrimaryScreen;
        \$bounds = \$screen.Bounds;
        \$bitmap = New-Object System.Drawing.Bitmap(\$bounds.Width, \$bounds.Height);
        \$graphics = [System.Drawing.Graphics]::FromImage(\$bitmap);
        \$graphics.CopyFromScreen(\$bounds.Location, [System.Drawing.Point]::Empty, \$bounds.Size);
        \$bitmap.Save('$absolutePath', [System.Drawing.Imaging.ImageFormat]::Png);
        \$graphics.Dispose();
        \$bitmap.Dispose();
        ''';
        try {
          final res = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', psScript]);
          if (res.exitCode != 0) {
            return {'status': 'error', 'message': res.stderr};
          }
          return {'status': 'success', 'message': 'Screenshot saved to $absolutePath'};
        } catch (e) {
          return {'status': 'error', 'message': e.toString()};
        }
      } else if (name == 'simulate_mouse') {
        final action = args['action'] as String? ?? 'click';
        final x = args['x'] ?? 0;
        final y = args['y'] ?? 0;
        
        var psScript = '''
        Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern void mouse_event(int dwFlags, int dx, int dy, int cButtons, int dwExtraInfo); [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);' -Name Win32Mouse -Namespace Win32API;
        [Win32API.Win32Mouse]::SetCursorPos($x, $y);
        ''';
        if (action == 'click') {
          psScript += '\n[Win32API.Win32Mouse]::mouse_event(0x02 -bor 0x04, 0, 0, 0, 0);';
        } else if (action == 'right_click') {
          psScript += '\n[Win32API.Win32Mouse]::mouse_event(0x08 -bor 0x10, 0, 0, 0, 0);';
        } else if (action == 'double_click') {
          psScript += '''
          [Win32API.Win32Mouse]::mouse_event(0x02 -bor 0x04, 0, 0, 0, 0);
          Start-Sleep -m 100;
          [Win32API.Win32Mouse]::mouse_event(0x02 -bor 0x04, 0, 0, 0, 0);
          ''';
        }
        try {
          final res = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', psScript]);
          if (res.exitCode != 0) {
            return {'status': 'error', 'message': res.stderr};
          }
          return await _getUpdatedScreenResult({
            'status': 'success',
            'message': 'Simulated mouse $action at ($x, $y)'
          });
        } catch (e) {
          return {'status': 'error', 'message': e.toString()};
        }
      } else if (name == 'simulate_keyboard') {
        final text = args['text'] as String? ?? '';
        final escapedText = text.replaceAll("'", "''");
        final psScript = '''
        Add-Type -AssemblyName System.Windows.Forms;
        [System.Windows.Forms.SendKeys]::SendWait('$escapedText');
        ''';
        try {
          final res = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', psScript]);
          if (res.exitCode != 0) {
            return {'status': 'error', 'message': res.stderr};
          }
          return await _getUpdatedScreenResult({
            'status': 'success',
            'message': 'Simulated keyboard input: $text'
          });
        } catch (e) {
          return {'status': 'error', 'message': e.toString()};
        }
      }
    }
    // ------------------ LINUX ------------------
    else if (Platform.isLinux) {
      if (name == 'exec_shell') {
        final command = args['command'] as String? ?? '';
        final approved = await ref.read(hitlProvider.notifier).requestConfirmation(
          '运行 Shell 命令',
          command,
        );
        if (!approved) {
          return {'status': 'error', 'message': 'User rejected Shell execution.'};
        }
        try {
          final res = await Process.run('sh', ['-c', command]);
          return {
            'status': 'success',
            'stdout': res.stdout,
            'stderr': res.stderr,
            'exit_code': res.exitCode
          };
        } catch (e) {
          return {'status': 'error', 'message': e.toString()};
        }
      }
    }
    return {'status': 'error', 'message': 'Tool $name not supported on this platform.'};
  }

  Future<void> _updateLocationAndWeatherContext() async {
    final now = DateTime.now();
    if (_lastCacheTime != null && now.difference(_lastCacheTime!).inMinutes < 15) {
      return;
    }

    try {
      final locResponse = await http.get(Uri.parse('http://ip-api.com/json')).timeout(const Duration(seconds: 4));
      if (locResponse.statusCode == 200) {
        final locData = jsonDecode(locResponse.body);
        final city = locData['city'] ?? 'Unknown City';
        final country = locData['country'] ?? 'Unknown Country';
        final lat = locData['lat'];
        final lon = locData['lon'];
        
        _cachedLocationContext = "Location: $city, $country (Lat: $lat, Lon: $lon)";
        
        if (lat != null && lon != null) {
          final weatherUrl = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true';
          final weatherResponse = await http.get(Uri.parse(weatherUrl)).timeout(const Duration(seconds: 4));
          if (weatherResponse.statusCode == 200) {
            final weatherData = jsonDecode(weatherResponse.body);
            final current = weatherData['current_weather'];
            if (current != null) {
              final temp = current['temperature'];
              final wind = current['windspeed'];
              final code = current['weathercode'];
              
              String condition = '晴朗';
              if (code >= 1 && code <= 3) condition = '多云';
              else if (code >= 45 && code <= 48) condition = '有雾';
              else if (code >= 51 && code <= 67) condition = '细雨/小雨';
              else if (code >= 71 && code <= 77) condition = '小雪';
              else if (code >= 80 && code <= 82) condition = '阵雨';
              else if (code >= 85 && code <= 86) condition = '雪天';
              else if (code >= 95) condition = '雷阵雨';
              
              _cachedWeatherContext = "Weather: $temp°C, $condition (风速: $wind km/h)";
            }
          }
        }
      }
    } catch (e) {
      // Silently swallow network exceptions
    }
    
    _lastCacheTime = now;
  }

  Future<Map<String, dynamic>> _executeDaemonTool(String name, Map<String, dynamic> args) async {
    final agentId = args['agentId'] as String?;
    if (agentId == null) return {'status': 'error', 'message': 'Missing agentId'};

    final registry = ref.read(a2aAgentRegistryProvider);
    final targetAgent = registry.cast<A2AAgentEntry?>().firstWhere((e) => e!.id == agentId, orElse: () => null);
    if (targetAgent == null) {
      return {'status': 'error', 'message': 'Daemon node with ID $agentId not found.'};
    }

    final baseUrl = targetAgent.endpoint;
    final token = targetAgent.pairingToken ?? '';
    final headers = {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final getHeaders = {
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    try {
      http.Response response;
      if (name == 'daemon_execute_command') {
        final command = args['command'] as String? ?? '';
        final approved = await ref.read(hitlProvider.notifier).requestConfirmation(
          '在守护节点运行命令',
          '节点: ${targetAgent.name}\n命令: $command',
        );
        if (!approved) {
          return {'status': 'error', 'message': 'User rejected command execution on daemon.'};
        }
        response = await http.post(
          Uri.parse('$baseUrl/execute-command'),
          headers: headers,
          body: jsonEncode({'command': command}),
        ).timeout(const Duration(seconds: 15));
      } else if (name == 'daemon_execute_script') {
        final script = args['script'] as String? ?? '';
        final approved = await ref.read(hitlProvider.notifier).requestConfirmation(
          '在守护节点执行脚本',
          '节点: ${targetAgent.name}\n脚本内容:\n$script',
        );
        if (!approved) {
          return {'status': 'error', 'message': 'User rejected script execution on daemon.'};
        }
        response = await http.post(
          Uri.parse('$baseUrl/execute-script'),
          headers: headers,
          body: jsonEncode({
            'script': script,
            if (args.containsKey('extension')) 'extension': args['extension'],
          }),
        ).timeout(const Duration(seconds: 30));
      } else if (name == 'daemon_upload_file') {
        final path = args['path'] as String? ?? '';
        final ext = path.split('.').last.toLowerCase();
        final binaryExtensions = {'png', 'jpg', 'jpeg', 'gif', 'pdf', 'zip', 'tar', 'gz', 'exe', 'bin', 'dll', 'so', 'apk'};
        final isBinary = binaryExtensions.contains(ext);

        response = await http.post(
          Uri.parse('$baseUrl/upload-file'),
          headers: headers,
          body: jsonEncode({
            'path': path,
            'content': args['content'],
            'is_base64': isBinary,
          }),
        ).timeout(const Duration(seconds: 15));
      } else if (name == 'daemon_download_file') {
        response = await http.post(
          Uri.parse('$baseUrl/download-file'),
          headers: headers,
          body: jsonEncode({
            'path': args['path'],
          }),
        ).timeout(const Duration(seconds: 15));
      } else if (name == 'daemon_get_iot_data') {
        response = await http.get(
          Uri.parse('$baseUrl/iot-data'),
          headers: getHeaders,
        ).timeout(const Duration(seconds: 10));
      } else if (name == 'daemon_control_iot_device') {
        response = await http.post(
          Uri.parse('$baseUrl/control-device'),
          headers: headers,
          body: jsonEncode({
            'deviceId': args['deviceId'],
            'action': args['action'],
          }),
        ).timeout(const Duration(seconds: 10));
      } else if (name == 'daemon_get_screen_structure') {
        response = await http.get(
          Uri.parse('$baseUrl/screen-structure'),
          headers: getHeaders,
        ).timeout(const Duration(seconds: 15));
      } else if (name == 'daemon_parse_screenshot') {
        response = await http.post(
          Uri.parse('$baseUrl/parse-screenshot'),
          headers: headers,
          body: jsonEncode({
            'image': args['image'],
          }),
        ).timeout(const Duration(seconds: 30));
      } else if (name == 'daemon_browser_action') {
        response = await http.post(
          Uri.parse('$baseUrl/browser-action'),
          headers: headers,
          body: jsonEncode({
            'actions': args['actions'],
          }),
        ).timeout(const Duration(seconds: 45));
      } else {
        return {'status': 'error', 'message': 'Unknown daemon tool $name'};
      }

      if (response.statusCode == 401) {
        return {
          'status': 'error',
          'message': 'Unauthorized: Pairing Token is invalid or missing for node "${targetAgent.name}". Please pair this daemon node first in Settings/Capability Registry with the correct Token.'
        };
      }
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'HTTP request failed: $e'};
    }
  }

  void _addDaemonToolsOpenAI(List<Map<String, dynamic>> list) {
    list.add({
      'type': 'function',
      'function': {
        'name': 'daemon_execute_command',
        'description': 'Execute a shell command on a discovered headless daemon node.',
        'parameters': {
          'type': 'object',
          'properties': {
            'agentId': {'type': 'string', 'description': 'The target node agent ID'},
            'command': {'type': 'string', 'description': 'The shell command to run'}
          },
          'required': ['agentId', 'command']
        }
      }
    });
    list.add({
      'type': 'function',
      'function': {
        'name': 'daemon_execute_script',
        'description': 'Write and execute a script file on a discovered headless daemon node.',
        'parameters': {
          'type': 'object',
          'properties': {
            'agentId': {'type': 'string', 'description': 'The target node agent ID'},
            'script': {'type': 'string', 'description': 'The script code content'},
            'extension': {'type': 'string', 'description': 'File extension including dot (e.g. .sh, .ps1)'}
          },
          'required': ['agentId', 'script']
        }
      }
    });
    list.add({
      'type': 'function',
      'function': {
        'name': 'daemon_upload_file',
        'description': 'Upload/write a file to a specific path on a discovered headless daemon node.',
        'parameters': {
          'type': 'object',
          'properties': {
            'agentId': {'type': 'string', 'description': 'The target node agent ID'},
            'path': {'type': 'string', 'description': 'Absolute or relative target file path'},
            'content': {'type': 'string', 'description': 'Text content of the file'}
          },
          'required': ['agentId', 'path', 'content']
        }
      }
    });
    list.add({
      'type': 'function',
      'function': {
        'name': 'daemon_get_iot_data',
        'description': 'Retrieve telemetry data for all connected IoT devices from a discovered edge gateway daemon.',
        'parameters': {
          'type': 'object',
          'properties': {
            'agentId': {'type': 'string', 'description': 'The target gateway node agent ID'}
          },
          'required': ['agentId']
        }
      }
    });
    list.add({
      'type': 'function',
      'function': {
        'name': 'daemon_control_iot_device',
        'description': 'Control a specific IoT device state connected to a discovered edge gateway daemon.',
        'parameters': {
          'type': 'object',
          'properties': {
            'agentId': {'type': 'string', 'description': 'The target gateway node agent ID'},
            'deviceId': {'type': 'string', 'description': 'The unique IoT device ID'},
            'action': {'type': 'string', 'description': 'Action to perform (e.g. "on", "off", "brightness=50", "temp=22.0")'}
          },
          'required': ['agentId', 'deviceId', 'action']
        }
      }
    });
    list.add({
      'type': 'function',
      'function': {
        'name': 'daemon_download_file',
        'description': 'Download/read a file from a specific path on a discovered headless daemon node.',
        'parameters': {
          'type': 'object',
          'properties': {
            'agentId': {'type': 'string', 'description': 'The target node agent ID'},
            'path': {'type': 'string', 'description': 'Absolute or relative target file path to download'}
          },
          'required': ['agentId', 'path']
        }
      }
    });
    list.add({
      'type': 'function',
      'function': {
        'name': 'daemon_get_screen_structure',
        'description': 'Retrieve the structured UI tree (JSON) of the active screen/window from a discovered edge gateway or daemon node.',
        'parameters': {
          'type': 'object',
          'properties': {
            'agentId': {'type': 'string', 'description': 'The target node agent ID'}
          },
          'required': ['agentId']
        }
      }
    });
    list.add({
      'type': 'function',
      'function': {
        'name': 'daemon_parse_screenshot',
        'description': 'Send a screenshot base64 image to a discovered daemon node for local OmniParser vision analysis.',
        'parameters': {
          'type': 'object',
          'properties': {
            'agentId': {'type': 'string', 'description': 'The target node agent ID'},
            'image': {'type': 'string', 'description': 'Base64 encoded screenshot image string'}
          },
          'required': ['agentId', 'image']
        }
      }
    });
    list.add({
      'type': 'function',
      'function': {
        'name': 'daemon_browser_action',
        'description': 'Execute a sequence of headless browser actions (goto, click, type, get_text, screenshot, close) on a discovered headless daemon node.',
        'parameters': {
          'type': 'object',
          'properties': {
            'agentId': {'type': 'string', 'description': 'The target node agent ID'},
            'actions': {
              'type': 'array',
              'description': 'List of browser actions to execute sequentially.',
              'items': {
                'type': 'object',
                'properties': {
                  'action': {'type': 'string', 'description': 'One of: goto, click, type, get_text, screenshot, close'},
                  'url': {'type': 'string', 'description': 'The target URL for goto'},
                  'selector': {'type': 'string', 'description': 'CSS/XPath selector for click, type, get_text'},
                  'text': {'type': 'string', 'description': 'The text value to input for type'}
                },
                'required': ['action']
              }
            }
          },
          'required': ['agentId', 'actions']
        }
      }
    });
  }

  void _addDaemonToolsClaude(List<Map<String, dynamic>> list) {
    list.add({
      'name': 'daemon_execute_command',
      'description': 'Execute a shell command on a discovered headless daemon node.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'agentId': {'type': 'string', 'description': 'The target node agent ID'},
          'command': {'type': 'string', 'description': 'The shell command to run'}
        },
        'required': ['agentId', 'command']
      }
    });
    list.add({
      'name': 'daemon_execute_script',
      'description': 'Write and execute a script file on a discovered headless daemon node.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'agentId': {'type': 'string', 'description': 'The target node agent ID'},
          'script': {'type': 'string', 'description': 'The script code content'},
          'extension': {'type': 'string', 'description': 'File extension including dot (e.g. .sh, .ps1)'}
        },
        'required': ['agentId', 'script']
      }
    });
    list.add({
      'name': 'daemon_upload_file',
      'description': 'Upload/write a file to a specific path on a discovered headless daemon node.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'agentId': {'type': 'string', 'description': 'The target node agent ID'},
          'path': {'type': 'string', 'description': 'Absolute or relative target file path'},
          'content': {'type': 'string', 'description': 'Text content of the file'}
        },
        'required': ['agentId', 'path', 'content']
      }
    });
    list.add({
      'name': 'daemon_get_iot_data',
      'description': 'Retrieve telemetry data for all connected IoT devices from a discovered edge gateway daemon.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'agentId': {'type': 'string', 'description': 'The target gateway node agent ID'}
        },
        'required': ['agentId']
      }
    });
    list.add({
      'name': 'daemon_control_iot_device',
      'description': 'Control a specific IoT device state connected to a discovered edge gateway daemon.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'agentId': {'type': 'string', 'description': 'The target gateway node agent ID'},
          'deviceId': {'type': 'string', 'description': 'The unique IoT device ID'},
          'action': {'type': 'string', 'description': 'Action to perform (e.g. "on", "off", "brightness=50", "temp=22.0")'}
        },
        'required': ['agentId', 'deviceId', 'action']
      }
    });
    list.add({
      'name': 'daemon_download_file',
      'description': 'Download/read a file from a specific path on a discovered headless daemon node.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'agentId': {'type': 'string', 'description': 'The target node agent ID'},
          'path': {'type': 'string', 'description': 'Absolute or relative target file path to download'}
        },
        'required': ['agentId', 'path']
      }
    });
    list.add({
      'name': 'daemon_get_screen_structure',
      'description': 'Retrieve the structured UI tree (JSON) of the active screen/window from a discovered edge gateway or daemon node.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'agentId': {'type': 'string', 'description': 'The target node agent ID'}
        },
        'required': ['agentId']
      }
    });
    list.add({
      'name': 'daemon_parse_screenshot',
      'description': 'Send a screenshot base64 image to a discovered daemon node for local OmniParser vision analysis.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'agentId': {'type': 'string', 'description': 'The target node agent ID'},
          'image': {'type': 'string', 'description': 'Base64 encoded screenshot image string'}
        },
        'required': ['agentId', 'image']
      }
    });
    list.add({
      'name': 'daemon_browser_action',
      'description': 'Execute a sequence of headless browser actions (goto, click, type, get_text, screenshot, close) on a discovered headless daemon node.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'agentId': {'type': 'string', 'description': 'The target node agent ID'},
          'actions': {
            'type': 'array',
            'description': 'List of browser actions to execute sequentially.',
            'items': {
              'type': 'object',
              'properties': {
                'action': {'type': 'string', 'description': 'One of: goto, click, type, get_text, screenshot, close'},
                'url': {'type': 'string', 'description': 'The target URL for goto'},
                'selector': {'type': 'string', 'description': 'CSS/XPath selector for click, type, get_text'},
                'text': {'type': 'string', 'description': 'The text value to input for type'}
              },
              'required': ['action']
            }
          }
        },
        'required': ['agentId', 'actions']
      }
    });
  }

  List<gemini.FunctionDeclaration> _getDaemonToolsGemini() {
    return [
      gemini.FunctionDeclaration(
        'daemon_execute_command',
        'Execute a shell command on a discovered headless daemon node.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'agentId': gemini.Schema(gemini.SchemaType.string, description: 'The target node agent ID'),
            'command': gemini.Schema(gemini.SchemaType.string, description: 'The shell command to run'),
          },
          requiredProperties: ['agentId', 'command']
        )
      ),
      gemini.FunctionDeclaration(
        'daemon_execute_script',
        'Write and execute a script file on a discovered headless daemon node.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'agentId': gemini.Schema(gemini.SchemaType.string, description: 'The target node agent ID'),
            'script': gemini.Schema(gemini.SchemaType.string, description: 'The script code content'),
            'extension': gemini.Schema(gemini.SchemaType.string, description: 'File extension including dot (e.g. .sh, .ps1)'),
          },
          requiredProperties: ['agentId', 'script']
        )
      ),
      gemini.FunctionDeclaration(
        'daemon_upload_file',
        'Upload/write a file to a specific path on a discovered headless daemon node.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'agentId': gemini.Schema(gemini.SchemaType.string, description: 'The target node agent ID'),
            'path': gemini.Schema(gemini.SchemaType.string, description: 'Absolute or relative target file path'),
            'content': gemini.Schema(gemini.SchemaType.string, description: 'Text content of the file'),
          },
          requiredProperties: ['agentId', 'path', 'content']
        )
      ),
      gemini.FunctionDeclaration(
        'daemon_get_iot_data',
        'Retrieve telemetry data for all connected IoT devices from a discovered edge gateway daemon.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'agentId': gemini.Schema(gemini.SchemaType.string, description: 'The target gateway node agent ID'),
          },
          requiredProperties: ['agentId']
        )
      ),
      gemini.FunctionDeclaration(
        'daemon_control_iot_device',
        'Control a specific IoT device state connected to a discovered edge gateway daemon.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'agentId': gemini.Schema(gemini.SchemaType.string, description: 'The target gateway node agent ID'),
            'deviceId': gemini.Schema(gemini.SchemaType.string, description: 'The unique IoT device ID'),
            'action': gemini.Schema(gemini.SchemaType.string, description: 'Action to perform (e.g. "on", "off", "brightness=50", "temp=22.0")'),
          },
          requiredProperties: ['agentId', 'deviceId', 'action']
        )
      ),
      gemini.FunctionDeclaration(
        'daemon_download_file',
        'Download/read a file from a specific path on a discovered headless daemon node.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'agentId': gemini.Schema(gemini.SchemaType.string, description: 'The target node agent ID'),
            'path': gemini.Schema(gemini.SchemaType.string, description: 'Absolute or relative target file path to download'),
          },
          requiredProperties: ['agentId', 'path']
        )
      ),
      gemini.FunctionDeclaration(
        'daemon_get_screen_structure',
        'Retrieve the structured UI tree (JSON) of the active screen/window from a discovered edge gateway or daemon node.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'agentId': gemini.Schema(gemini.SchemaType.string, description: 'The target node agent ID'),
          },
          requiredProperties: ['agentId']
        )
      ),
      gemini.FunctionDeclaration(
        'daemon_parse_screenshot',
        'Send a screenshot base64 image to a discovered daemon node for local OmniParser vision analysis.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'agentId': gemini.Schema(gemini.SchemaType.string, description: 'The target node agent ID'),
            'image': gemini.Schema(gemini.SchemaType.string, description: 'Base64 encoded screenshot image string'),
          },
          requiredProperties: ['agentId', 'image']
        )
      ),
      gemini.FunctionDeclaration(
        'daemon_browser_action',
        'Execute a sequence of headless browser actions (goto, click, type, get_text, screenshot, close) on a discovered headless daemon node.',
        gemini.Schema(
          gemini.SchemaType.object,
          properties: {
            'agentId': gemini.Schema(gemini.SchemaType.string, description: 'The target node agent ID'),
            'actions': gemini.Schema(
              gemini.SchemaType.array,
              description: 'List of browser actions to execute sequentially.',
              items: gemini.Schema(
                gemini.SchemaType.object,
                properties: {
                  'action': gemini.Schema(gemini.SchemaType.string, description: 'One of: goto, click, type, get_text, screenshot, close'),
                  'url': gemini.Schema(gemini.SchemaType.string, description: 'The target URL for goto'),
                  'selector': gemini.Schema(gemini.SchemaType.string, description: 'CSS/XPath selector for click, type, get_text'),
                  'text': gemini.Schema(gemini.SchemaType.string, description: 'The text value to input for type'),
                },
                requiredProperties: ['action']
              )
            ),
          },
          requiredProperties: ['agentId', 'actions']
        )
      ),
    ];
  }
}

class AgentResponse {
  final UiNode? uiTree;
  final String? textReply;

  AgentResponse({this.uiTree, this.textReply});
}
