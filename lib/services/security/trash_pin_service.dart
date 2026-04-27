import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum TrashPinAction { enter, restore, delete }

extension TrashPinActionDetails on TrashPinAction {
  String get storageKey {
    switch (this) {
      case TrashPinAction.enter:
        return 'enter';
      case TrashPinAction.restore:
        return 'restore';
      case TrashPinAction.delete:
        return 'delete';
    }
  }

  String get settingsTitle {
    switch (this) {
      case TrashPinAction.enter:
        return 'PIN para entrar no Lixo';
      case TrashPinAction.restore:
        return 'PIN para recuperar entradas';
      case TrashPinAction.delete:
        return 'PIN para eliminar definitivamente';
    }
  }

  String get promptTitle {
    switch (this) {
      case TrashPinAction.enter:
        return 'PIN do Lixo';
      case TrashPinAction.restore:
        return 'PIN para recuperar';
      case TrashPinAction.delete:
        return 'PIN para eliminar';
    }
  }
}

class TrashPinService {
  TrashPinService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<bool> isEnabled(TrashPinAction action) async {
    final enabled = await _storage.read(key: _enabledKey(action));
    final pin = await _storage.read(key: _pinKey(action));
    return enabled == 'true' && pin != null && pin.isNotEmpty;
  }

  Future<void> setPin(TrashPinAction action, String pin) async {
    await _storage.write(key: _pinKey(action), value: pin);
    await _storage.write(key: _enabledKey(action), value: 'true');
  }

  Future<void> disable(TrashPinAction action) async {
    await _storage.delete(key: _pinKey(action));
    await _storage.delete(key: _enabledKey(action));
  }

  Future<bool> verify(TrashPinAction action, String pin) async {
    if (!await isEnabled(action)) return true;
    final savedPin = await _storage.read(key: _pinKey(action));
    return savedPin == pin;
  }

  Future<bool> changePin(
    TrashPinAction action, {
    required String oldPin,
    required String newPin,
  }) async {
    final isOldPinValid = await verify(action, oldPin);
    if (!isOldPinValid) return false;
    await setPin(action, newPin);
    return true;
  }

  String _pinKey(TrashPinAction action) {
    return 'trash_pin_${action.storageKey}_pin';
  }

  String _enabledKey(TrashPinAction action) {
    return 'trash_pin_${action.storageKey}_enabled';
  }
}

final trashPinServiceProvider = Provider<TrashPinService>((ref) {
  return TrashPinService();
});
