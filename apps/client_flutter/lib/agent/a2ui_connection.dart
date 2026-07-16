import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'a2ui_messages.dart';

class A2UIConnection {
  WebSocketChannel? _channel;
  final String url;
  final String sessionId;
  
  final _messageController = StreamController<A2UIMessage>.broadcast();
  Stream<A2UIMessage> get messages => _messageController.stream;

  final _stateController = StreamController<ConnectionStateEnum>.broadcast();
  Stream<ConnectionStateEnum> get state => _stateController.stream;
  
  int _retryCount = 0;
  static const int _maxRetries = 5;
  Timer? _reconnectTimer;
  
  A2UIConnection(this.url, this.sessionId);

  void connect() {
    if (_channel != null) return;
    
    _stateController.add(ConnectionStateEnum.connecting);
    final wsUrl = Uri.parse('$url/ws/a2ui/$sessionId');
    
    try {
      _channel = WebSocketChannel.connect(wsUrl);
      _stateController.add(ConnectionStateEnum.connected);
      _retryCount = 0;
      
      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String);
            final msg = A2UIMessage.fromJson(json);
            _messageController.add(msg);
          } catch (e) {
            debugPrint('Failed to parse A2UI message: $e');
          }
        },
        onError: (error) {
          debugPrint('A2UI WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('A2UI WebSocket closed');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('A2UI connection failed: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _channel = null;
    _stateController.add(ConnectionStateEnum.disconnected);
    
    if (_retryCount < _maxRetries) {
      _retryCount++;
      final delay = Duration(seconds: 2 * _retryCount);
      debugPrint('Reconnecting in ${delay.inSeconds}s... (Attempt $_retryCount/$_maxRetries)');
      _reconnectTimer = Timer(delay, connect);
    } else {
      _stateController.add(ConnectionStateEnum.error);
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _stateController.add(ConnectionStateEnum.disconnected);
  }

  void sendEvent(String action, Map<String, dynamic> payload) {
    if (_channel == null) return;
    
    final msg = A2UIClientEvent(
      action: action,
      payload: payload,
    );
    _channel!.sink.add(jsonEncode(msg.toJson()));
  }

  void sendConfirmResponse(String confirmationId, bool confirmed) {
    if (_channel == null) return;
    
    final msg = A2UIConfirmResponse(
      confirmationId: confirmationId,
      confirmed: confirmed,
    );
    _channel!.sink.add(jsonEncode(msg.toJson()));
  }
}

enum ConnectionStateEnum {
  connecting,
  connected,
  disconnected,
  error
}
