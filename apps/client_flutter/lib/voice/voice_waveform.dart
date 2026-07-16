import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class VoiceWaveformWidget extends StatefulWidget {
  final bool isListening;
  const VoiceWaveformWidget({super.key, required this.isListening});

  @override
  State<VoiceWaveformWidget> createState() => _VoiceWaveformWidgetState();
}

class _VoiceWaveformWidgetState extends State<VoiceWaveformWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isListening) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(VoiceWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isListening && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: SiriWavePainter(
            animationValue: _controller.value,
            isListening: widget.isListening,
          ),
          child: const SizedBox(
            width: double.infinity,
            height: 140,
          ),
        );
      },
    );
  }
}

class SiriWavePainter extends CustomPainter {
  final double animationValue;
  final bool isListening;

  SiriWavePainter({required this.animationValue, required this.isListening});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final width = size.width;

    final waves = [
      // Wave 1: Cyan/Blue (Primary)
      _WaveConfig(
        color: const Color(0xFF00E5FF),
        amplitudeFactor: 0.35,
        frequency: 1.5,
        phaseShift: 0.0,
        speed: 2.0,
        strokeWidth: 3.5,
      ),
      // Wave 2: Green/Teal (Secondary)
      _WaveConfig(
        color: const Color(0xFF00FF88),
        amplitudeFactor: 0.28,
        frequency: 2.2,
        phaseShift: 1.5,
        speed: -1.8,
        strokeWidth: 2.5,
      ),
      // Wave 3: Orange/Yellow (Tertiary)
      _WaveConfig(
        color: const Color(0xFFFFB300),
        amplitudeFactor: 0.20,
        frequency: 1.0,
        phaseShift: 3.0,
        speed: 1.2,
        strokeWidth: 2.0,
      ),
    ];

    for (final wave in waves) {
      final paint = Paint()
        ..color = wave.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = wave.strokeWidth
        ..strokeCap = StrokeCap.round;

      // Subtle glow effect
      paint.imageFilter = ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5, tileMode: TileMode.decal);

      final path = Path();
      
      for (double x = 0; x <= width; x += 1.5) {
        final normalizedX = x / width;
        
        // Envelope: 0 at ends, 1 in middle
        final envelope = sin(pi * normalizedX);
        
        // Sine calculations
        final phase = animationValue * 2 * pi * wave.speed + wave.phaseShift;
        final sineVal = sin(normalizedX * 2 * pi * wave.frequency - phase);
        
        // Calculate y coordinate (modulate overall amplitude by listening state)
        final activeAmplitude = isListening ? 1.0 : 0.02;
        final y = centerY + sineVal * (size.height * wave.amplitudeFactor) * envelope * activeAmplitude;
        
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SiriWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isListening != isListening;
  }
}

class _WaveConfig {
  final Color color;
  final double amplitudeFactor;
  final double frequency;
  final double phaseShift;
  final double speed;
  final double strokeWidth;

  _WaveConfig({
    required this.color,
    required this.amplitudeFactor,
    required this.frequency,
    required this.phaseShift,
    required this.speed,
    required this.strokeWidth,
  });
}
