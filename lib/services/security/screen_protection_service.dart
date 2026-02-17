import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScreenProtectionService {
  static const MethodChannel _channel = MethodChannel('encryvault/screen_protection');
  bool _enabled = false;

  Future<void> enable() async {
    await setEnabled(true);
  }

  Future<void> disable() async {
    await setEnabled(false);
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    try {
      await _channel.invokeMethod<void>(enabled ? 'enableProtection' : 'disableProtection');
      _enabled = enabled;
    } catch (_) {
      // Ignore platform channel failures to avoid crashing navigation flows.
    }
  }
}

final screenProtectionServiceProvider = Provider<ScreenProtectionService>((ref) {
  return ScreenProtectionService();
});
