import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vault_sort_mode.dart';
import '../../utils/constants.dart';
import '../vault/trash_retention_policy.dart';

class PreferencesService {
  static const autoLockNever = 0;

  Future<bool> isTermsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefsKeys.termsAccepted) ?? false;
  }

  Future<void> setTermsAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.termsAccepted, accepted);
  }

  Future<int> getAutoLockMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(PrefsKeys.autoLockMinutes);
    return _normalizeAutoLockMinutes(value);
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      PrefsKeys.autoLockMinutes,
      _normalizeAutoLockMinutes(minutes),
    );
  }

  Future<String?> getVaultFileName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(PrefsKeys.vaultFileName);
  }

  Future<void> setVaultFileName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.vaultFileName, name);
  }

  Future<int> getUnlockFailedCount() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(PrefsKeys.unlockFailedCount) ?? 0;
    return value < 0 ? 0 : value;
  }

  Future<void> setUnlockFailedCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final safeCount = count < 0 ? 0 : count;
    await prefs.setInt(PrefsKeys.unlockFailedCount, safeCount);
  }

  Future<int?> getUnlockLockUntilEpochMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(PrefsKeys.unlockLockUntilEpochMs);
  }

  Future<void> setUnlockLockUntilEpochMs(int? epochMs) async {
    final prefs = await SharedPreferences.getInstance();
    if (epochMs == null) {
      await prefs.remove(PrefsKeys.unlockLockUntilEpochMs);
      return;
    }
    await prefs.setInt(PrefsKeys.unlockLockUntilEpochMs, epochMs);
  }

  Future<VaultSortMode> getVaultSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    return vaultSortModeFromPreference(
      prefs.getString(PrefsKeys.vaultSortMode),
    );
  }

  Future<void> setVaultSortMode(VaultSortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.vaultSortMode, mode.preferenceValue);
  }

  Future<TrashRetentionOption> getTrashRetentionOption() async {
    final prefs = await SharedPreferences.getInstance();
    return trashRetentionOptionFromPreference(
      prefs.getString(PrefsKeys.trashRetention),
    );
  }

  Future<void> setTrashRetentionOption(TrashRetentionOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.trashRetention, option.preferenceValue);
  }

  Future<bool> getRequireSensitiveActionConfirmation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefsKeys.requireSensitiveActionConfirmation) ?? false;
  }

  Future<void> setRequireSensitiveActionConfirmation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.requireSensitiveActionConfirmation, value);
  }

  Future<bool> getSavePasswordHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefsKeys.savePasswordHistory) ?? true;
  }

  Future<void> setSavePasswordHistory(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.savePasswordHistory, value);
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return _themeModeFromPreference(prefs.getString(PrefsKeys.appThemeMode));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.appThemeMode, _themeModeToPreference(mode));
  }

  ThemeMode _themeModeFromPreference(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToPreference(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  int _normalizeAutoLockMinutes(int? minutes) {
    if (minutes == null) return 2;
    if (minutes <= autoLockNever) return autoLockNever;
    return minutes.clamp(1, 30);
  }
}

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});
