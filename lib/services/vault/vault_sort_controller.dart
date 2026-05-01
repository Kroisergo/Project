import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vault_entry.dart';
import '../../models/vault_sort_mode.dart';
import '../storage/preferences_service.dart';

class VaultSortController extends AsyncNotifier<VaultSortMode> {
  @override
  Future<VaultSortMode> build() async {
    final prefs = ref.read(preferencesServiceProvider);
    return prefs.getVaultSortMode();
  }

  Future<void> setMode(VaultSortMode mode) async {
    final current = state.valueOrNull;
    if (current == mode) return;
    state = AsyncData(mode);
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setVaultSortMode(mode);
  }
}

final vaultSortControllerProvider =
    AsyncNotifierProvider<VaultSortController, VaultSortMode>(
      VaultSortController.new,
    );

List<VaultEntry> filterAndSortEntries({
  required List<VaultEntry> entries,
  required String query,
  required Set<String> selectedTags,
  required VaultSortMode sortMode,
  VaultEntryCategory? selectedCategory,
  bool favoritesOnly = false,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final filtered = entries.where((entry) {
    final matchesQuery =
        normalizedQuery.isEmpty ||
        entry.title.toLowerCase().contains(normalizedQuery) ||
        entry.username.toLowerCase().contains(normalizedQuery) ||
        entry.url.toLowerCase().contains(normalizedQuery) ||
        entry.category.label.toLowerCase().contains(normalizedQuery) ||
        entry.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
    final matchesTag =
        selectedTags.isEmpty ||
        entry.tags.any((tag) => selectedTags.contains(tag));
    final matchesCategory =
        selectedCategory == null || entry.category == selectedCategory;
    final matchesFavorite = !favoritesOnly || entry.isFavorite;
    return matchesQuery && matchesTag && matchesCategory && matchesFavorite;
  }).toList();

  filtered.sort((a, b) {
    final byFavorite = _compareFavorite(a, b);
    if (byFavorite != 0) return byFavorite;
    switch (sortMode) {
      case VaultSortMode.az:
        return _compareText(a.title, b.title);
      case VaultSortMode.za:
        return _compareText(b.title, a.title);
      case VaultSortMode.newest:
        return b.updatedAt.compareTo(a.updatedAt);
      case VaultSortMode.oldest:
        return a.updatedAt.compareTo(b.updatedAt);
      case VaultSortMode.recentlyEdited:
        return b.updatedAt.compareTo(a.updatedAt);
      case VaultSortMode.recentlyOpened:
        return b.lastOpenedAt.compareTo(a.lastOpenedAt);
      case VaultSortMode.mostUsed:
        final byCount = b.openCount.compareTo(a.openCount);
        if (byCount != 0) return byCount;
        return b.lastOpenedAt.compareTo(a.lastOpenedAt);
      case VaultSortMode.leastUsed:
        final byCount = a.openCount.compareTo(b.openCount);
        if (byCount != 0) return byCount;
        return a.lastOpenedAt.compareTo(b.lastOpenedAt);
      case VaultSortMode.category:
        final byCategory = a.category.sortOrder.compareTo(b.category.sortOrder);
        if (byCategory != 0) return byCategory;
        return _compareText(a.title, b.title);
    }
  });

  return filtered;
}

bool shouldShowVaultFilters(List<VaultEntry> entries) {
  return entries.any((entry) => !entry.isDeleted);
}

int _compareText(String a, String b) {
  final byLower = a.toLowerCase().compareTo(b.toLowerCase());
  if (byLower != 0) return byLower;
  return a.compareTo(b);
}

int _compareFavorite(VaultEntry a, VaultEntry b) {
  if (a.isFavorite == b.isFavorite) return 0;
  return a.isFavorite ? -1 : 1;
}
