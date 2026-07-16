import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

class DaemonConfig {
  final String id;
  final String name;
  final int port;
  final List<String> skills;
  final String auth;
  final String token;

  DaemonConfig({
    required this.id,
    required this.name,
    required this.port,
    required this.skills,
    required this.auth,
    required this.token,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'port': port,
        'skills': skills,
        'auth': auth,
        'token': token,
      };

  factory DaemonConfig.fromJson(Map<String, dynamic> json) => DaemonConfig(
        id: json['id'] ?? const Uuid().v4(),
        name: json['name'] ?? 'Headless Daemon',
        port: json['port'] ?? 9000,
        skills: List<String>.from(json['skills'] ?? []),
        auth: json['auth'] ?? 'token',
        token: json['token'] ?? const Uuid().v4(),
      );

  static Future<DaemonConfig> load(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        
        // Regenerate token if missing or auth is 'token'
        var token = json['token'] as String? ?? '';
        var saveNeeded = false;
        if (token.isEmpty) {
          token = const Uuid().v4();
          json['token'] = token;
          saveNeeded = true;
        }
        
        final config = DaemonConfig.fromJson(json);
        if (saveNeeded) {
          await config.save(path);
        }
        return config;
      } catch (_) {}
    }
    // Return default config
    final defaultToken = const Uuid().v4();
    final config = DaemonConfig(
      id: const Uuid().v4(),
      name: 'Headless Daemon',
      port: 9000,
      skills: ['file_upload', 'command_exec', 'script_exec', 'iot_data', 'iot_control', 'screen_parse', 'web_automation'],
      auth: 'token',
      token: defaultToken,
    );
    await config.save(path);
    return config;
  }

  Future<void> save(String path) async {
    final file = File(path);
    final jsonString = const JsonEncoder.withIndent('  ').convert(toJson());
    await file.writeAsString(jsonString);
  }
}
