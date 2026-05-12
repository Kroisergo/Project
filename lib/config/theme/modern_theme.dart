import 'package:flutter/material.dart';

import '../../models/app_design_mode.dart';
import 'design_tokens.dart';

class ModernTheme {
  static ThemeData light() => buildEncryVaultTheme(_lightTokens);

  static ThemeData dark() => buildEncryVaultTheme(_darkTokens);

  static final _lightTokens = EncryVaultTheme(
    designMode: AppDesignMode.modern,
    isDark: false,
    background: const Color(0xFFF1F7FC),
    surface: const Color(0xFFFAFDFF),
    surfaceRaised: const Color(0xFFE9F2FA),
    inputFill: const Color(0xFFF7FBFE),
    border: const Color(0xFFB8CBE0),
    strongBorder: const Color(0xFF9AB5D0),
    accent: const Color(0xFF0060A6),
    accentSoft: const Color(0xFFE2F0FB),
    accentMuted: const Color(0xFF2578B6),
    onAccent: Colors.white,
    textPrimary: const Color(0xFF121D2B),
    textSecondary: const Color(0xFF374960),
    textMuted: const Color(0xFF6A7A8C),
    danger: const Color(0xFFD92D20),
    warning: const Color(0xFFB76E00),
    success: const Color(0xFF12805C),
    favorite: const Color(0xFFB7791F),
    cardRadius: 20,
    inputRadius: 16,
    buttonRadius: 16,
    chipRadius: 12,
    pagePadding: 20,
    sectionGap: 24,
    cardGap: 12,
    buttonHeight: 52,
    cardElevation: 1,
    cardShadow: [
      BoxShadow(
        color: const Color(0xFF2B3E52).withValues(alpha: 0.12),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
    usesSoftGradient: true,
  );

  static final _darkTokens = EncryVaultTheme(
    designMode: AppDesignMode.modern,
    isDark: true,
    background: const Color(0xFF030812),
    surface: const Color(0xFF0F1B2E),
    surfaceRaised: const Color(0xFF16253E),
    inputFill: const Color(0xFF0F1B2E),
    border: const Color(0xFF31405C),
    strongBorder: const Color(0xFF3F5373),
    accent: const Color(0xFF32D5FF),
    accentSoft: const Color(0xFF0B344F),
    accentMuted: const Color(0xFF468BFF),
    onAccent: const Color(0xFF030812),
    textPrimary: const Color(0xFFEFF6FF),
    textSecondary: const Color(0xFF94A3B8),
    textMuted: const Color(0xFF5C708A),
    danger: const Color(0xFFFF6B6B),
    warning: const Color(0xFFFFC857),
    success: const Color(0xFF66D19E),
    favorite: const Color(0xFFFFD166),
    cardRadius: 20,
    inputRadius: 16,
    buttonRadius: 16,
    chipRadius: 12,
    pagePadding: 20,
    sectionGap: 24,
    cardGap: 12,
    buttonHeight: 52,
    cardElevation: 1,
    cardShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 30,
        offset: const Offset(0, 14),
      ),
    ],
    usesSoftGradient: true,
  );
}
