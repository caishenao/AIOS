import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

final sttServiceProvider = Provider<SttService>((ref) {
  return SttService(ref);
});

final isListeningProvider = StateProvider<bool>((ref) => false);
final recognizedTextProvider = StateProvider<String>((ref) => '');

class SttService {
  final Ref ref;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  SttService(this.ref);

  Future<bool> init() async {
    if (!_isInitialized) {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            ref.read(isListeningProvider.notifier).state = false;
          }
        },
        onError: (errorNotification) {
          ref.read(isListeningProvider.notifier).state = false;
        },
      );
    }
    return _isInitialized;
  }

  Future<void> startListening() async {
    bool available = await init();
    if (available) {
      ref.read(isListeningProvider.notifier).state = true;
      ref.read(recognizedTextProvider.notifier).state = '';
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          ref.read(recognizedTextProvider.notifier).state = result.recognizedWords;
        },
        listenMode: stt.ListenMode.dictation,
      );
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
    ref.read(isListeningProvider.notifier).state = false;
  }
}
