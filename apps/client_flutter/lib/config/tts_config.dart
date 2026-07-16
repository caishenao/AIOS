import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsConfig {
  final bool enabled;
  final String language;
  final double rate;
  final double pitch;
  final double volume;

  const TtsConfig({
    required this.enabled,
    required this.language,
    required this.rate,
    required this.pitch,
    required this.volume,
  });

  TtsConfig copyWith({
    bool? enabled,
    String? language,
    double? rate,
    double? pitch,
    double? volume,
  }) {
    return TtsConfig(
      enabled: enabled ?? this.enabled,
      language: language ?? this.language,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
    );
  }
}

class TtsConfigNotifier extends StateNotifier<TtsConfig> {
  static const _enabledKey = 'tts_enabled';
  static const _languageKey = 'tts_language';
  static const _rateKey = 'tts_rate';
  static const _pitchKey = 'tts_pitch';
  static const _volumeKey = 'tts_volume';

  TtsConfigNotifier()
      : super(const TtsConfig(
          enabled: true,
          language: 'zh-CN',
          rate: 0.5,
          pitch: 1.0,
          volume: 1.0,
        )) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = TtsConfig(
      enabled: prefs.getBool(_enabledKey) ?? true,
      language: prefs.getString(_languageKey) ?? 'zh-CN',
      rate: prefs.getDouble(_rateKey) ?? 0.5,
      pitch: prefs.getDouble(_pitchKey) ?? 1.0,
      volume: prefs.getDouble(_volumeKey) ?? 1.0,
    );
  }

  Future<void> setEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, val);
    state = state.copyWith(enabled: val);
  }

  Future<void> setLanguage(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, val);
    state = state.copyWith(language: val);
  }

  Future<void> setRate(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rateKey, val);
    state = state.copyWith(rate: val);
  }

  Future<void> setPitch(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_pitchKey, val);
    state = state.copyWith(pitch: val);
  }

  Future<void> setVolume(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, val);
    state = state.copyWith(volume: val);
  }
}

final ttsConfigProvider = StateNotifierProvider<TtsConfigNotifier, TtsConfig>((ref) {
  return TtsConfigNotifier();
});
