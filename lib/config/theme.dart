import 'package:flutter/material.dart';

class AppTheme {
  static const _darkBackground = Color(0xFF121212);
  static const _darkSurface = Color(0xFF181818);
  static const _darkSurfaceRaised = Color(0xFF202124);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1C7ED6),
      brightness: Brightness.light,
    );
    return _base(colorScheme);
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1C7ED6),
      brightness: Brightness.dark,
    );
    return _base(colorScheme);
  }

  static ThemeData _base(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    return ThemeData(
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
      fontFamily: 'Roboto',
      useMaterial3: true,
      scaffoldBackgroundColor: isDark
          ? _darkBackground
          : const Color(0xFFF7F9FB),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? _darkBackground : colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: isDark,
        fillColor: isDark ? _darkSurfaceRaised : null,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : colorScheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? _darkSurface : colorScheme.primaryContainer,
        foregroundColor: isDark
            ? const Color(0xFFE7F0FF)
            : colorScheme.onPrimaryContainer,
      ),
    );
  }
}
