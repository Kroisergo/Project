import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:uuid/uuid.dart';

import '../../models/vault_data.dart';
import '../../models/vault_entry.dart';
import '../../models/vault_header.dart';
import 'trash_retention_policy.dart';
import 'vault_repository.dart';

class VaultState {
  final VaultHeader? header;
  final VaultData? data;
  final SecureKey? key;
  final String? fileName;

  const VaultState({
    required this.header,
    required this.data,
    required this.key,
    required this.fileName,
  });

  bool get isUnlocked => header != null && data != null && key != null;
}

class VaultNotifier extends StateNotifier<VaultState> {
  VaultNotifier(this._repo)
    : super(
        const VaultState(header: null, data: null, key: null, fileName: null),
      );

  final VaultRepository _repo;
  final _uuid = const Uuid();

  void setVault(
    VaultHeader header,
    VaultData data,
    SecureKey key, {
    String? fileName,
  }) {
    state = VaultState(
      header: header,
      data: data,
      key: key,
      fileName: fileName,
    );
  }

  Future<String> addEntry({
    required String title,
    required String username,
    required String password,
    required String notes,
    List<String> tags = const [],
  }) async {
    final current = state;
    if (!current.isUnlocked) return '';

    final now = DateTime.now().toUtc();
    final newEntry = VaultEntry(
      id: _uuid.v4(),
      title: title,
      username: username,
      password: password,
      notes: notes,
      tags: tags,
      createdAt: now,
      updatedAt: now,
      passwordUpdatedAt: now,
      lastOpenedAt: now,
      openCount: 0,
      passwordHistory: [
        VaultPasswordHistoryItem(password: password, changedAt: now),
      ],
    );
    final newData = VaultData(
      version: current.data!.version,
      updatedAt: now,
      entries: [...current.data!.entries, newEntry],
    );
    final newHeader = await _repo.saveVault(
      header: current.header!,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(
      header: newHeader,
      data: newData,
      key: current.key,
      fileName: current.fileName,
    );
    return newEntry.id;
  }

  Future<void> updateEntry({
    required String id,
    required String title,
    required String username,
    required String password,
    required String notes,
    List<String> tags = const [],
  }) async {
    final current = state;
    if (!current.isUnlocked) return;

    final now = DateTime.now().toUtc();
    final entries = current.data!.entries.map((e) {
      if (e.id != id) return e;
      final passwordChanged = e.password != password;
      final passwordHistory = passwordChanged
          ? [
              ...e.passwordHistory,
              VaultPasswordHistoryItem(password: password, changedAt: now),
            ]
          : e.passwordHistory;
      return e.copyWith(
        title: title,
        username: username,
        password: password,
        notes: notes,
        tags: tags,
        updatedAt: now,
        passwordUpdatedAt: passwordChanged ? now : e.passwordUpdatedAt,
        passwordHistory: passwordHistory,
      );
    }).toList();

    final newData = VaultData(
      version: current.data!.version,
      updatedAt: now,
      entries: entries,
    );

    final newHeader = await _repo.saveVault(
      header: current.header!,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(
      header: newHeader,
      data: newData,
      key: current.key,
      fileName: current.fileName,
    );
  }

  Future<void> deleteEntry(String id) async {
    final current = state;
    if (!current.isUnlocked) return;
    final now = DateTime.now().toUtc();
    final newEntries = current.data!.entries.map((entry) {
      if (entry.id != id) return entry;
      return entry.copyWith(deletedAt: now, updatedAt: now);
    }).toList();
    final newData = VaultData(
      version: current.data!.version,
      updatedAt: now,
      entries: newEntries,
    );
    final newHeader = await _repo.saveVault(
      header: current.header!,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(
      header: newHeader,
      data: newData,
      key: current.key,
      fileName: current.fileName,
    );
  }

  Future<void> deleteEntries(Set<String> ids) async {
    final current = state;
    if (!current.isUnlocked || ids.isEmpty) return;
    final now = DateTime.now().toUtc();
    final newEntries = current.data!.entries.map((entry) {
      if (!ids.contains(entry.id)) return entry;
      return entry.copyWith(deletedAt: now, updatedAt: now);
    }).toList();
    final newData = VaultData(
      version: current.data!.version,
      updatedAt: now,
      entries: newEntries,
    );
    final newHeader = await _repo.saveVault(
      header: current.header!,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(
      header: newHeader,
      data: newData,
      key: current.key,
      fileName: current.fileName,
    );
  }

  Future<void> restoreEntry(String id) async {
    final current = state;
    if (!current.isUnlocked) return;
    final now = DateTime.now().toUtc();
    final newEntries = current.data!.entries.map((entry) {
      if (entry.id != id) return entry;
      return entry.copyWith(clearDeletedAt: true, updatedAt: now);
    }).toList();
    final newData = VaultData(
      version: current.data!.version,
      updatedAt: now,
      entries: newEntries,
    );
    final newHeader = await _repo.saveVault(
      header: current.header!,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(
      header: newHeader,
      data: newData,
      key: current.key,
      fileName: current.fileName,
    );
  }

  Future<void> permanentlyDeleteEntries(Set<String> ids) async {
    final current = state;
    if (!current.isUnlocked || ids.isEmpty) return;
    final now = DateTime.now().toUtc();
    final newData = VaultData(
      version: current.data!.version,
      updatedAt: now,
      entries: current.data!.entries
          .where((entry) => !ids.contains(entry.id))
          .toList(),
    );
    final newHeader = await _repo.saveVault(
      header: current.header!,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(
      header: newHeader,
      data: newData,
      key: current.key,
      fileName: current.fileName,
    );
  }

  Future<void> emptyTrash() async {
    final current = state;
    if (!current.isUnlocked) return;
    final now = DateTime.now().toUtc();
    final newData = VaultData(
      version: current.data!.version,
      updatedAt: now,
      entries: current.data!.activeEntries,
    );
    final newHeader = await _repo.saveVault(
      header: current.header!,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(
      header: newHeader,
      data: newData,
      key: current.key,
      fileName: current.fileName,
    );
  }

  Future<void> purgeExpiredTrash({
    TrashRetentionOption retention = TrashRetentionPolicy.defaultOption,
  }) async {
    final current = state;
    if (!current.isUnlocked) return;

    final now = DateTime.now().toUtc();
    final entries = current.data!.entries.where((entry) {
      final deletedAt = entry.deletedAt;
      return deletedAt == null ||
          !TrashRetentionPolicy.isExpired(
            deletedAt,
            option: retention,
            now: now,
          );
    }).toList();

    if (entries.length == current.data!.entries.length) return;

    final newData = VaultData(
      version: current.data!.version,
      updatedAt: now,
      entries: entries,
    );
    final newHeader = await _repo.saveVault(
      header: current.header!,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(
      header: newHeader,
      data: newData,
      key: current.key,
      fileName: current.fileName,
    );
  }

  Future<void> markEntryOpened(String id) async {
    final current = state;
    if (!current.isUnlocked) return;

    final now = DateTime.now().toUtc();
    var changed = false;
    final entries = current.data!.entries.map((entry) {
      if (entry.id != id) return entry;
      changed = true;
      return entry.copyWith(lastOpenedAt: now, openCount: entry.openCount + 1);
    }).toList();

    if (!changed) return;

    final newData = VaultData(
      version: current.data!.version,
      updatedAt: now,
      entries: entries,
    );
    final newHeader = await _repo.saveVault(
      header: current.header!,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(
      header: newHeader,
      data: newData,
      key: current.key,
      fileName: current.fileName,
    );
  }

  Future<void> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = state;
    if (!current.isUnlocked) {
      throw const VaultLoadException('Sessão bloqueada.');
    }

    final result = await _repo.changeMasterPassword(
      header: current.header!,
      data: current.data!,
      currentPassword: currentPassword,
      newPassword: newPassword,
      fileName: current.fileName,
    );
    current.key?.dispose();
    state = VaultState(
      header: result.header,
      data: current.data,
      key: result.key,
      fileName: result.fileName ?? current.fileName,
    );
  }

  void clear() {
    state.key?.dispose();
    state = const VaultState(
      header: null,
      data: null,
      key: null,
      fileName: null,
    );
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  return VaultNotifier(ref.read(vaultRepositoryProvider));
});
