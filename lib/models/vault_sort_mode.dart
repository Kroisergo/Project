enum VaultSortMode {
  az,
  za,
  newest,
  oldest,
  recentlyEdited,
  recentlyOpened,
  mostUsed,
  leastUsed,
  category,
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
      case VaultSortMode.recentlyEdited:
        return 'recentlyEdited';
      case VaultSortMode.recentlyOpened:
        return 'recentlyOpened';
      case VaultSortMode.mostUsed:
        return 'mostUsed';
      case VaultSortMode.leastUsed:
        return 'leastUsed';
      case VaultSortMode.category:
        return 'category';
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
      case VaultSortMode.recentlyEdited:
        return 'Editadas recentemente';
      case VaultSortMode.recentlyOpened:
        return 'Abertas recentemente';
      case VaultSortMode.mostUsed:
        return 'Mais utilizadas';
      case VaultSortMode.leastUsed:
        return 'Menos utilizadas';
      case VaultSortMode.category:
        return 'Categoria';
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
    case 'recentlyEdited':
      return VaultSortMode.recentlyEdited;
    case 'recentlyOpened':
      return VaultSortMode.recentlyOpened;
    case 'mostUsed':
      return VaultSortMode.mostUsed;
    case 'leastUsed':
      return VaultSortMode.leastUsed;
    case 'category':
      return VaultSortMode.category;
    case 'az':
    default:
      return VaultSortMode.az;
  }
}
