import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/chat_history.dart';

class RecentConversations extends ConsumerWidget {
  const RecentConversations({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final history = ref.watch(chatHistoryProvider);
    final recent = history.take(3).toList();

    return Column(
      children: [
        // Title row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最近对话',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  '更多 >',
                  style: TextStyle(fontSize: 13, color: cs.primary),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 36,
                  color: cs.onSurfaceVariant.withAlpha(80),
                ),
                const SizedBox(height: 8),
                Text(
                  '暂无对话记录',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '点击麦克风开始对话吧',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withAlpha(150),
                  ),
                ),
              ],
            ),
          )
        else
          ...recent.map((entry) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withAlpha(60)),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconForEntry(entry),
                      size: 20,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.userMessage,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.textReply ?? '生成了界面',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Time
                  Text(
                    _formatTime(entry.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  IconData _iconForEntry(ChatHistoryEntry entry) {
    final msg = entry.userMessage.toLowerCase();
    if (msg.contains('天气')) return Icons.wb_sunny_outlined;
    if (msg.contains('音乐') || msg.contains('播放')) return Icons.music_note_outlined;
    if (msg.contains('闹钟') || msg.contains('提醒')) return Icons.alarm_outlined;
    if (msg.contains('日程') || msg.contains('安排')) return Icons.calendar_today_outlined;
    if (msg.contains('灯') || msg.contains('家居') || msg.contains('设备')) return Icons.home_outlined;
    return Icons.chat_bubble_outline;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(entryDay).inDays;

    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');

    if (diff == 0) return '$h:$m';
    if (diff == 1) return '昨天 $h:$m';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}
