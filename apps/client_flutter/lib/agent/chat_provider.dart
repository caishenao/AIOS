import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'a2ui_connection.dart';
import 'a2ui_messages.dart';
import '../genui/surface/ui_node.dart';
import '../config/capability_registry.dart';
import 'local_agent_service.dart';

final useLocalAgentProvider = StateProvider<bool>((ref) => true);

final adapterBaseUrlProvider = StateProvider<String>((ref) => 'http://127.0.0.1:8700');
final adapterWsUrlProvider = StateProvider<String>((ref) => 'ws://127.0.0.1:8700');

/// Holds the current session id
final chatProvider = StateNotifierProvider<ChatNotifier, String?>((ref) {
  return ChatNotifier(ref);
});

/// Holds the latest UiNode tree (keyed by session, but we also have a global one)
final latestUiTreeProvider = StateProvider<UiNode?>((ref) => null);

/// Holds the latest text reply from the assistant
final latestTextReplyProvider = StateProvider<String?>((ref) => null);

/// Tracks whether a chat request is in flight
final isChatLoadingProvider = StateProvider<bool>((ref) => false);

class ChatNotifier extends StateNotifier<String?> {
  final Ref ref;
  ChatNotifier(this.ref) : super(null);

  void cancelCurrentTask() {
    final useLocal = ref.read(useLocalAgentProvider);
    if (useLocal) {
      ref.read(localAgentProvider).cancelCurrentTask();
    }
    ref.read(isChatLoadingProvider.notifier).state = false;
  }

  /// Send a message and wait for the complete response (synchronous API).
  /// Returns the session ID on success. The UI tree and text are placed into providers.
  Future<String> sendMessage(String text) async {
    ref.read(isChatLoadingProvider.notifier).state = true;
    ref.read(latestUiTreeProvider.notifier).state = null;
    ref.read(latestTextReplyProvider.notifier).state = null;

    final useLocal = ref.read(useLocalAgentProvider);

    try {
      if (useLocal) {
        final localAgent = ref.read(localAgentProvider);
        final response = await localAgent.sendMessage(text);
        
        ref.read(latestUiTreeProvider.notifier).state = response.uiTree;
        ref.read(latestTextReplyProvider.notifier).state = response.textReply;
        
        state = 'local_session';
        return 'local_session';
      } else {
        final baseUrl = ref.read(adapterBaseUrlProvider);
        final url = Uri.parse('$baseUrl/api/chat');

        final payload = {
          'text': text,
          if (state != null) 'session_id': state,
          'a2a_agents': ref.read(a2aAgentRegistryProvider).map((a) => a.toJson()).toList(),
        };
        
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final sessionId = data['session_id'] as String;
          state = sessionId;

          // Parse UI tree if present
          final uiTreeJson = data['ui_tree'];
          if (uiTreeJson != null && uiTreeJson is Map<String, dynamic>) {
            final node = UiNode.fromJson(uiTreeJson);
            ref.read(latestUiTreeProvider.notifier).state = node;
          }

          // Store text reply
          final textReply = data['text_reply'] as String?;
          ref.read(latestTextReplyProvider.notifier).state = textReply;

          return sessionId;
        } else {
          throw Exception('Server error: ${response.statusCode} ${response.body}');
        }
      }
    } finally {
      ref.read(isChatLoadingProvider.notifier).state = false;
    }
  }
}

// Keep WebSocket providers for future streaming/interactive use
final a2uiConnectionProvider = StateNotifierProvider.family<A2UIConnectionNotifier, A2UIConnection?, String>((ref, sessionId) {
  return A2UIConnectionNotifier(ref, sessionId);
});

class A2UIConnectionNotifier extends StateNotifier<A2UIConnection?> {
  final Ref ref;
  final String sessionId;
  
  A2UIConnectionNotifier(this.ref, this.sessionId) : super(null);
  
  void connect() {
    if (state != null) return;
    
    final wsUrl = ref.read(adapterWsUrlProvider);
    final conn = A2UIConnection(wsUrl, sessionId);
    
    conn.messages.listen((msg) {
      if (msg is A2UIRenderMessage) {
        ref.read(currentUiTreeProvider(sessionId).notifier).state = msg.uiTree;
        // Also push to global latest
        ref.read(latestUiTreeProvider.notifier).state = msg.uiTree;
      }
    });
    
    conn.state.listen((s) {
      ref.read(connectionStateProvider(sessionId).notifier).state = s;
    });
    
    conn.connect();
    state = conn;
  }
  
  void disconnect() {
    state?.disconnect();
    state = null;
  }
  
  void sendEvent(String action, Map<String, dynamic> payload) {
    state?.sendEvent(action, payload);
  }
}

final currentUiTreeProvider = StateProvider.family<UiNode?, String>((ref, sessionId) => null);
final connectionStateProvider = StateProvider.family<ConnectionStateEnum, String>((ref, sessionId) => ConnectionStateEnum.disconnected);
