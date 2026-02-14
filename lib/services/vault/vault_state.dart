import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:uuid/uuid.dart';

import '../../models/vault_data.dart';
import '../../models/vault_entry.dart';
import '../../models/vault_header.dart';
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
  VaultNotifier(this._repo) : super(const VaultState(header: null, data: null, key: null, fileName: null));

  final VaultRepository _repo;
  final _uuid = const Uuid();

  void setVault(VaultHeader header, VaultData data, SecureKey key, {String? fileName}) {
    state = VaultState(header: header, data: data, key: key, fileName: fileName);
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
    state = VaultState(header: newHeader, data: newData, key: current.key, fileName: current.fileName);
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

    final entries = current.data!.entries.map((e) {
      if (e.id != id) return e;
      return e.copyWith(
        title: title,
        username: username,
        password: password,
        notes: notes,
        tags: tags,
        updatedAt: DateTime.now().toUtc(),
      );
    }).toList();

    final newData = VaultData(
      version: current.data!.version,
      updatedAt: DateTime.now().toUtc(),
      entries: entries,
    );

    final newHeader = await _repo.saveVault(
      header: current.header!,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(header: newHeader, data: newData, key: current.key, fileName: current.fileName);
  }

  Future<void> deleteEntry(String id) async {
    final current = state;
    if (!current.isUnlocked) return;
    final newEntries = current.data!.entries.where((e) => e.id != id).toList();
    final newData = VaultData(
      version: current.data!.version,
      updatedAt: DateTime.now().toUtc(),
      entries: newEntries,
    );
    final newHeader = await _repo.saveVault(
      header: current.header!,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(header: newHeader, data: newData, key: current.key, fileName: current.fileName);
  }

  void clear() {
    state.key?.dispose();
    state = const VaultState(header: null, data: null, key: null, fileName: null);
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  return VaultNotifier(ref.read(vaultRepositoryProvider));
});
