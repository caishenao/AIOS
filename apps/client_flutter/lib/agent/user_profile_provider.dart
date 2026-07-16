import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, List<String>>((ref) {
  final notifier = UserProfileNotifier();
  notifier.load();
  return notifier;
});

class UserProfileNotifier extends StateNotifier<List<String>> {
  static const String _key = 'agent_user_profile';
  
  UserProfileNotifier() : super([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      state = jsonList.map((e) => e.toString()).toList();
    }
  }

  Future<void> addFact(String fact) async {
    final newState = [...state, fact];
    state = newState;
    await _save(newState);
  }

  Future<void> removeFact(int index) async {
    if (index >= 0 && index < state.length) {
      final newState = List<String>.from(state)..removeAt(index);
      state = newState;
      await _save(newState);
    }
  }

  Future<void> _save(List<String> facts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(facts);
    await prefs.setString(_key, jsonString);
  }
}
