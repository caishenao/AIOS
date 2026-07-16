import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../config/tts_config.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService(ref);
});

class TtsService {
  final Ref ref;
  final FlutterTts _flutterTts = FlutterTts();

  TtsService(this.ref);

  Future<void> _applyConfig() async {
    final config = ref.read(ttsConfigProvider);
    await _flutterTts.setLanguage(config.language);
    await _flutterTts.setSpeechRate(config.rate);
    await _flutterTts.setVolume(config.volume);
    await _flutterTts.setPitch(config.pitch);
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _applyConfig();
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
