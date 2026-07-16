import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'config.dart';

class DaemonDiscoveryService {
  final DaemonConfig config;
  RawDatagramSocket? _socket;
  Timer? _timer;

  DaemonDiscoveryService(this.config);

  Future<void> start() async {
    try {
      // Bind to port 0 for outgoing UDP broadcast
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;

      final payload = jsonEncode({
        'id': config.id,
        'name': config.name,
        'port': config.port,
        'skills': config.skills,
        'auth': config.auth,
      });
      final bytes = utf8.encode(payload);

      // Periodically broadcast every 5 seconds
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        try {
          // Broadcast to standard subnet broadcast address 255.255.255.255 on port 12100
          _socket!.send(bytes, InternetAddress('255.255.255.255'), 12100);
        } catch (_) {}
      });
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
  }
}
