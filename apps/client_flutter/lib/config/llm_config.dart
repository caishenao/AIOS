import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LlmConfig {
  final String provider; // 'openai', 'claude', 'gemini'
  final String baseUrl;
  final String apiKey;
  final String model;

  const LlmConfig({
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  LlmConfig copyWith({
    String? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return LlmConfig(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}

class LlmConfigNotifier extends StateNotifier<LlmConfig> {
  static const _providerKey = 'llm_provider';
  static const _baseUrlKey = 'llm_base_url';
  static const _apiKeyKey = 'llm_api_key';
  static const _modelKey = 'llm_model';

  LlmConfigNotifier()
      : super(const LlmConfig(
          provider: 'openai',
          baseUrl: 'https://tokunex.com/v1',
          apiKey: 'sk-ZrMyqG5rkN89OTkhmN7fdpQOeeKx3nZuBNKIZjHfiwox01fh',
          model: 'gpt-5.6-sol',
        )) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString(_providerKey) ?? 'openai';
    var baseUrl = prefs.getString(_baseUrlKey) ?? 'https://tokunex.com/v1';
    var apiKey = prefs.getString(_apiKeyKey) ?? 'sk-ZrMyqG5rkN89OTkhmN7fdpQOeeKx3nZuBNKIZjHfiwox01fh';
    var model = prefs.getString(_modelKey) ?? 'gpt-5.6-sol';

    if (apiKey.contains('zy-bad3eb147a89e2e21b89d2310dc17ff862ff04ef55f82d8d') || apiKey.isEmpty) {
      baseUrl = 'https://tokunex.com/v1';
      apiKey = 'sk-ZrMyqG5rkN89OTkhmN7fdpQOeeKx3nZuBNKIZjHfiwox01fh';
      model = 'gpt-5.6-sol';
      await prefs.setString(_baseUrlKey, baseUrl);
      await prefs.setString(_apiKeyKey, apiKey);
      await prefs.setString(_modelKey, model);
    }

    state = LlmConfig(
      provider: provider,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
    );
  }

  Future<void> setConfig(LlmConfig config) async {
    state = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, config.provider);
    await prefs.setString(_baseUrlKey, config.baseUrl);
    await prefs.setString(_apiKeyKey, config.apiKey);
    await prefs.setString(_modelKey, config.model);
  }
}

final llmConfigProvider = StateNotifierProvider<LlmConfigNotifier, LlmConfig>((ref) {
  return LlmConfigNotifier();
});
