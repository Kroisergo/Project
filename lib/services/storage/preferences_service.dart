import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/constants.dart';

class PreferencesService {
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
    return prefs.getInt(PrefsKeys.autoLockMinutes) ?? 2;
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.autoLockMinutes, minutes);
  }

  Future<String?> getVaultFileName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(PrefsKeys.vaultFileName);
  }

  Future<void> setVaultFileName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.vaultFileName, name);
  }
}

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});
