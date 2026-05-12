class VaultConstants {
  static const defaultVaultName = 'vault.vltx';
  static const vaultExtension = '.vltx';
  static const magic = 'EVLT';
  static const formatVersion = 1;
  static const currentDataVersion = 2;
  static const cipherId = 'xchacha20poly1305-ietf';
  static const kdfId = 'argon2id';
  static const ignoredAlertNoExpiryValue = -1;
}

class PrefsKeys {
  static const termsAccepted = 'termsAccepted';
  static const autoLockMinutes = 'autoLockMinutes';
  static const vaultFileName = 'vaultFileName';
  static const unlockFailedCount = 'unlockFailedCount';
  static const unlockLockUntilEpochMs = 'unlockLockUntilEpochMs';
  static const vaultSortMode = 'vaultSortMode';
  static const appDesignMode = 'appDesignMode';
  static const appThemeMode = 'appThemeMode';
  static const trashRetention = 'trashRetention';
  static const requireSensitiveActionConfirmation =
      'requireSensitiveActionConfirmation';
  static const savePasswordHistory = 'savePasswordHistory';
  static const protectScreenshots = 'protectScreenshots';
  static const visualProtection = 'visualProtection';
  static const protectScreenRecording = 'protectScreenRecording';
  static const ignoredEntryAlertExpiries = 'ignoredEntryAlertExpiries';
  static const tagDisplayMode = 'tagDisplayMode';
  static const exposedHomeTagKeys = 'exposedHomeTagKeys';
  static const customQuickLinks = 'customQuickLinks';
}
