import 'package:flutter/material.dart';

import '../../models/app_design_mode.dart';
import 'design_tokens.dart';

class ClassicTheme {
  static ThemeData light() => buildEncryVaultTheme(_lightTokens);

  static ThemeData dark() => buildEncryVaultTheme(_darkTokens);

  static final _lightTokens = EncryVaultTheme(
    designMode: AppDesignMode.classic,
    isDark: false,
    background: const Color(0xFFF4F7FA),
    surface: const Color(0xFFFAFBFD),
    surfaceRaised: const Color(0xFFEFF4F9),
    inputFill: const Color(0xFFFAFBFD),
    border: const Color(0xFFBEC9D7),
    strongBorder: const Color(0xFFA5B4C6),
    accent: const Color(0xFF2A5784),
    accentSoft: const Color(0xFFE6ECF3),
    accentMuted: const Color(0xFF4A759F),
    onAccent: Colors.white,
    textPrimary: const Color(0xFF18202B),
    textSecondary: const Color(0xFF3E4C5E),
    textMuted: const Color(0xFF667386),
    danger: const Color(0xFFB42318),
    warning: const Color(0xFF9A6700),
    success: const Color(0xFF0F766E),
    favorite: const Color(0xFF9A6700),
    cardRadius: 10,
    inputRadius: 10,
    buttonRadius: 10,
    chipRadius: 10,
    pagePadding: 20,
    sectionGap: 22,
    cardGap: 10,
    buttonHeight: 50,
    cardElevation: 0,
    cardShadow: [
      BoxShadow(
        color: const Color(0xFF333C48).withValues(alpha: 0.08),
        blurRadius: 12,
        offset: const Offset(0, 8),
      ),
    ],
    usesSoftGradient: false,
  );

  static final _darkTokens = EncryVaultTheme(
    designMode: AppDesignMode.classic,
    isDark: true,
    background: const Color(0xFF0A0F16),
    surface: const Color(0xFF121B27),
    surfaceRaised: const Color(0xFF182331),
    inputFill: const Color(0xFF0C121B),
    border: const Color(0xFF303D4E),
    strongBorder: const Color(0xFF435268),
    accent: const Color(0xFF4884BE),
    accentSoft: const Color(0xFF182331),
    accentMuted: const Color(0xFF5C96CC),
    onAccent: const Color(0xFFEAEFF5),
    textPrimary: const Color(0xFFEAEFF5),
    textSecondary: const Color(0xFFB9C5D3),
    textMuted: const Color(0xFF7F8D9E),
    danger: const Color(0xFFFF7A70),
    warning: const Color(0xFFE6B450),
    success: const Color(0xFF79C6A6),
    favorite: const Color(0xFFE6B450),
    cardRadius: 10,
    inputRadius: 10,
    buttonRadius: 10,
    chipRadius: 10,
    pagePadding: 20,
    sectionGap: 22,
    cardGap: 10,
    buttonHeight: 50,
    cardElevation: 0,
    cardShadow: const [],
    usesSoftGradient: false,
  );
}
