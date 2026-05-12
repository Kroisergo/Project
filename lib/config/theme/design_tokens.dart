import 'package:flutter/material.dart';

import '../../models/app_design_mode.dart';

@immutable
class EncryVaultTheme extends ThemeExtension<EncryVaultTheme> {
  const EncryVaultTheme({
    required this.designMode,
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.inputFill,
    required this.border,
    required this.strongBorder,
    required this.accent,
    required this.accentSoft,
    required this.accentMuted,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.danger,
    required this.warning,
    required this.success,
    required this.favorite,
    required this.cardRadius,
    required this.inputRadius,
    required this.buttonRadius,
    required this.chipRadius,
    required this.pagePadding,
    required this.sectionGap,
    required this.cardGap,
    required this.buttonHeight,
    required this.cardElevation,
    required this.cardShadow,
    required this.usesSoftGradient,
  });

  final AppDesignMode designMode;
  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color inputFill;
  final Color border;
  final Color strongBorder;
  final Color accent;
  final Color accentSoft;
  final Color accentMuted;
  final Color onAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color danger;
  final Color warning;
  final Color success;
  final Color favorite;
  final double cardRadius;
  final double inputRadius;
  final double buttonRadius;
  final double chipRadius;
  final double pagePadding;
  final double sectionGap;
  final double cardGap;
  final double buttonHeight;
  final double cardElevation;
  final List<BoxShadow> cardShadow;
  final bool usesSoftGradient;

  static EncryVaultTheme of(BuildContext context) {
    final extension = Theme.of(context).extension<EncryVaultTheme>();
    assert(extension != null, 'EncryVaultTheme is missing from ThemeData');
    return extension!;
  }

  @override
  EncryVaultTheme copyWith({
    AppDesignMode? designMode,
    bool? isDark,
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? inputFill,
    Color? border,
    Color? strongBorder,
    Color? accent,
    Color? accentSoft,
    Color? accentMuted,
    Color? onAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? danger,
    Color? warning,
    Color? success,
    Color? favorite,
    double? cardRadius,
    double? inputRadius,
    double? buttonRadius,
    double? chipRadius,
    double? pagePadding,
    double? sectionGap,
    double? cardGap,
    double? buttonHeight,
    double? cardElevation,
    List<BoxShadow>? cardShadow,
    bool? usesSoftGradient,
  }) {
    return EncryVaultTheme(
      designMode: designMode ?? this.designMode,
      isDark: isDark ?? this.isDark,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      inputFill: inputFill ?? this.inputFill,
      border: border ?? this.border,
      strongBorder: strongBorder ?? this.strongBorder,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentMuted: accentMuted ?? this.accentMuted,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      favorite: favorite ?? this.favorite,
      cardRadius: cardRadius ?? this.cardRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      chipRadius: chipRadius ?? this.chipRadius,
      pagePadding: pagePadding ?? this.pagePadding,
      sectionGap: sectionGap ?? this.sectionGap,
      cardGap: cardGap ?? this.cardGap,
      buttonHeight: buttonHeight ?? this.buttonHeight,
      cardElevation: cardElevation ?? this.cardElevation,
      cardShadow: cardShadow ?? this.cardShadow,
      usesSoftGradient: usesSoftGradient ?? this.usesSoftGradient,
    );
  }

  @override
  EncryVaultTheme lerp(ThemeExtension<EncryVaultTheme>? other, double t) {
    if (other is! EncryVaultTheme) return this;
    return EncryVaultTheme(
      designMode: t < 0.5 ? designMode : other.designMode,
      isDark: t < 0.5 ? isDark : other.isDark,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      border: Color.lerp(border, other.border, t)!,
      strongBorder: Color.lerp(strongBorder, other.strongBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      inputRadius: lerpDouble(inputRadius, other.inputRadius, t),
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t),
      chipRadius: lerpDouble(chipRadius, other.chipRadius, t),
      pagePadding: lerpDouble(pagePadding, other.pagePadding, t),
      sectionGap: lerpDouble(sectionGap, other.sectionGap, t),
      cardGap: lerpDouble(cardGap, other.cardGap, t),
      buttonHeight: lerpDouble(buttonHeight, other.buttonHeight, t),
      cardElevation: lerpDouble(cardElevation, other.cardElevation, t),
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      usesSoftGradient: t < 0.5 ? usesSoftGradient : other.usesSoftGradient,
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

ThemeData buildEncryVaultTheme(EncryVaultTheme tokens) {
  final isClassic = tokens.designMode == AppDesignMode.classic;
  final brightness = tokens.isDark ? Brightness.dark : Brightness.light;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: tokens.accent,
    brightness: brightness,
  );
  final scheme = baseScheme.copyWith(
    primary: tokens.accent,
    onPrimary: tokens.onAccent,
    secondary: tokens.accentMuted,
    surface: tokens.surface,
    onSurface: tokens.textPrimary,
    error: tokens.danger,
    outline: tokens.border,
    surfaceContainerHighest: tokens.surfaceRaised,
  );

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(tokens.inputRadius),
    borderSide: BorderSide(color: tokens.border),
  );
  final focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(tokens.inputRadius),
    borderSide: BorderSide(color: tokens.accent, width: 1.4),
  );

  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: 'Roboto',
    useMaterial3: true,
    scaffoldBackgroundColor: tokens.background,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: isClassic ? tokens.inputFill : tokens.background,
      foregroundColor: tokens.textPrimary,
      centerTitle: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: tokens.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.inputFill,
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: tokens.danger),
      ),
      focusedErrorBorder: focusedBorder.copyWith(
        borderSide: BorderSide(color: tokens.danger, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: tokens.textSecondary),
      hintStyle: TextStyle(color: tokens.textMuted),
    ),
    textTheme: ThemeData(brightness: brightness).textTheme
        .apply(bodyColor: tokens.textPrimary, displayColor: tokens.textPrimary)
        .copyWith(
          bodySmall: TextStyle(color: tokens.textSecondary, fontSize: 13),
          bodyMedium: TextStyle(color: tokens.textSecondary, fontSize: 14),
          bodyLarge: TextStyle(color: tokens.textPrimary, fontSize: 16),
          labelMedium: TextStyle(
            color: tokens.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: TextStyle(
            color: tokens.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: tokens.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            color: tokens.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: TextStyle(
            color: tokens.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
    dividerTheme: DividerThemeData(color: tokens.border, thickness: 1),
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: tokens.cardElevation,
      shadowColor: tokens.cardShadow.isEmpty
          ? Colors.transparent
          : tokens.cardShadow.first.color,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        side: BorderSide(color: tokens.border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.surfaceRaised,
      selectedColor: tokens.accentSoft,
      disabledColor: tokens.surfaceRaised.withValues(alpha: 0.55),
      labelStyle: TextStyle(
        color: tokens.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: TextStyle(
        color: tokens.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: tokens.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.chipRadius),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.accent.withValues(alpha: tokens.isDark ? 0.18 : 0.1);
          }
          return tokens.surfaceRaised;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return tokens.textPrimary;
          return tokens.textSecondary;
        }),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? tokens.accent.withValues(alpha: tokens.isDark ? 0.62 : 0.44)
                : tokens.border,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.chipRadius),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: tokens.accent,
      textColor: tokens.textPrimary,
      titleTextStyle: TextStyle(
        color: tokens.textPrimary,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: TextStyle(
        color: tokens.textSecondary,
        fontSize: 13,
        height: 1.25,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.accent,
        minimumSize: Size.fromHeight(tokens.buttonHeight),
        side: BorderSide(color: tokens.strongBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.buttonRadius),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.onAccent,
        disabledBackgroundColor: tokens.surfaceRaised,
        disabledForegroundColor: tokens.textMuted,
        minimumSize: Size.fromHeight(tokens.buttonHeight),
        elevation: tokens.cardElevation,
        shadowColor: tokens.cardShadow.isEmpty
            ? Colors.transparent
            : tokens.cardShadow.first.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.buttonRadius),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tokens.accent,
      foregroundColor: tokens.onAccent,
      elevation: tokens.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.buttonRadius),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.inputFill,
        border: border,
        enabledBorder: border,
        focusedBorder: focusedBorder,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.surfaceRaised,
      contentTextStyle: TextStyle(color: tokens.textPrimary),
      actionTextColor: tokens.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
      ),
    ),
  );
}
