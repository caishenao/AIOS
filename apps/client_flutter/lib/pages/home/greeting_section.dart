import 'package:flutter/material.dart';

class GreetingSection extends StatelessWidget {
  final VoidCallback? onSettingsTap;

  const GreetingSection({super.key, this.onSettingsTap});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了 🌙';
    if (hour < 12) return '早上好 ☀️';
    if (hour < 18) return '下午好 👋';
    return '晚上好 🌆';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left text ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '我是你的语音智能管家',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '有问题尽管问我，我随时为你服务',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // ── Right: AI Avatar + Settings ──
          Column(
            children: [
              // Settings gear
              GestureDetector(
                onTap: onSettingsTap,
                child: Icon(
                  Icons.settings_outlined,
                  size: 22,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              // AI Robot avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary.withAlpha(30),
                      cs.secondary.withAlpha(30),
                    ],
                  ),
                  border: Border.all(
                    color: cs.primary.withAlpha(40),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 36,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
