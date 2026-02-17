enum VaultSortMode {
  az,
  za,
  newest,
  oldest,
}

extension VaultSortModePreference on VaultSortMode {
  String get preferenceValue {
    switch (this) {
      case VaultSortMode.az:
        return 'az';
      case VaultSortMode.za:
        return 'za';
      case VaultSortMode.newest:
        return 'newest';
      case VaultSortMode.oldest:
        return 'oldest';
    }
  }

  String get label {
    switch (this) {
      case VaultSortMode.az:
        return 'A-Z';
      case VaultSortMode.za:
        return 'Z-A';
      case VaultSortMode.newest:
        return 'Mais recente';
      case VaultSortMode.oldest:
        return 'Mais antigo';
    }
  }
}

VaultSortMode vaultSortModeFromPreference(String? value) {
  switch (value) {
    case 'za':
      return VaultSortMode.za;
    case 'newest':
      return VaultSortMode.newest;
    case 'oldest':
      return VaultSortMode.oldest;
    case 'az':
    default:
      return VaultSortMode.az;
  }
}
