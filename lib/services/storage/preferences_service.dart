import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_design_mode.dart';
import '../../models/quick_link_preset.dart';
import '../../models/tag_display_mode.dart';
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

  Future<TrashRetentionOption> getDocumentTrashRetentionOption() async {
    final prefs = await SharedPreferences.getInstance();
    return trashRetentionOptionFromPreference(
      prefs.getString(PrefsKeys.documentTrashRetention),
    );
  }

  Future<void> setDocumentTrashRetentionOption(
    TrashRetentionOption option,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsKeys.documentTrashRetention,
      option.preferenceValue,
    );
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

  Future<bool> getProtectScreenshots() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefsKeys.protectScreenshots) ?? true;
  }

  Future<void> setProtectScreenshots(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.protectScreenshots, value);
  }

  Future<bool> getVisualProtection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefsKeys.visualProtection) ?? true;
  }

  Future<void> setVisualProtection(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.visualProtection, value);
  }

  Future<bool> getProtectScreenRecording() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefsKeys.protectScreenRecording) ?? true;
  }

  Future<void> setProtectScreenRecording(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.protectScreenRecording, value);
  }

  Future<Map<String, int>> getIgnoredEntryAlertExpiries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PrefsKeys.ignoredEntryAlertExpiries);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((key, value) {
        final expiry = value is num ? value.toInt() : int.tryParse('$value');
        return MapEntry('$key', expiry ?? 0);
      })..removeWhere(
        (_, value) =>
            value != VaultConstants.ignoredAlertNoExpiryValue && value <= 0,
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> setIgnoredEntryAlertExpiries(Map<String, int> expiries) async {
    final prefs = await SharedPreferences.getInstance();
    if (expiries.isEmpty) {
      await prefs.remove(PrefsKeys.ignoredEntryAlertExpiries);
      return;
    }
    await prefs.setString(
      PrefsKeys.ignoredEntryAlertExpiries,
      jsonEncode(expiries),
    );
  }

  Future<TagDisplayMode> getTagDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    return tagDisplayModeFromPreference(
      prefs.getString(PrefsKeys.tagDisplayMode),
    );
  }

  Future<void> setTagDisplayMode(TagDisplayMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.tagDisplayMode, mode.preferenceValue);
  }

  Future<List<String>> getExposedHomeTagKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(PrefsKeys.exposedHomeTagKeys) ?? const [];
  }

  Future<void> setExposedHomeTagKeys(Iterable<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized =
        keys.where((key) => key.trim().isNotEmpty).toSet().toList()..sort();
    if (normalized.isEmpty) {
      await prefs.remove(PrefsKeys.exposedHomeTagKeys);
      return;
    }
    await prefs.setStringList(PrefsKeys.exposedHomeTagKeys, normalized);
  }

  Future<List<QuickLinkPreset>> getCustomQuickLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PrefsKeys.customQuickLinks);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(QuickLinkPreset.fromJson)
          .whereType<QuickLinkPreset>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setCustomQuickLinks(Iterable<QuickLinkPreset> links) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = <QuickLinkPreset>[];
    final seenUrls = <String>{};
    for (final link in links) {
      final label = link.label.trim();
      final url = link.normalizedUrl;
      if (label.isEmpty || url.isEmpty) continue;
      if (!seenUrls.add(url.toLowerCase())) continue;
      normalized.add(QuickLinkPreset(label: label, url: url, icon: link.icon));
    }
    if (normalized.isEmpty) {
      await prefs.remove(PrefsKeys.customQuickLinks);
      return;
    }
    await prefs.setString(
      PrefsKeys.customQuickLinks,
      jsonEncode(normalized.map((link) => link.toJson()).toList()),
    );
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return _themeModeFromPreference(prefs.getString(PrefsKeys.appThemeMode));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.appThemeMode, _themeModeToPreference(mode));
  }

  Future<AppDesignMode> getAppDesignMode() async {
    final prefs = await SharedPreferences.getInstance();
    return appDesignModeFromPreference(
      prefs.getString(PrefsKeys.appDesignMode),
    );
  }

  Future<void> setAppDesignMode(AppDesignMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.appDesignMode, mode.preferenceValue);
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
