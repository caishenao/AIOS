import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ChatHistoryEntry {
  final String id;
  final DateTime timestamp;
  final String userMessage;
  final String? textReply;
  final Map<String, dynamic>? uiTree;

  ChatHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.userMessage,
    this.textReply,
    this.uiTree,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'userMessage': userMessage,
        'textReply': textReply,
        'uiTree': uiTree,
      };

  factory ChatHistoryEntry.fromJson(Map<String, dynamic> json) => ChatHistoryEntry(
        id: json['id'],
        timestamp: DateTime.parse(json['timestamp']),
        userMessage: json['userMessage'],
        textReply: json['textReply'],
        uiTree: json['uiTree'] as Map<String, dynamic>?,
      );
}

final chatHistoryProvider = StateNotifierProvider<ChatHistoryNotifier, List<ChatHistoryEntry>>((ref) {
  final notifier = ChatHistoryNotifier();
  notifier.load();
  return notifier;
});

final chatHistorySearchQueryProvider = StateProvider<String>((ref) => '');

class ChatHistoryNotifier extends StateNotifier<List<ChatHistoryEntry>> {
  static const String _key = 'chat_history';

  ChatHistoryNotifier() : super([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      state = jsonList.map((e) => ChatHistoryEntry.fromJson(e)).toList();
    }
  }

  Future<void> addEntry(String userMessage, {String? textReply, Map<String, dynamic>? uiTree}) async {
    final entry = ChatHistoryEntry(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      userMessage: userMessage,
      textReply: textReply,
      uiTree: uiTree,
    );
    final newState = [entry, ...state]; // newest first
    state = newState;
    await _save(newState);
  }

  Future<void> deleteEntry(String id) async {
    final newState = state.where((e) => e.id != id).toList();
    state = newState;
    await _save(newState);
  }

  Future<void> clearHistory() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _save(List<ChatHistoryEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}
