import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class McpServerEntry {
  final String id;
  final String name;
  final String transport;
  final String endpoint;
  final String auth;
  final String? credentialRef;

  McpServerEntry({
    required this.id,
    required this.name,
    required this.transport,
    required this.endpoint,
    required this.auth,
    this.credentialRef,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'transport': transport,
        'endpoint': endpoint,
        'auth': auth,
        'credentialRef': credentialRef,
      };

  factory McpServerEntry.fromJson(Map<String, dynamic> json) => McpServerEntry(
        id: json['id'],
        name: json['name'],
        transport: json['transport'],
        endpoint: json['endpoint'],
        auth: json['auth'],
        credentialRef: json['credentialRef'],
      );
}

final capabilityRegistryProvider = StateNotifierProvider<CapabilityRegistryNotifier, List<McpServerEntry>>((ref) {
  final notifier = CapabilityRegistryNotifier();
  notifier.load();
  return notifier;
});

class CapabilityRegistryNotifier extends StateNotifier<List<McpServerEntry>> {
  static const String _key = 'mcp_servers';
  
  CapabilityRegistryNotifier() : super([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      state = jsonList.map((e) => McpServerEntry.fromJson(e)).toList();
    }
  }

  Future<void> addServer(McpServerEntry entry) async {
    final newState = [...state, entry];
    state = newState;
    await _save(newState);
  }

  Future<void> removeServer(String id) async {
    final newState = state.where((e) => e.id != id).toList();
    state = newState;
    await _save(newState);
  }

  Future<void> _save(List<McpServerEntry> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(servers.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}

class AgentSkillEntry {
  final String id;
  final String name;
  final String description;
  final String endpoint;

  AgentSkillEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.endpoint,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'endpoint': endpoint,
      };

  factory AgentSkillEntry.fromJson(Map<String, dynamic> json) => AgentSkillEntry(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        endpoint: json['endpoint'],
      );
}

final agentSkillRegistryProvider = StateNotifierProvider<AgentSkillRegistryNotifier, List<AgentSkillEntry>>((ref) {
  final notifier = AgentSkillRegistryNotifier();
  notifier.load();
  return notifier;
});

class AgentSkillRegistryNotifier extends StateNotifier<List<AgentSkillEntry>> {
  static const String _key = 'agent_skills';
  
  AgentSkillRegistryNotifier() : super([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      state = jsonList.map((e) => AgentSkillEntry.fromJson(e)).toList();
    }
  }

  Future<void> addSkill(AgentSkillEntry entry) async {
    final newState = [...state, entry];
    state = newState;
    await _save(newState);
  }

  Future<void> removeSkill(String id) async {
    final newState = state.where((e) => e.id != id).toList();
    state = newState;
    await _save(newState);
  }

  Future<void> _save(List<AgentSkillEntry> skills) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(skills.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}

class A2AAgentEntry {
  final String id;
  final String name;
  final String description;
  final String version;
  final String endpoint;
  final List<String> skills;
  final String auth;
  final List<dynamic> devices;
  final String? pairingToken;
  final String? rfwWidgets;

  A2AAgentEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.endpoint,
    required this.skills,
    required this.auth,
    this.devices = const [],
    this.pairingToken,
    this.rfwWidgets,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'version': version,
        'endpoint': endpoint,
        'skills': skills,
        'auth': auth,
        'devices': devices,
        if (pairingToken != null) 'pairingToken': pairingToken,
        if (rfwWidgets != null) 'rfwWidgets': rfwWidgets,
      };

  factory A2AAgentEntry.fromJson(Map<String, dynamic> json) => A2AAgentEntry(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        version: json['version'] ?? '1.0.0',
        endpoint: json['endpoint'],
        skills: List<String>.from(json['skills'] ?? []),
        auth: json['auth'] ?? 'none',
        devices: json['devices'] as List<dynamic>? ?? const [],
        pairingToken: json['pairingToken'] as String?,
        rfwWidgets: json['rfwWidgets'] as String?,
      );
}

final a2aAgentRegistryProvider = StateNotifierProvider<A2AAgentRegistryNotifier, List<A2AAgentEntry>>((ref) {
  final notifier = A2AAgentRegistryNotifier();
  notifier.load();
  return notifier;
});

class A2AAgentRegistryNotifier extends StateNotifier<List<A2AAgentEntry>> {
  static const String _key = 'a2a_agents';
  
  A2AAgentRegistryNotifier() : super([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      state = jsonList.map((e) => A2AAgentEntry.fromJson(e)).toList();
    }
  }

  Future<void> addAgent(A2AAgentEntry entry) async {
    // If agent with same endpoint exists, update it preserving pairingToken
    final existingIndex = state.indexWhere((e) => e.endpoint == entry.endpoint);
    if (existingIndex >= 0) {
      final newState = List<A2AAgentEntry>.from(state);
      final existingToken = state[existingIndex].pairingToken;
      newState[existingIndex] = A2AAgentEntry(
        id: entry.id,
        name: entry.name,
        description: entry.description,
        version: entry.version,
        endpoint: entry.endpoint,
        skills: entry.skills,
        auth: entry.auth,
        devices: entry.devices,
        pairingToken: existingToken,
        rfwWidgets: entry.rfwWidgets,
      );
      state = newState;
    } else {
      final newState = [...state, entry];
      state = newState;
    }
    await _save(state);
  }

  Future<void> updatePairingToken(String id, String token) async {
    final index = state.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final newState = List<A2AAgentEntry>.from(state);
      final entry = newState[index];
      newState[index] = A2AAgentEntry(
        id: entry.id,
        name: entry.name,
        description: entry.description,
        version: entry.version,
        endpoint: entry.endpoint,
        skills: entry.skills,
        auth: entry.auth,
        devices: entry.devices,
        pairingToken: token.trim(),
        rfwWidgets: entry.rfwWidgets,
      );
      state = newState;
      await _save(newState);
    }
  }

  Future<void> removeAgent(String id) async {
    final newState = state.where((e) => e.id != id).toList();
    state = newState;
    await _save(newState);
  }

  Future<void> _save(List<A2AAgentEntry> agents) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(agents.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}

