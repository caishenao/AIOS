import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_steward/config/chat_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Test ChatHistoryNotifier CRUD operations', () async {
    final container = ProviderContainer();

    // 1. Initial history is empty
    var history = container.read(chatHistoryProvider);
    expect(history.isEmpty, true);

    // 2. Add an entry
    final userMsg = '北京天气怎么样？';
    final textReply = '北京今天晴朗，22度。';
    final uiTree = {
      'component': 'WeatherCard',
      'props': {'location': '北京', 'temp': '22°C'}
    };

    await container.read(chatHistoryProvider.notifier).addEntry(
          userMsg,
          textReply: textReply,
          uiTree: uiTree,
        );

    history = container.read(chatHistoryProvider);
    expect(history.length, 1);
    expect(history.first.userMessage, userMsg);
    expect(history.first.textReply, textReply);
    expect(history.first.uiTree?['component'], 'WeatherCard');

    // 3. Add second entry
    await container.read(chatHistoryProvider.notifier).addEntry('关灯');

    history = container.read(chatHistoryProvider);
    expect(history.length, 2);
    expect(history.first.userMessage, '关灯');
    expect(history.last.userMessage, userMsg); // LIFO order (newest first)

    // 4. Delete an entry
    final entryToDelete = history.first;
    await container.read(chatHistoryProvider.notifier).deleteEntry(entryToDelete.id);

    history = container.read(chatHistoryProvider);
    expect(history.length, 1);
    expect(history.first.userMessage, userMsg);

    // 5. Clear history
    await container.read(chatHistoryProvider.notifier).clearHistory();
    history = container.read(chatHistoryProvider);
    expect(history.isEmpty, true);
  });
}
