import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/capability_registry.dart';
import 'local_agent_service.dart';
import 'chat_provider.dart';

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  return DiscoveryService(ref);
});

class DiscoveryService {
  final Ref ref;
  nsd.Discovery? _discovery;
  nsd.Registration? _registration;
  HttpServer? _server;
  RawDatagramSocket? _udpSocket;
  bool _isScanning = false;
  final String _agentId = const Uuid().v4();

  DiscoveryService(this.ref);

  bool get isScanning => _isScanning;

  Future<void> startScanning() async {
    if (kIsWeb) return;
    if (_isScanning) return;
    _isScanning = true;

    try {
      // 1. Start local HTTP Server
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      debugPrint('Local Agent Server listening on port ${_server!.port}');
      
      _server!.listen((HttpRequest request) {
        _handleHttpRequest(request);
      });

      // 2. Register mDNS Service
      final serviceName = 'FlutterAgent_${Platform.localHostname}';
      final service = nsd.Service(
        name: serviceName,
        type: '_a2a._tcp',
        port: _server!.port,
      );
      _registration = await nsd.register(service);
      debugPrint('mDNS Service registered: $serviceName');

      // 3. Start Discovery
      _discovery = await nsd.startDiscovery('_a2a._tcp');
      _discovery!.addListener(() {
        _handleServicesChanged();
      });

      // 4. Start UDP Multicast Scan for Headless Daemons
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 12100, reuseAddress: true);
      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data);
              final data = jsonDecode(text);
              final id = data['id'] as String?;
              if (id != null && id != _agentId) {
                final entry = A2AAgentEntry(
                  id: id,
                  name: data['name'] ?? 'Discovered Daemon',
                  description: 'AIOS Headless Daemon node',
                  version: '1.0.0',
                  endpoint: 'http://${datagram.address.address}:${data['port'] ?? 9000}',
                  skills: List<String>.from(data['skills'] ?? []),
                  auth: data['auth'] ?? 'none',
                  devices: data['devices'] as List<dynamic>? ?? const [],
                );
                ref.read(a2aAgentRegistryProvider.notifier).addAgent(entry);
              }
            } catch (e) {
              debugPrint('Error parsing discovery UDP packet: $e');
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to start Discovery/Hosting: $e');
      _isScanning = false;
    }
  }

  Future<void> stopScanning() async {
    if (kIsWeb) return;
    if (!_isScanning) return;
    _isScanning = false;

    if (_discovery != null) {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
    }

    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }

    if (_udpSocket != null) {
      _udpSocket!.close();
      _udpSocket = null;
    }

    if (_server != null) {
      await _server!.close();
      _server = null;
    }
  }

  void _handleHttpRequest(HttpRequest request) async {
    // CORS headers
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
        final card = {
          'id': _agentId,
          'name': 'Flutter Local Agent (${Platform.localHostname})',
          'description': 'Decentralized local agent hosted on ${Platform.operatingSystem}',
          'version': '1.0.0',
          'endpoint': 'http://${Platform.localHostname}:${_server!.port}',
          'skills': ['chat', 'ui_generation', 'hardware_info', 'local_file'],
          'auth': 'none'
        };
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(card));
        await request.response.close();
      } else if (request.method == 'POST' && 
                 (request.uri.path == '/' || 
                  request.uri.path == '/task' || 
                  request.uri.path == '/a2a/tasks')) {
        final content = await utf8.decoder.bind(request).join();
        final body = jsonDecode(content);
        final intent = (body['intent'] ?? body['task']) as String?;

        if (intent == null) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('{"error": "Missing intent or task"}');
          await request.response.close();
          return;
        }

        final useLocal = ref.read(useLocalAgentProvider);
        if (useLocal) {
          final response = await ref.read(localAgentProvider).sendMessage(intent);
          
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'reply': response.textReply,
            if (response.uiTree != null) 'uiTree': response.uiTree!.toJson(),
          }));
          await request.response.close();
        } else {
          final baseUrl = ref.read(adapterBaseUrlProvider);
          final url = Uri.parse('$baseUrl/api/chat');
          final payload = {
            'text': intent,
            'a2a_agents': ref.read(a2aAgentRegistryProvider).map((a) => a.toJson()).toList(),
          };
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
          request.response.headers.contentType = ContentType.json;
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            request.response.write(jsonEncode({
              'reply': data['text_reply'],
              if (data['ui_tree'] != null) 'uiTree': data['ui_tree'],
            }));
          } else {
            request.response.statusCode = response.statusCode;
            request.response.write(response.body);
          }
          await request.response.close();
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not found');
        await request.response.close();
      }
    } catch (e) {
      debugPrint('HTTP request error: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('{"error": "$e"}');
      await request.response.close();
    }
  }

  void _handleServicesChanged() {
    if (_discovery == null) return;
    for (final service in _discovery!.services) {
      if (service.name?.contains(Platform.localHostname) ?? false) continue; // skip self by name
      _processDiscoveredService(service);
    }
  }

  Future<void> _processDiscoveredService(nsd.Service service) async {
    final host = service.host;
    final port = service.port;
    if (host == null || port == null) return;

    final endpoint = 'http://$host:$port';
    try {
      final response = await http.get(Uri.parse('$endpoint/agent-card')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['id'] == _agentId) return; // double check skip self

        final entry = A2AAgentEntry(
          id: data['id'] ?? service.name ?? 'unknown_id',
          name: data['name'] ?? service.name ?? 'Unknown Agent',
          description: data['description'] ?? 'Auto-discovered A2A Agent',
          version: data['version'] ?? '1.0.0',
          endpoint: endpoint,
          skills: List<String>.from(data['skills'] ?? []),
          auth: data['auth'] ?? 'none',
          devices: data['devices'] as List<dynamic>? ?? const [],
          rfwWidgets: data['rfw_widgets'] as String?,
        );

        // Add to registry automatically
        ref.read(a2aAgentRegistryProvider.notifier).addAgent(entry);
        debugPrint('Added discovered A2A Agent: ${entry.name} at ${entry.endpoint}');
      }
    } catch (e) {
      debugPrint('Failed to fetch agent card from $endpoint: $e');
    }
  }
}
