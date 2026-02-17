import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screen_protection_service.dart';

class ScreenProtectionController {
  ScreenProtectionController({
    required this.service,
  });

  final ScreenProtectionService service;
  bool _lastEnabled = false;

  Future<void> syncForVaultState(bool isUnlocked) async {
    if (_lastEnabled == isUnlocked) return;
    _lastEnabled = isUnlocked;
    await service.setEnabled(isUnlocked);
  }
}

final screenProtectionControllerProvider = Provider<ScreenProtectionController>((ref) {
  return ScreenProtectionController(
    service: ref.read(screenProtectionServiceProvider),
  );
});
