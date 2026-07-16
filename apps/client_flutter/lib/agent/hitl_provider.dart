import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HitlRequest {
  final String title;
  final String details;
  final Completer<bool> completer;

  HitlRequest({
    required this.title,
    required this.details,
    required this.completer,
  });
}

final hitlProvider = StateNotifierProvider<HitlNotifier, HitlRequest?>((ref) {
  return HitlNotifier();
});

class HitlNotifier extends StateNotifier<HitlRequest?> {
  HitlNotifier() : super(null);

  Future<bool> requestConfirmation(String title, String details) async {
    // Complete existing request if any to avoid deadlocks
    if (state != null) {
      if (!state!.completer.isCompleted) {
        state!.completer.complete(false);
      }
    }
    
    final completer = Completer<bool>();
    state = HitlRequest(title: title, details: details, completer: completer);
    
    final result = await completer.future;
    state = null;
    return result;
  }

  void approve() {
    if (state != null && !state!.completer.isCompleted) {
      state!.completer.complete(true);
    }
  }

  void reject() {
    if (state != null && !state!.completer.isCompleted) {
      state!.completer.complete(false);
    }
  }
}
