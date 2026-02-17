class VaultConstants {
  static const defaultVaultName = 'vault.vltx';
  static const vaultExtension = '.vltx';
  static const magic = 'EVLT';
  static const formatVersion = 1;
  static const cipherId = 'xchacha20poly1305-ietf';
  static const kdfId = 'argon2id';
}

class PrefsKeys {
  static const termsAccepted = 'termsAccepted';
  static const autoLockMinutes = 'autoLockMinutes';
  static const vaultFileName = 'vaultFileName';
  static const unlockFailedCount = 'unlockFailedCount';
  static const unlockLockUntilEpochMs = 'unlockLockUntilEpochMs';
  static const vaultSortMode = 'vaultSortMode';
  static const appThemeMode = 'appThemeMode';
}
