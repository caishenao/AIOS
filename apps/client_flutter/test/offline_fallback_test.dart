import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_steward/agent/local_agent_service.dart';
import 'package:home_steward/config/capability_registry.dart';
import 'package:home_steward/config/llm_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('LocalAgentService offline client fallback parsing test', () async {
    final container = ProviderContainer();
    
    // Add target mock agent
    final agent = A2AAgentEntry(
      id: 'mock_daemon',
      name: 'Mock Gateway',
      description: 'Desc',
      version: '1.0.0',
      endpoint: 'http://localhost:9999', // unreachable
      skills: [],
      auth: 'none',
    );
    await container.read(a2aAgentRegistryProvider.notifier).addAgent(agent);

    // Set config to use an unreachable host
    await container.read(llmConfigProvider.notifier).setConfig(const LlmConfig(
      provider: 'openai',
      apiKey: 'fake_key',
      model: 'gpt-4',
      baseUrl: 'http://localhost:9998', // unreachable
    ));

    final service = container.read(localAgentProvider);

    // Call sendMessage with an unreachable LLM server to trigger SocketException fallback
    final response = await service.sendMessage('打开客厅的灯');

    expect(response.textReply, contains('【本地应急模式】已为您打开客厅主灯'));
  });
}
