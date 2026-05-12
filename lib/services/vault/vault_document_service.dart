import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../models/vault_container_format.dart';
import '../../models/vault_data.dart';
import '../../models/vault_document.dart';
import '../../models/vault_header.dart';
import 'vault_document_limits.dart';
import 'vault_repository.dart';
import 'vault_state.dart';

class VaultDocumentServiceResult {
  final VaultHeader header;
  final Uint8List headerBytes;
  final VaultData data;
  final VaultContainerFormat format;
  final String? fileName;
  final String? documentId;

  const VaultDocumentServiceResult({
    required this.header,
    required this.headerBytes,
    required this.data,
    required this.format,
    required this.fileName,
    this.documentId,
  });
}

class VaultDocumentService {
  VaultDocumentService({required this.repository, Uuid uuid = const Uuid()})
    : _uuid = uuid;

  final VaultRepository repository;
  final Uuid _uuid;

  Future<String> addFromFile({
    required VaultState current,
    required String sourcePath,
    void Function(VaultDocumentMetadata document)? onPendingDocument,
  }) async {
    final result = await addFromFileWithResult(
      current: current,
      sourcePath: sourcePath,
      onPendingDocument: onPendingDocument,
    );
    return result.documentId ?? '';
  }

  Future<VaultDocumentServiceResult> addFromFileWithResult({
    required VaultState current,
    required String sourcePath,
    void Function(VaultDocumentMetadata document)? onPendingDocument,
  }) async {
    _requireUnlocked(current);
    final source = File(sourcePath);
    final sourceFileName = p.basename(source.path);
    final documentId = _uuid.v4();
    final totalBytes = current.data!.documents.fold<int>(
      0,
      (sum, document) => sum + document.sizeBytes,
    );
    await VaultDocumentLimits.validateFile(
      file: source,
      currentTotalBytes: totalBytes,
    );
    final now = DateTime.now().toUtc();
    onPendingDocument?.call(
      VaultDocumentMetadata(
        id: documentId,
        fileName: sourceFileName,
        extension: _extensionFor(sourceFileName),
        mimeType: lookupMimeType(source.path) ?? 'application/octet-stream',
        sizeBytes: await source.length(),
        createdAt: now,
        updatedAt: now,
        chunkSize: VaultDocumentLimits.defaultChunkSize,
        chunks: const [],
      ),
    );
    final result = await repository.addDocument(
      currentHeader: current.header!,
      currentHeaderBytes: current.headerBytes,
      currentData: current.data!,
      key: current.key!,
      fileName: current.fileName,
      documentId: documentId,
      sourcePath: source.path,
      sourceFileName: sourceFileName,
      extension: _extensionFor(sourceFileName),
      mimeType: lookupMimeType(source.path) ?? 'application/octet-stream',
    );
    return VaultDocumentServiceResult(
      header: result.header,
      headerBytes: result.headerBytes,
      data: result.data,
      format: VaultContainerFormat.v3,
      fileName: current.fileName,
      documentId: result.documentId,
    );
  }

  Future<void> exportDocument({
    required VaultState current,
    required String documentId,
    required String destinationPath,
  }) async {
    _requireUnlocked(current);
    final document = current.data!.documents.singleWhere(
      (document) => document.id == documentId,
    );
    await repository.exportDocument(
      header: current.header!,
      key: current.key!,
      document: document,
      fileName: current.fileName,
      destinationPath: destinationPath,
    );
  }

  Future<void> deleteDocument({
    required VaultState current,
    required String documentId,
  }) async {
    await deleteDocumentWithResult(current: current, documentId: documentId);
  }

  Future<VaultDocumentServiceResult> deleteDocumentWithResult({
    required VaultState current,
    required String documentId,
  }) async {
    _requireUnlocked(current);
    final result = await repository.deleteDocument(
      header: current.header!,
      headerBytes: current.headerBytes,
      data: current.data!,
      key: current.key!,
      fileName: current.fileName,
      documentId: documentId,
    );
    return VaultDocumentServiceResult(
      header: result.header,
      headerBytes: result.headerBytes,
      data: result.data,
      format: VaultContainerFormat.v3,
      fileName: current.fileName,
      documentId: result.documentId,
    );
  }

  String _extensionFor(String fileName) {
    return p.extension(fileName).replaceFirst('.', '').toLowerCase();
  }

  void _requireUnlocked(VaultState current) {
    if (!current.isUnlocked) {
      throw const VaultLoadException('Sessão bloqueada.');
    }
  }
}

final vaultDocumentServiceProvider = Provider<VaultDocumentService>((ref) {
  return VaultDocumentService(repository: ref.read(vaultRepositoryProvider));
});
