import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:uuid/uuid.dart';

import '../../models/vault_container_format.dart';
import '../../models/vault_data.dart';
import '../../models/vault_document.dart';
import '../../models/vault_entry.dart';
import '../../models/vault_header.dart';
import '../storage/preferences_service.dart';
import 'trash_retention_policy.dart';
import 'vault_document_service.dart';
import 'vault_repository.dart';

class VaultState {
  final VaultHeader? header;
  final VaultData? data;
  final SecureKey? key;
  final String? fileName;
  final VaultContainerFormat format;
  final Uint8List? headerBytes;

  const VaultState({
    required this.header,
    required this.data,
    required this.key,
    required this.fileName,
    required this.format,
    required this.headerBytes,
  });

  bool get isUnlocked => header != null && data != null && key != null;
}

class VaultNotifier extends StateNotifier<VaultState> {
  VaultNotifier(this._repo, this._prefs, this._documents)
    : super(
        const VaultState(
          header: null,
          data: null,
          key: null,
          fileName: null,
          format: VaultContainerFormat.v3,
          headerBytes: null,
        ),
      );

  final VaultRepository _repo;
  final PreferencesService _prefs;
  final VaultDocumentService _documents;
  final _uuid = const Uuid();

  void setVault(
    VaultHeader header,
    VaultData data,
    SecureKey key, {
    String? fileName,
    VaultContainerFormat format = VaultContainerFormat.v3,
    Uint8List? headerBytes,
  }) {
    state = VaultState(
      header: header,
      data: data,
      key: key,
      fileName: fileName,
      format: format,
      headerBytes: headerBytes,
    );
  }

  Future<void> _saveCurrentData(VaultState current, VaultData newData) async {
    final newHeader = await _repo.saveVault(
      header: current.header!,
      headerBytes: current.headerBytes,
      data: newData,
      key: current.key!,
      fileName: current.fileName,
    );
    state = VaultState(
      header: newHeader,
      data: newData,
      key: current.key,
      fileName: current.fileName,
      format: current.format,
      headerBytes: current.headerBytes,
    );
  }

  void _applyDocumentResult(
    VaultState current,
    VaultDocumentServiceResult result,
  ) {
    _requireSameUnlockedSession(current);
    state = VaultState(
      header: result.header,
      data: result.data.copyWith(documents: [...result.data.documents]),
      key: current.key,
      fileName: result.fileName ?? current.fileName,
      format: result.format,
      headerBytes: result.headerBytes,
    );
  }

  void _applyPendingDocument(
    VaultState current,
    VaultDocumentMetadata document,
  ) {
    _requireSameUnlockedSession(current);
    final data = state.data;
    if (data == null) return;
    state = VaultState(
      header: state.header,
      data: data.copyWith(
        updatedAt: document.updatedAt,
        documents: [
          ...data.documents.where((existing) => existing.id != document.id),
          document,
        ],
      ),
      key: state.key,
      fileName: state.fileName,
      format: state.format,
      headerBytes: state.headerBytes,
    );
  }

  void _removePendingDocument(VaultState current, String documentId) {
    _requireSameUnlockedSession(current);
    final data = state.data;
    if (data == null) return;
    state = VaultState(
      header: state.header,
      data: data.copyWith(
        documents: data.documents
            .where((document) => document.id != documentId)
            .toList(),
      ),
      key: state.key,
      fileName: state.fileName,
      format: state.format,
      headerBytes: state.headerBytes,
    );
  }

  void _notifyDocumentsUnchanged(VaultState current) {
    _requireSameUnlockedSession(current);
    final data = state.data;
    if (data == null) return;
    state = VaultState(
      header: state.header,
      data: data.copyWith(documents: [...data.documents]),
      key: state.key,
      fileName: state.fileName,
      format: state.format,
      headerBytes: state.headerBytes,
    );
  }

  void _requireSameUnlockedSession(VaultState current) {
    if (!state.isUnlocked || !identical(state.key, current.key)) {
      throw const VaultLoadException('Sessão bloqueada.');
    }
  }

  Future<String> addEntry({
    required String title,
    required String username,
    required String password,
    String url = '',
    required String notes,
    VaultEntryCategory category = VaultEntryCategory.other,
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
      url: url,
      notes: notes,
      category: category,
      tags: tags,
      createdAt: now,
      updatedAt: now,
      passwordUpdatedAt: now,
      lastOpenedAt: now,
      openCount: 0,
      passwordHistory: const [],
    );
    final newData = current.data!.copyWith(
      updatedAt: now,
      entries: [...current.data!.entries, newEntry],
    );
    await _saveCurrentData(current, newData);
    return newEntry.id;
  }

  Future<void> updateEntry({
    required String id,
    required String title,
    required String username,
    required String password,
    String? url,
    required String notes,
    VaultEntryCategory? category,
    List<String> tags = const [],
  }) async {
    final current = state;
    if (!current.isUnlocked) return;

    final now = DateTime.now().toUtc();
    final savePasswordHistory = await _prefs.getSavePasswordHistory();
    final entries = current.data!.entries.map((e) {
      if (e.id != id) return e;
      final passwordChanged = e.password != password;
      final passwordHistory = passwordChanged && savePasswordHistory
          ? [
              ...e.passwordHistory,
              VaultPasswordHistoryItem(password: e.password, changedAt: now),
            ]
          : e.passwordHistory;
      return e.copyWith(
        title: title,
        username: username,
        password: password,
        url: url ?? e.url,
        notes: notes,
        category: category ?? e.category,
        tags: tags,
        updatedAt: now,
        passwordUpdatedAt: passwordChanged ? now : e.passwordUpdatedAt,
        passwordHistory: passwordHistory,
      );
    }).toList();

    final newData = current.data!.copyWith(updatedAt: now, entries: entries);
    await _saveCurrentData(current, newData);
  }

  Future<void> setEntryFavorite(String id, bool isFavorite) async {
    final current = state;
    if (!current.isUnlocked) return;

    final now = DateTime.now().toUtc();
    var changed = false;
    final entries = current.data!.entries.map((entry) {
      if (entry.id != id || entry.isFavorite == isFavorite) return entry;
      changed = true;
      return entry.copyWith(isFavorite: isFavorite, updatedAt: now);
    }).toList();

    if (!changed) return;

    final newData = current.data!.copyWith(updatedAt: now, entries: entries);
    await _saveCurrentData(current, newData);
  }

  Future<void> deleteEntry(String id) async {
    final current = state;
    if (!current.isUnlocked) return;
    final now = DateTime.now().toUtc();
    final newEntries = current.data!.entries.map((entry) {
      if (entry.id != id) return entry;
      return entry.copyWith(deletedAt: now, updatedAt: now);
    }).toList();
    final newData = current.data!.copyWith(updatedAt: now, entries: newEntries);
    await _saveCurrentData(current, newData);
  }

  Future<void> deleteEntries(Set<String> ids) async {
    final current = state;
    if (!current.isUnlocked || ids.isEmpty) return;
    final now = DateTime.now().toUtc();
    final newEntries = current.data!.entries.map((entry) {
      if (!ids.contains(entry.id)) return entry;
      return entry.copyWith(deletedAt: now, updatedAt: now);
    }).toList();
    final newData = current.data!.copyWith(updatedAt: now, entries: newEntries);
    await _saveCurrentData(current, newData);
  }

  Future<void> restoreEntry(String id) async {
    final current = state;
    if (!current.isUnlocked) return;
    final now = DateTime.now().toUtc();
    final newEntries = current.data!.entries.map((entry) {
      if (entry.id != id) return entry;
      return entry.copyWith(clearDeletedAt: true, updatedAt: now);
    }).toList();
    final newData = current.data!.copyWith(updatedAt: now, entries: newEntries);
    await _saveCurrentData(current, newData);
  }

  Future<void> permanentlyDeleteEntries(Set<String> ids) async {
    final current = state;
    if (!current.isUnlocked || ids.isEmpty) return;
    final now = DateTime.now().toUtc();
    final newData = current.data!.copyWith(
      updatedAt: now,
      entries: current.data!.entries
          .where((entry) => !ids.contains(entry.id))
          .toList(),
    );
    await _saveCurrentData(current, newData);
  }

  Future<void> emptyTrash() async {
    final current = state;
    if (!current.isUnlocked) return;
    final now = DateTime.now().toUtc();
    final newData = current.data!.copyWith(
      updatedAt: now,
      entries: current.data!.activeEntries,
    );
    await _saveCurrentData(current, newData);
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

    final newData = current.data!.copyWith(updatedAt: now, entries: entries);
    await _saveCurrentData(current, newData);
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

    final newData = current.data!.copyWith(updatedAt: now, entries: entries);
    await _saveCurrentData(current, newData);
  }

  Future<void> removePasswordHistoryItem({
    required String id,
    required int historyIndex,
  }) async {
    final current = state;
    if (!current.isUnlocked || historyIndex < 0) return;

    final now = DateTime.now().toUtc();
    var changed = false;
    final entries = current.data!.entries.map((entry) {
      if (entry.id != id || historyIndex >= entry.passwordHistory.length) {
        return entry;
      }
      final history = [...entry.passwordHistory]..removeAt(historyIndex);
      changed = true;
      return entry.copyWith(updatedAt: now, passwordHistory: history);
    }).toList();

    if (!changed) return;

    final newData = current.data!.copyWith(updatedAt: now, entries: entries);
    await _saveCurrentData(current, newData);
  }

  Future<void> clearPasswordHistory(String id) async {
    final current = state;
    if (!current.isUnlocked) return;

    final now = DateTime.now().toUtc();
    var changed = false;
    final entries = current.data!.entries.map((entry) {
      if (entry.id != id || entry.passwordHistory.isEmpty) return entry;
      changed = true;
      return entry.copyWith(updatedAt: now, passwordHistory: const []);
    }).toList();

    if (!changed) return;

    final newData = current.data!.copyWith(updatedAt: now, entries: entries);
    await _saveCurrentData(current, newData);
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
      data: result.data,
      key: result.key,
      fileName: result.fileName ?? current.fileName,
      format: vaultContainerFormatFromVersion(result.header.formatVersion),
      headerBytes: result.headerBytes,
    );
  }

  Future<String> addDocumentFromFile(String sourcePath) async {
    final current = state;
    if (!current.isUnlocked) return '';

    String? pendingDocumentId;
    try {
      final result = await _documents.addFromFileWithResult(
        current: current,
        sourcePath: sourcePath,
        onPendingDocument: (document) {
          pendingDocumentId = document.id;
          _applyPendingDocument(current, document);
        },
      );
      _applyDocumentResult(current, result);
      return result.documentId ?? '';
    } catch (_) {
      final documentId = pendingDocumentId;
      if (documentId != null) {
        try {
          _removePendingDocument(current, documentId);
        } catch (_) {
          // If the session is already locked, avoid resurrecting state.
        }
      }
      rethrow;
    }
  }

  Future<void> deleteDocument(String documentId) async {
    final current = state;
    if (!current.isUnlocked) return;
    final now = DateTime.now().toUtc();
    var changed = false;
    final documents = current.data!.documents.map((document) {
      if (document.id != documentId || document.isDeleted) return document;
      changed = true;
      return document.copyWith(deletedAt: now, updatedAt: now);
    }).toList();
    if (!changed) return;
    final newData = current.data!.copyWith(
      updatedAt: now,
      documents: documents,
    );
    await _saveCurrentData(current, newData);
  }

  Future<void> restoreDocument(String documentId) async {
    final current = state;
    if (!current.isUnlocked) return;
    final now = DateTime.now().toUtc();
    var changed = false;
    final documents = current.data!.documents.map((document) {
      if (document.id != documentId || !document.isDeleted) return document;
      changed = true;
      return document.copyWith(clearDeletedAt: true, updatedAt: now);
    }).toList();
    if (!changed) return;
    final newData = current.data!.copyWith(
      updatedAt: now,
      documents: documents,
    );
    await _saveCurrentData(current, newData);
  }

  Future<void> permanentlyDeleteDocuments(Set<String> ids) async {
    final current = state;
    if (!current.isUnlocked || ids.isEmpty) return;
    final now = DateTime.now().toUtc();
    final newData = current.data!.copyWith(
      updatedAt: now,
      documents: current.data!.documents
          .where((document) => !ids.contains(document.id))
          .toList(),
    );
    await _saveCurrentData(current, newData);
  }

  Future<void> emptyDocumentTrash() async {
    final current = state;
    if (!current.isUnlocked) return;
    final now = DateTime.now().toUtc();
    final newData = current.data!.copyWith(
      updatedAt: now,
      documents: current.data!.activeDocuments,
    );
    await _saveCurrentData(current, newData);
  }

  Future<void> purgeExpiredDocumentTrash({
    TrashRetentionOption retention = TrashRetentionPolicy.defaultOption,
  }) async {
    final current = state;
    if (!current.isUnlocked) return;

    final now = DateTime.now().toUtc();
    final documents = current.data!.documents.where((document) {
      final deletedAt = document.deletedAt;
      return deletedAt == null ||
          !TrashRetentionPolicy.isExpired(
            deletedAt,
            option: retention,
            now: now,
          );
    }).toList();

    if (documents.length == current.data!.documents.length) return;

    final newData = current.data!.copyWith(
      updatedAt: now,
      documents: documents,
    );
    await _saveCurrentData(current, newData);
  }

  Future<void> exportDocument(String documentId, String destinationPath) async {
    final current = state;
    if (!current.isUnlocked) return;
    await _documents.exportDocument(
      current: current,
      documentId: documentId,
      destinationPath: destinationPath,
    );
    _notifyDocumentsUnchanged(current);
  }

  Future<VaultDocumentPreview> previewDocument(String documentId) async {
    final current = state;
    if (!current.isUnlocked) {
      throw const VaultLoadException('SessÃ£o bloqueada.');
    }
    return _documents.previewDocument(current: current, documentId: documentId);
  }

  void clear() {
    state.key?.dispose();
    state = const VaultState(
      header: null,
      data: null,
      key: null,
      fileName: null,
      format: VaultContainerFormat.v3,
      headerBytes: null,
    );
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  return VaultNotifier(
    ref.read(vaultRepositoryProvider),
    ref.read(preferencesServiceProvider),
    ref.read(vaultDocumentServiceProvider),
  );
});
