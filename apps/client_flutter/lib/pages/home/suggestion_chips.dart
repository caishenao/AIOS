import 'package:flutter/material.dart';

class SuggestionChips extends StatelessWidget {
  final void Function(String text) onSuggestionTap;

  const SuggestionChips({super.key, required this.onSuggestionTap});

  static const _suggestions = [
    '今天天气怎么样？',
    '帮我设定明天早上7点的闹钟',
    '播放轻音乐',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '你可以这样问我',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: _suggestions.map((text) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => onSuggestionTap(text),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: cs.outline.withAlpha(100),
                      ),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
