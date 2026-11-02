import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'home/greeting_section.dart';
import 'home/voice_input_card.dart';
import 'home/suggestion_chips.dart';
import 'home/feature_grid.dart';
import 'home/recent_conversations.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // 1. Greeting
              GreetingSection(
                onSettingsTap: () => context.push('/config'),
              ),

              const SizedBox(height: 20),

              // 2. Voice Input Card
              const VoiceInputCard(),

              const SizedBox(height: 20),

              // 3. Suggestion Chips
              SuggestionChips(
                onSuggestionTap: (text) => _sendCommand(ref, context, text),
              ),

              const SizedBox(height: 28),

              // 4. Feature Grid
              FeatureGrid(
                onFeatureTap: (cmd) => _sendCommand(ref, context, cmd),
              ),

              const SizedBox(height: 28),

              // 5. Recent Conversations
              const RecentConversations(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _sendCommand(WidgetRef ref, BuildContext context, String command) {
    // Navigate to conversation page and send command
    context.push('/conversation', extra: command);
  }
}
