import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sodium/sodium_sumo.dart';

import '../crypto/sodium_provider.dart';

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
  TrashPinService({
    FlutterSecureStorage? storage,
    Future<SodiumSumo> Function()? sodiumLoader,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _sodiumLoader = sodiumLoader ?? (() async => SodiumSumoInit.init());

  final FlutterSecureStorage _storage;
  final Future<SodiumSumo> Function() _sodiumLoader;

  Future<bool> isEnabled(TrashPinAction action) async {
    final enabled = await _storage.read(key: _enabledKey(action));
    final record = await _storage.read(key: _pinKey(action));
    return enabled == 'true' && record != null && record.isNotEmpty;
  }

  Future<void> setPin(TrashPinAction action, String pin) async {
    final record = await _buildRecord(pin);
    await _storage.write(key: _pinKey(action), value: jsonEncode(record));
    await _storage.write(key: _enabledKey(action), value: 'true');
  }

  Future<void> disable(TrashPinAction action) async {
    await _storage.delete(key: _pinKey(action));
    await _storage.delete(key: _enabledKey(action));
  }

  Future<bool> verify(TrashPinAction action, String pin) async {
    if (!await isEnabled(action)) return true;
    final savedRecord = await _storage.read(key: _pinKey(action));
    if (savedRecord == null || savedRecord.isEmpty) return false;

    final parsed = _tryParseRecord(savedRecord);
    if (parsed == null) {
      final isLegacyValid = savedRecord == pin;
      if (isLegacyValid) {
        await setPin(action, pin);
      }
      return isLegacyValid;
    }

    final hash = parsed['hash'];
    if (hash is! String || hash.isEmpty) return false;
    final sodium = await _sodiumLoader();
    try {
      return sodium.crypto.pwhash.strVerify(passwordHash: hash, password: pin);
    } catch (_) {
      return false;
    }
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

  Future<Map<String, dynamic>> _buildRecord(String pin) async {
    final sodium = await _sodiumLoader();
    final pwhash = sodium.crypto.pwhash;
    return {
      'version': 1,
      'algorithm': 'argon2id',
      'opsLimit': pwhash.opsLimitModerate,
      'memLimit': pwhash.memLimitModerate,
      'hash': pwhash.str(
        password: pin,
        opsLimit: pwhash.opsLimitModerate,
        memLimit: pwhash.memLimitModerate,
      ),
    };
  }

  Map<String, dynamic>? _tryParseRecord(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
}

final trashPinServiceProvider = Provider<TrashPinService>((ref) {
  return TrashPinService(sodiumLoader: () => ref.read(sodiumProvider.future));
});
