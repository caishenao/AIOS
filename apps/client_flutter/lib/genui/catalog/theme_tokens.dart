import 'package:flutter/material.dart';

class ThemeTokens {
  final Color background;
  final Color surface;
  final Color accent;
  final Color onSurface;
  final Color onAccent;
  final double cardRadius;
  final double baseSpacing;
  final double fontScale;

  const ThemeTokens({
    required this.background,
    required this.surface,
    required this.accent,
    required this.onSurface,
    required this.onAccent,
    required this.cardRadius,
    required this.baseSpacing,
    required this.fontScale,
  });

  static const ThemeTokens minimal = ThemeTokens(
    background: Color(0xFF0B0B0F),
    surface: Color(0xFF16161D),
    accent: Color(0xFF7C5CFF),
    onSurface: Color(0xFFE8E8ED),
    onAccent: Color(0xFFFFFFFF),
    cardRadius: 20.0,
    baseSpacing: 16.0,
    fontScale: 1.15,
  );

  factory ThemeTokens.fromJson(Map<String, dynamic>? json) {
    if (json == null) return minimal;
    
    Color parseColor(String? hex, Color fallback) {
      if (hex == null || !hex.startsWith('#')) return fallback;
      try {
        return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
      } catch (_) {
        return fallback;
      }
    }

    return ThemeTokens(
      background: parseColor(json['color.background'], minimal.background),
      surface: parseColor(json['color.surface'], minimal.surface),
      accent: parseColor(json['color.accent'], minimal.accent),
      onSurface: parseColor(json['color.onSurface'], minimal.onSurface),
      onAccent: parseColor(json['color.onAccent'], minimal.onAccent),
      cardRadius: (json['radius.card'] as num?)?.toDouble() ?? minimal.cardRadius,
      baseSpacing: (json['spacing.base'] as num?)?.toDouble() ?? minimal.baseSpacing,
      fontScale: (json['font.scale'] as num?)?.toDouble() ?? minimal.fontScale,
    );
  }

  ThemeTokens merge(ThemeTokens other) {
    return ThemeTokens(
      background: other.background,
      surface: other.surface,
      accent: other.accent,
      onSurface: other.onSurface,
      onAccent: other.onAccent,
      cardRadius: other.cardRadius,
      baseSpacing: other.baseSpacing,
      fontScale: other.fontScale,
    );
  }
}
