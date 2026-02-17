import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_service.dart';

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = ref.read(preferencesServiceProvider);
    return prefs.getThemeMode();
  }

  Future<void> setMode(ThemeMode mode) async {
    final current = state.valueOrNull;
    if (current == mode) return;
    state = AsyncData(mode);
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setThemeMode(mode);
  }
}

final themeModeControllerProvider = AsyncNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
