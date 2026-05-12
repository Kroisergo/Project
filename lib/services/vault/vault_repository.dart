import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../models/vault_container_format.dart';
import '../../models/vault_data.dart';
import '../../models/vault_document.dart';
import '../../models/vault_header.dart';
import '../../utils/constants.dart';
import '../crypto/crypto_service.dart';
import '../storage/vault_file_service.dart';
import 'vault_container_detector.dart';
import 'vault_repository_v3.dart';

class VaultRepository {
  VaultRepository({
    required this.ref,
    required this.cryptoService,
    required this.fileService,
  });

  final Ref ref;
  final CryptoService cryptoService;
  final VaultFileService fileService;

  Future<VaultOpenResult> loadAndDecrypt({
    required String masterPassword,
    String? fileName,
  }) async {
    final container = await VaultContainerDetector(
      fileService: fileService,
    ).inspect(fileName: fileName);
    _requireV3(container.header);
    return VaultRepositoryV3(
      ref: ref,
      cryptoService: cryptoService,
      fileService: fileService,
    ).loadAndDecrypt(info: container, masterPassword: masterPassword);
  }

  Future<VaultHeader> saveVault({
    required VaultHeader header,
    Uint8List? headerBytes,
    required VaultData data,
    required SecureKey key,
    String? fileName,
  }) {
    _requireV3(header);
    return VaultRepositoryV3(
      ref: ref,
      cryptoService: cryptoService,
      fileService: fileService,
    ).saveVault(
      header: header,
      headerBytes: headerBytes,
      data: data,
      key: key,
      fileName: fileName,
    );
  }

  Future<VaultRekeyResult> changeMasterPassword({
    required VaultHeader header,
    required VaultData data,
    required String currentPassword,
    required String newPassword,
    String? fileName,
  }) {
    _requireV3(header);
    return VaultRepositoryV3(
      ref: ref,
      cryptoService: cryptoService,
      fileService: fileService,
    ).changeMasterPassword(
      header: header,
      data: data,
      currentPassword: currentPassword,
      newPassword: newPassword,
      fileName: fileName,
    );
  }

  Future<VaultDocumentSaveResult> addDocument({
    required VaultHeader currentHeader,
    Uint8List? currentHeaderBytes,
    required VaultData currentData,
    required SecureKey key,
    required String? fileName,
    required String documentId,
    required String sourcePath,
    required String sourceFileName,
    required String extension,
    required String mimeType,
  }) {
    _requireV3(currentHeader);
    return VaultRepositoryV3(
      ref: ref,
      cryptoService: cryptoService,
      fileService: fileService,
    ).addDocument(
      currentHeader: currentHeader,
      currentHeaderBytes: currentHeaderBytes,
      currentData: currentData,
      key: key,
      fileName: fileName,
      documentId: documentId,
      sourcePath: sourcePath,
      sourceFileName: sourceFileName,
      extension: extension,
      mimeType: mimeType,
    );
  }

  Future<VaultDocumentSaveResult> deleteDocument({
    required VaultHeader header,
    Uint8List? headerBytes,
    required VaultData data,
    required SecureKey key,
    required String? fileName,
    required String documentId,
  }) {
    _requireV3(header);
    return VaultRepositoryV3(
      ref: ref,
      cryptoService: cryptoService,
      fileService: fileService,
    ).deleteDocument(
      header: header,
      headerBytes: headerBytes,
      data: data,
      key: key,
      fileName: fileName,
      documentId: documentId,
    );
  }

  Future<void> exportDocument({
    required VaultHeader header,
    required SecureKey key,
    required VaultDocumentMetadata document,
    required String? fileName,
    required String destinationPath,
  }) {
    _requireV3(header);
    return VaultRepositoryV3(
      ref: ref,
      cryptoService: cryptoService,
      fileService: fileService,
    ).exportDocument(
      header: header,
      key: key,
      document: document,
      fileName: fileName,
      destinationPath: destinationPath,
    );
  }

  Future<Uint8List> readDocument({
    required VaultHeader header,
    required SecureKey key,
    required VaultDocumentMetadata document,
    required String? fileName,
    required int maxBytes,
  }) {
    _requireV3(header);
    return VaultRepositoryV3(
      ref: ref,
      cryptoService: cryptoService,
      fileService: fileService,
    ).readDocument(
      header: header,
      key: key,
      document: document,
      fileName: fileName,
      maxBytes: maxBytes,
    );
  }

  void _requireV3(VaultHeader header) {
    if (header.formatVersion != VaultConstants.v3FormatVersion) {
      throw const VaultLoadException(
        'Cofre corrompido ou versão não suportada.',
      );
    }
  }
}

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository(
    ref: ref,
    cryptoService: CryptoService(),
    fileService: VaultFileService(),
  );
});

class VaultLoadException implements Exception {
  final String message;
  const VaultLoadException(this.message);

  @override
  String toString() => message;
}

class VaultAuthException implements Exception {
  final String message;
  const VaultAuthException(this.message);

  @override
  String toString() => message;
}

class VaultOpenResult {
  final VaultHeader header;
  final VaultData data;
  final SecureKey key;
  final String? fileName;
  final VaultContainerFormat format;
  final Uint8List headerBytes;

  VaultOpenResult({
    required this.header,
    required this.data,
    required this.key,
    required this.fileName,
    required this.format,
    required this.headerBytes,
  });
}

class VaultRekeyResult {
  final VaultHeader header;
  final SecureKey key;
  final String? fileName;
  final VaultData data;
  final Uint8List headerBytes;

  VaultRekeyResult({
    required this.header,
    required this.key,
    required this.fileName,
    required this.data,
    required this.headerBytes,
  });
}
