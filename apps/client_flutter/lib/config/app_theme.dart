import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Theme Mode Provider
// ---------------------------------------------------------------------------

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key);
    if (index != null && index < ThemeMode.values.length) {
      state = ThemeMode.values[index];
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// ---------------------------------------------------------------------------
// App Theme
// ---------------------------------------------------------------------------

class AppTheme {
  AppTheme._();

  // ── Light ──────────────────────────────────────────────────────────────

  static const _lightColorScheme = ColorScheme.light(
    surface: Color(0xFFFFFFFF),
    surfaceContainerHighest: Color(0xFFEEF1F8),
    primary: Color(0xFF4A6CF7),
    primaryContainer: Color(0xFFE8EDFF),
    secondary: Color(0xFF7C5CFF),
    secondaryContainer: Color(0xFFF0ECFF),
    onSurface: Color(0xFF1A1D26),
    onSurfaceVariant: Color(0xFF6B7280),
    outline: Color(0xFFE2E5ED),
    shadow: Color(0x0A000000),
  );

  static ThemeData lightTheme() {
    const cs = _lightColorScheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: cs.surface,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        foregroundColor: Color(0xFF1A1D26),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outline,
        thickness: 0.5,
      ),
    );
  }

  // ── Dark ───────────────────────────────────────────────────────────────

  static const _darkColorScheme = ColorScheme.dark(
    surface: Color(0xFF161B26),
    surfaceContainerHighest: Color(0xFF1E2433),
    primary: Color(0xFF6B8AFF),
    primaryContainer: Color(0xFF2A3565),
    secondary: Color(0xFF9B7FFF),
    secondaryContainer: Color(0xFF2D2554),
    onSurface: Color(0xFFE8ECF4),
    onSurfaceVariant: Color(0xFF9CA3AF),
    outline: Color(0xFF2A2F3C),
    shadow: Color(0x33000000),
  );

  static ThemeData darkTheme() {
    const cs = _darkColorScheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: const Color(0xFF0B0E14),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: cs.surface,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        foregroundColor: Color(0xFFE8ECF4),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outline,
        thickness: 0.5,
      ),
    );
  }
}
