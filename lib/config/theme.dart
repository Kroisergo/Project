import 'package:flutter/material.dart';

import '../models/app_design_mode.dart';
import 'theme/classic_theme.dart';
import 'theme/modern_theme.dart';

class AppTheme {
  static ThemeData light(AppDesignMode designMode) {
    switch (designMode) {
      case AppDesignMode.modern:
        return ModernTheme.light();
      case AppDesignMode.classic:
        return ClassicTheme.light();
    }
  }

  static ThemeData dark(AppDesignMode designMode) {
    switch (designMode) {
      case AppDesignMode.modern:
        return ModernTheme.dark();
      case AppDesignMode.classic:
        return ClassicTheme.dark();
    }
  }
}
