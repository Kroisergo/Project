import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screen_protection_service.dart';

class ScreenProtectionController {
  ScreenProtectionController({required this.service});

  final ScreenProtectionService service;
  bool _lastEnabled = false;

  Future<void> ensureEnabledByDefault() async {
    if (_lastEnabled) return;
    _lastEnabled = true;
    await service.enable();
  }

  Future<void> syncForVaultState(bool isUnlocked) async {
    await ensureEnabledByDefault();
  }
}

final screenProtectionControllerProvider = Provider<ScreenProtectionController>(
  (ref) {
    return ScreenProtectionController(
      service: ref.read(screenProtectionServiceProvider),
    );
  },
);
