import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'network_utils.dart';

final bridgeServiceProvider = Provider<BridgeService>((ref) {
  return BridgeService();
});

class BridgedAgentInstance {
  final Map<String, dynamic> config;
  final HttpServer server;
  final nsd.Registration registration;

  BridgedAgentInstance({
    required this.config,
    required this.server,
    required this.registration,
  });
}

class BridgeService {
  final List<BridgedAgentInstance> _instances = [];
  bool _isBridging = false;

  Future<void> startBridging() async {
    if (kIsWeb) return;
    if (_isBridging) return;
    _isBridging = true;

    try {
      final configPath = _getConfigPath();
      final configFile = File(configPath);

      if (!await configFile.exists()) {
        debugPrint('No local_agents.json found at $configPath');
        return;
      }

      final content = await configFile.readAsString();
      final data = jsonDecode(content);
      final agents = data['agents'] as List<dynamic>? ?? [];

      for (final agentData in agents) {
        await _startAgentBridge(agentData);
      }
    } catch (e) {
      debugPrint('Failed to start bridge service: $e');
    }
  }

  Future<void> stopBridging() async {
    if (kIsWeb) return;
    if (!_isBridging) return;
    _isBridging = false;

    for (final instance in _instances) {
      await nsd.unregister(instance.registration);
      await instance.server.close();
    }
    _instances.clear();
  }

  String _getConfigPath() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    return '$home${Platform.pathSeparator}.hermes${Platform.pathSeparator}local_agents.json';
  }

  Future<void> _startAgentBridge(Map<String, dynamic> agentConfig) async {
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      debugPrint('Bridge Server for ${agentConfig['id']} listening on port ${server.port}');

      server.listen((HttpRequest request) {
        _handleHttpRequest(request, agentConfig, server.port);
      });

      final serviceName = 'FlutterBridge_${agentConfig['id']}_${Platform.localHostname}';
      final service = nsd.Service(
        name: serviceName,
        type: '_a2a._tcp',
        port: server.port,
      );
      final registration = await nsd.register(service);
      
      _instances.add(BridgedAgentInstance(
        config: agentConfig,
        server: server,
        registration: registration,
      ));
      debugPrint('Bridge mDNS registered: $serviceName');
    } catch (e) {
      debugPrint('Failed to start bridge for agent ${agentConfig['id']}: $e');
    }
  }

  void _handleHttpRequest(HttpRequest request, Map<String, dynamic> agentConfig, int port) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    try {
      if (request.method == 'GET' && request.uri.path == '/agent-card') {
        final localIp = await getLocalIpAddress();
        final card = {
          'id': agentConfig['id'] ?? 'unknown',
          'name': agentConfig['name'] ?? 'Bridged Agent',
          'description': agentConfig['description'] ?? 'Bridged CLI Agent on ${Platform.operatingSystem}',
          'version': '1.0.0',
          'endpoint': 'http://$localIp:$port',
          'skills': ['cli_bridge'],
          'auth': 'none'
        };
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(card));
        await request.response.close();
      } else if (request.method == 'POST' && (request.uri.path == '/' || request.uri.path == '/task')) {
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content);
        final intent = body['intent'] as String?;

        if (intent == null) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('{"error": "Missing intent"}');
          await request.response.close();
          return;
        }

        final command = agentConfig['command'] as String;
        final rawArgs = List<String>.from(agentConfig['args'] ?? []);
        final args = rawArgs.map((arg) => arg.replaceAll('{intent}', intent)).toList();

        final processResult = await Process.run(command, args);
        final resultText = 'Stdout: ${processResult.stdout}\nStderr: ${processResult.stderr}';

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'reply': resultText,
        }));
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not found');
        await request.response.close();
      }
    } catch (e) {
      debugPrint('HTTP request error in bridge: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('{"error": "$e"}');
      await request.response.close();
    }
  }
}
