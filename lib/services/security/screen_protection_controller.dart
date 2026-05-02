import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_service.dart';
import 'screen_protection_service.dart';

class ScreenProtectionController {
  ScreenProtectionController({
    required this.service,
    PreferencesService? preferences,
  }) : _preferences = preferences ?? PreferencesService();

  final ScreenProtectionService service;
  final PreferencesService _preferences;
  bool? _lastAppliedEnabled;

  Future<void> ensureEnabledByDefault() async {
    await syncProtectionSettings();
  }

  Future<void> syncForVaultState(bool isUnlocked) async {
    await syncProtectionSettings();
  }

  Future<void> syncProtectionSettings() async {
    final protectScreenshots = await _preferences.getProtectScreenshots();
    final protectScreenRecording = await _preferences
        .getProtectScreenRecording();
    final shouldEnable = protectScreenshots || protectScreenRecording;
    if (_lastAppliedEnabled == shouldEnable) return;
    _lastAppliedEnabled = shouldEnable;
    await service.setEnabled(shouldEnable);
  }
}

final screenProtectionControllerProvider = Provider<ScreenProtectionController>(
  (ref) {
    return ScreenProtectionController(
      service: ref.read(screenProtectionServiceProvider),
      preferences: ref.read(preferencesServiceProvider),
    );
  },
);
