import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../voice/stt_service.dart';
import '../../voice/voice_waveform.dart';

class VoiceInputCard extends ConsumerStatefulWidget {
  const VoiceInputCard({super.key});

  @override
  ConsumerState<VoiceInputCard> createState() => _VoiceInputCardState();
}

class _VoiceInputCardState extends ConsumerState<VoiceInputCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isListening = ref.watch(isListeningProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top row: language selector + voice history ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Language selector
              Row(
                children: [
                  Icon(Icons.mic_none, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '普通话',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
              // Voice history
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '语音历史',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Center: Waveform + Mic button ──
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left waveform bars
                Expanded(
                  child: isListening
                      ? VoiceWaveformWidget(isListening: isListening)
                      : _StaticWaveform(color: cs.primary),
                ),

                const SizedBox(width: 16),

                // Mic button
                GestureDetector(
                  onTap: () {
                    if (isListening) {
                      ref.read(sttServiceProvider).stopListening();
                    } else {
                      ref.read(sttServiceProvider).startListening();
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = isListening
                          ? 1.0 + _pulseController.value * 0.08
                          : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                cs.primary,
                                cs.primary.withAlpha(200),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withAlpha(
                                  isListening ? 120 : 60,
                                ),
                                blurRadius: isListening ? 30 : 16,
                                spreadRadius: isListening ? 4 : 0,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mic,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Right waveform bars
                Expanded(
                  child: isListening
                      ? VoiceWaveformWidget(isListening: isListening)
                      : _StaticWaveform(color: cs.primary, reverse: true),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Bottom text ──
          Text(
            isListening ? '正在聆听...' : '点击说话',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isListening ? cs.primary : cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '松手结束',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// Static waveform bars decoration (shown when not listening)
class _StaticWaveform extends StatelessWidget {
  final Color color;
  final bool reverse;

  const _StaticWaveform({required this.color, this.reverse = false});

  @override
  Widget build(BuildContext context) {
    final heights = [8, 14, 10, 20, 12, 26, 16, 30, 18, 14, 10, 22, 8, 16, 12];
    final list = reverse ? heights.reversed.toList() : heights;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: list.map((h) {
        return Container(
          width: 3,
          height: h.toDouble(),
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: color.withAlpha(40 + (h % 3) * 15),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }
}
