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

final vaultSortControllerProvider = AsyncNotifierProvider<VaultSortController, VaultSortMode>(
  VaultSortController.new,
);

List<VaultEntry> filterAndSortEntries({
  required List<VaultEntry> entries,
  required String query,
  required Set<String> selectedTags,
  required VaultSortMode sortMode,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final filtered = entries.where((entry) {
    final matchesQuery = normalizedQuery.isEmpty ||
        entry.title.toLowerCase().contains(normalizedQuery) ||
        entry.username.toLowerCase().contains(normalizedQuery) ||
        entry.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
    final matchesTag = selectedTags.isEmpty || entry.tags.any((tag) => selectedTags.contains(tag));
    return matchesQuery && matchesTag;
  }).toList();

  filtered.sort((a, b) {
    switch (sortMode) {
      case VaultSortMode.az:
        return _compareText(a.title, b.title);
      case VaultSortMode.za:
        return _compareText(b.title, a.title);
      case VaultSortMode.newest:
        return b.updatedAt.compareTo(a.updatedAt);
      case VaultSortMode.oldest:
        return a.updatedAt.compareTo(b.updatedAt);
    }
  });

  return filtered;
}

int _compareText(String a, String b) {
  final byLower = a.toLowerCase().compareTo(b.toLowerCase());
  if (byLower != 0) return byLower;
  return a.compareTo(b);
}
