import 'package:flutter/material.dart';

class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String command;

  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.command,
  });
}

class FeatureGrid extends StatelessWidget {
  final void Function(String command) onFeatureTap;

  const FeatureGrid({super.key, required this.onFeatureTap});

  static const _features = <_Feature>[
    _Feature(
      icon: Icons.wb_sunny_outlined,
      title: '天气查询',
      subtitle: '查询天气信息',
      color: Color(0xFFF59E0B),
      command: '今天天气怎么样',
    ),
    _Feature(
      icon: Icons.calendar_today_outlined,
      title: '日程管理',
      subtitle: '管理日程安排',
      color: Color(0xFFEF4444),
      command: '帮我看看今天的日程',
    ),
    _Feature(
      icon: Icons.alarm_outlined,
      title: '闹钟提醒',
      subtitle: '设置闹钟提醒',
      color: Color(0xFF8B5CF6),
      command: '设置一个闹钟',
    ),
    _Feature(
      icon: Icons.home_outlined,
      title: '智能家居',
      subtitle: '控制智能设备',
      color: Color(0xFF10B981),
      command: '打开客厅灯',
    ),
    _Feature(
      icon: Icons.music_note_outlined,
      title: '音乐播放',
      subtitle: '播放你喜欢的音乐',
      color: Color(0xFFEC4899),
      command: '播放轻音乐',
    ),
    _Feature(
      icon: Icons.menu_book_outlined,
      title: '百科问答',
      subtitle: '各种知识解答',
      color: Color(0xFF3B82F6),
      command: '什么是量子计算',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Title row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '常用功能',
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

        // Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: _features.map((f) {
              return GestureDetector(
                onTap: () => onFeatureTap(f.command),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline.withAlpha(60)),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: f.color.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(f.icon, color: f.color, size: 24),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        f.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        f.subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
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
