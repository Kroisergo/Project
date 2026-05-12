import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sodium/sodium_sumo.dart';

import '../../models/vault_container_format.dart';
import '../../models/vault_data.dart';
import '../../models/vault_document.dart';
import '../../models/vault_footer_v3.dart';
import '../../models/vault_header.dart';
import '../../models/vault_manifest_v3.dart';
import '../../utils/constants.dart';
import '../crypto/crypto_params.dart';
import '../crypto/crypto_service.dart';
import '../crypto/sodium_provider.dart';
import '../storage/vault_file_service.dart';
import 'vault_chunk_crypto_service.dart';
import 'vault_chunked_file_writer.dart';
import 'vault_container_detector.dart';
import 'vault_document_limits.dart';
import 'vault_repository.dart';

class VaultDocumentSaveResult {
  final VaultHeader header;
  final Uint8List headerBytes;
  final VaultData data;
  final String documentId;

  const VaultDocumentSaveResult({
    required this.header,
    required this.headerBytes,
    required this.data,
    required this.documentId,
  });
}

class VaultRepositoryV3 {
  VaultRepositoryV3({
    required this.ref,
    required this.cryptoService,
    required this.fileService,
    VaultChunkCryptoService? chunkCrypto,
  }) : chunkCrypto = chunkCrypto ?? VaultChunkCryptoService();

  final Ref ref;
  final CryptoService cryptoService;
  final VaultFileService fileService;
  final VaultChunkCryptoService chunkCrypto;

  Future<VaultOpenResult> loadAndDecrypt({
    required VaultContainerInfo info,
    required String masterPassword,
  }) async {
    _validateHeader(info.header);
    final sodium = await ref.read(sodiumProvider.future);
    final key = await _deriveKey(
      sodium: sodium,
      header: info.header,
      masterPassword: masterPassword,
    );
    SecureKey? manifestKey;
    Uint8List? manifestPlaintext;
    try {
      final footer = await _readFooter(info.file);
      final manifestBytes = await _readManifestCiphertext(info.file, footer);
      manifestKey = chunkCrypto.deriveManifestKey(sodium, key);
      manifestPlaintext = chunkCrypto.decrypt(
        sodium: sodium,
        ciphertext: manifestBytes,
        nonce: footer.manifestNonce,
        key: manifestKey,
        aad: chunkCrypto.manifestAad(
          headerBytes: info.headerBytes,
          footer: footer,
        ),
      );
      final decoded = jsonDecode(utf8.decode(manifestPlaintext));
      if (decoded is! Map) {
        throw const FormatException('Manifesto v3 inválido.');
      }
      final manifest = VaultManifestV3.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return VaultOpenResult(
        header: info.header,
        data: manifest.toVaultData(),
        key: key,
        fileName: info.fileName,
        format: VaultContainerFormat.v3,
        headerBytes: info.headerBytes,
      );
    } catch (_) {
      key.dispose();
      throw const VaultAuthException(
        'Não foi possível validar a integridade do cofre. A palavra-passe pode estar incorreta ou o ficheiro pode ter sido alterado.',
      );
    } finally {
      manifestKey?.dispose();
      manifestPlaintext?.fillRange(0, manifestPlaintext.length, 0);
    }
  }

  Future<VaultHeader> saveVault({
    required VaultHeader header,
    Uint8List? headerBytes,
    required VaultData data,
    required SecureKey key,
    String? fileName,
  }) async {
    final sodium = await ref.read(sodiumProvider.future);
    final target = await fileService.vaultFileForName(fileName);
    await VaultChunkedFileWriter(
      fileService: fileService,
      chunkCrypto: chunkCrypto,
    ).write(
      sodium: sodium,
      target: target,
      header: header,
      headerBytesOverride: headerBytes,
      data: data,
      key: key,
      sourceFile: target,
    );
    return header;
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
  }) async {
    if (currentHeader.formatVersion != VaultConstants.v3FormatVersion) {
      throw const VaultLoadException(
        'Cofre corrompido ou versão não suportada.',
      );
    }
    final source = File(sourcePath);
    final totalBytes = currentData.documents.fold<int>(
      0,
      (sum, document) => sum + document.sizeBytes,
    );
    await VaultDocumentLimits.validateFile(
      file: source,
      currentTotalBytes: totalBytes,
    );
    final now = DateTime.now().toUtc();
    final sodium = await ref.read(sodiumProvider.future);
    final target = await fileService.vaultFileForName(fileName);
    final result =
        await VaultChunkedFileWriter(
          fileService: fileService,
          chunkCrypto: chunkCrypto,
        ).write(
          sodium: sodium,
          target: target,
          header: currentHeader,
          headerBytesOverride: currentHeaderBytes,
          data: currentData.copyWith(
            version: VaultConstants.v3DataVersion,
            updatedAt: now,
          ),
          key: key,
          sourceFile: await target.exists() ? target : null,
          imports: [
            VaultDocumentImport(
              id: documentId,
              sourcePath: sourcePath,
              fileName: sourceFileName,
              extension: extension,
              mimeType: mimeType,
              sizeBytes: await source.length(),
              createdAt: now,
            ),
          ],
        );
    return VaultDocumentSaveResult(
      header: result.header,
      headerBytes: result.headerBytes,
      data: result.data,
      documentId: documentId,
    );
  }

  Future<VaultDocumentSaveResult> deleteDocument({
    required VaultHeader header,
    Uint8List? headerBytes,
    required VaultData data,
    required SecureKey key,
    required String? fileName,
    required String documentId,
  }) async {
    final sodium = await ref.read(sodiumProvider.future);
    final target = await fileService.vaultFileForName(fileName);
    final nextData = data.copyWith(
      updatedAt: DateTime.now().toUtc(),
      documents: data.documents
          .where((document) => document.id != documentId)
          .toList(),
    );
    final result =
        await VaultChunkedFileWriter(
          fileService: fileService,
          chunkCrypto: chunkCrypto,
        ).write(
          sodium: sodium,
          target: target,
          header: header,
          headerBytesOverride: headerBytes,
          data: nextData,
          key: key,
          sourceFile: target,
        );
    return VaultDocumentSaveResult(
      header: result.header,
      headerBytes: result.headerBytes,
      data: result.data,
      documentId: documentId,
    );
  }

  Future<void> exportDocument({
    required VaultHeader header,
    required SecureKey key,
    required VaultDocumentMetadata document,
    required String? fileName,
    required String destinationPath,
  }) async {
    final sodium = await ref.read(sodiumProvider.future);
    final sourceFile = await fileService.vaultFileForName(fileName);
    final info = await VaultContainerDetector(
      fileService: fileService,
    ).inspect(fileName: fileName);
    final headerBytes = info.headerBytes;
    final source = await sourceFile.open();
    final destination = File(destinationPath);
    await destination.parent.create(recursive: true);
    final out = await destination.open(mode: FileMode.write);
    SecureKey? chunkKey;
    try {
      chunkKey = chunkCrypto.deriveChunkKey(sodium, key);
      for (final chunk in document.chunks) {
        await source.setPosition(chunk.offset);
        final encrypted = Uint8List.fromList(
          await source.read(chunk.encryptedSize),
        );
        final plaintext = chunkCrypto.decrypt(
          sodium: sodium,
          ciphertext: encrypted,
          nonce: base64Decode(chunk.nonceB64),
          key: chunkKey,
          aad: chunkCrypto.chunkAad(
            headerBytes: headerBytes,
            documentId: document.id,
            chunkIndex: chunk.index,
            plainSize: chunk.plainSize,
          ),
        );
        await out.writeFrom(plaintext);
        plaintext.fillRange(0, plaintext.length, 0);
      }
      await out.flush();
    } catch (_) {
      try {
        await out.close();
      } catch (_) {}
      if (await destination.exists()) {
        await destination.delete();
      }
      throw const VaultAuthException('Não foi possível exportar o documento.');
    } finally {
      chunkKey?.dispose();
      await source.close();
      try {
        await out.close();
      } catch (_) {}
    }
  }

  Future<Uint8List> readDocument({
    required VaultHeader header,
    required SecureKey key,
    required VaultDocumentMetadata document,
    required String? fileName,
    required int maxBytes,
  }) async {
    if (document.sizeBytes > maxBytes) {
      throw const VaultDocumentLimitException(
        'Documento demasiado grande para pré-visualização.',
      );
    }
    final sodium = await ref.read(sodiumProvider.future);
    final sourceFile = await fileService.vaultFileForName(fileName);
    final info = await VaultContainerDetector(
      fileService: fileService,
    ).inspect(fileName: fileName);
    final headerBytes = info.headerBytes;
    final source = await sourceFile.open();
    final out = BytesBuilder();
    SecureKey? chunkKey;
    try {
      chunkKey = chunkCrypto.deriveChunkKey(sodium, key);
      for (final chunk in document.chunks) {
        await source.setPosition(chunk.offset);
        final encrypted = Uint8List.fromList(
          await source.read(chunk.encryptedSize),
        );
        final plaintext = chunkCrypto.decrypt(
          sodium: sodium,
          ciphertext: encrypted,
          nonce: base64Decode(chunk.nonceB64),
          key: chunkKey,
          aad: chunkCrypto.chunkAad(
            headerBytes: headerBytes,
            documentId: document.id,
            chunkIndex: chunk.index,
            plainSize: chunk.plainSize,
          ),
        );
        if (out.length + plaintext.length > maxBytes) {
          plaintext.fillRange(0, plaintext.length, 0);
          throw const VaultDocumentLimitException(
            'Documento demasiado grande para pré-visualização.',
          );
        }
        out.add(plaintext);
        plaintext.fillRange(0, plaintext.length, 0);
      }
      return out.takeBytes();
    } catch (_) {
      throw const VaultAuthException(
        'Não foi possível pré-visualizar o documento.',
      );
    } finally {
      chunkKey?.dispose();
      await source.close();
    }
  }

  Future<VaultRekeyResult> changeMasterPassword({
    required VaultHeader header,
    required VaultData data,
    required String currentPassword,
    required String newPassword,
    String? fileName,
  }) async {
    final info = await VaultContainerDetector(
      fileService: fileService,
    ).inspect(fileName: fileName);
    final validation = await loadAndDecrypt(
      info: info,
      masterPassword: currentPassword,
    );
    final sodium = await ref.read(sodiumProvider.future);
    final params = CryptoParams(
      memLimit: header.memLimit,
      opsLimit: header.opsLimit,
      parallelism: header.parallelism,
    );
    final salt = cryptoService.randomBytes(
      sodium,
      sodium.crypto.pwhash.saltBytes,
    );
    final newKey = await cryptoService.deriveKeyInBackground(
      sodium: sodium,
      masterPassword: newPassword,
      salt: salt,
      params: params,
    );
    final newHeader = header.copyWith(saltB64: base64Encode(salt));
    final target = await fileService.vaultFileForName(fileName);
    try {
      final result =
          await VaultChunkedFileWriter(
            fileService: fileService,
            chunkCrypto: chunkCrypto,
          ).write(
            sodium: sodium,
            target: target,
            header: newHeader,
            data: data,
            key: newKey,
            sourceFile: target,
            sourceHeaderBytes: validation.headerBytes,
            oldKey: validation.key,
            oldHeader: header,
            reencryptExistingChunks: true,
          );
      validation.key.dispose();
      return VaultRekeyResult(
        header: result.header,
        key: newKey,
        fileName: p.basename(target.path),
        data: result.data,
        headerBytes: result.headerBytes,
      );
    } catch (_) {
      validation.key.dispose();
      newKey.dispose();
      rethrow;
    }
  }

  Future<VaultFooterV3> _readFooter(File file) async {
    final raf = await file.open();
    try {
      final len = await raf.length();
      if (len < VaultFooterV3.length + 4) {
        throw const VaultLoadException('Conteúdo do cofre inválido.');
      }
      await raf.setPosition(len - VaultFooterV3.length);
      return VaultFooterV3.fromBytes(
        Uint8List.fromList(await raf.read(VaultFooterV3.length)),
      );
    } finally {
      await raf.close();
    }
  }

  Future<Uint8List> _readManifestCiphertext(
    File file,
    VaultFooterV3 footer,
  ) async {
    final raf = await file.open();
    try {
      await raf.setPosition(footer.manifestOffset);
      final bytes = await raf.read(footer.manifestEncryptedSize);
      if (bytes.length != footer.manifestEncryptedSize) {
        throw const VaultLoadException('Manifesto do cofre inválido.');
      }
      return Uint8List.fromList(bytes);
    } finally {
      await raf.close();
    }
  }

  Future<SecureKey> _deriveKey({
    required SodiumSumo sodium,
    required VaultHeader header,
    required String masterPassword,
  }) async {
    return cryptoService.deriveKeyInBackground(
      sodium: sodium,
      masterPassword: masterPassword,
      salt: base64Decode(header.saltB64),
      params: CryptoParams(
        memLimit: header.memLimit,
        opsLimit: header.opsLimit,
        parallelism: header.parallelism,
      ),
    );
  }

  void _validateHeader(VaultHeader header) {
    if (header.magic != VaultConstants.magic ||
        header.formatVersion != VaultConstants.v3FormatVersion ||
        header.container != VaultConstants.v3ContainerId ||
        header.cipherId != VaultConstants.cipherId ||
        header.kdf != VaultConstants.kdfId ||
        header.subkeyKdf != VaultConstants.v3SubkeyKdfId ||
        header.vaultIdB64 == null) {
      throw const VaultLoadException('Cabeçalho do cofre inválido.');
    }
  }
}
