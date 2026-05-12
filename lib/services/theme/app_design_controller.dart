import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_design_mode.dart';
import '../storage/preferences_service.dart';

class AppDesignController extends AsyncNotifier<AppDesignMode> {
  @override
  Future<AppDesignMode> build() async {
    final prefs = ref.read(preferencesServiceProvider);
    return prefs.getAppDesignMode();
  }

  Future<void> setMode(AppDesignMode mode) async {
    final current = state.valueOrNull;
    if (current == mode) return;
    state = AsyncData(mode);
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setAppDesignMode(mode);
  }
}

final appDesignControllerProvider =
    AsyncNotifierProvider<AppDesignController, AppDesignMode>(
      AppDesignController.new,
    );
