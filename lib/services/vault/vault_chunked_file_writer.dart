import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../../models/vault_data.dart';
import '../../models/vault_document.dart';
import '../../models/vault_footer_v3.dart';
import '../../models/vault_header.dart';
import '../../models/vault_manifest_v3.dart';
import '../storage/vault_file_service.dart';
import 'vault_chunk_crypto_service.dart';
import 'vault_document_limits.dart';

class VaultDocumentImport {
  final String id;
  final String sourcePath;
  final String fileName;
  final String extension;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  const VaultDocumentImport({
    required this.id,
    required this.sourcePath,
    required this.fileName,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });
}

class VaultChunkedWriteResult {
  final VaultHeader header;
  final Uint8List headerBytes;
  final VaultData data;

  const VaultChunkedWriteResult({
    required this.header,
    required this.headerBytes,
    required this.data,
  });
}

class VaultChunkedFileWriter {
  VaultChunkedFileWriter({
    required this.fileService,
    required this.chunkCrypto,
  });

  final VaultFileService fileService;
  final VaultChunkCryptoService chunkCrypto;

  Future<VaultChunkedWriteResult> write({
    required SodiumSumo sodium,
    required File target,
    required VaultHeader header,
    required VaultData data,
    required SecureKey key,
    File? sourceFile,
    Uint8List? headerBytesOverride,
    Uint8List? sourceHeaderBytes,
    SecureKey? oldKey,
    VaultHeader? oldHeader,
    List<VaultDocumentImport> imports = const [],
    bool reencryptExistingChunks = false,
  }) async {
    final headerBytes =
        headerBytesOverride ??
        Uint8List.fromList(utf8.encode(jsonEncode(header.toJson())));
    final tmp = await fileService.createTempVaultFile(target);
    final out = await tmp.open(mode: FileMode.write);
    RandomAccessFile? source;
    SecureKey? chunkKey;
    SecureKey? oldChunkKey;
    SecureKey? manifestKey;
    try {
      final headerLen = ByteData(4)
        ..setUint32(0, headerBytes.length, Endian.big);
      await out.writeFrom(headerLen.buffer.asUint8List());
      await out.writeFrom(headerBytes);
      source = sourceFile != null && await sourceFile.exists()
          ? await sourceFile.open()
          : null;
      chunkKey = chunkCrypto.deriveChunkKey(sodium, key);
      if (reencryptExistingChunks) {
        oldChunkKey = chunkCrypto.deriveChunkKey(sodium, oldKey ?? key);
      }

      final documents = <VaultDocumentMetadata>[];
      for (final document in data.documents) {
        final nextChunks = <VaultDocumentChunkMetadata>[];
        for (final chunk in document.chunks) {
          if (source == null) {
            throw const FileSystemException('Ficheiro de cofre inexistente.');
          }
          await source.setPosition(chunk.offset);
          final encrypted = Uint8List.fromList(
            await source.read(chunk.encryptedSize),
          );
          final nextOffset = await out.position();
          if (reencryptExistingChunks) {
            final oldHeaderBytes = sourceHeaderBytes ?? headerBytes;
            final oldAad = chunkCrypto.chunkAad(
              headerBytes: oldHeaderBytes,
              documentId: document.id,
              chunkIndex: chunk.index,
              plainSize: chunk.plainSize,
            );
            final plaintext = chunkCrypto.decrypt(
              sodium: sodium,
              ciphertext: encrypted,
              nonce: base64Decode(chunk.nonceB64),
              key: oldChunkKey!,
              aad: oldAad,
            );
            final nonce = sodium.randombytes.buf(
              sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
            );
            final aad = chunkCrypto.chunkAad(
              headerBytes: headerBytes,
              documentId: document.id,
              chunkIndex: chunk.index,
              plainSize: chunk.plainSize,
            );
            final nextEncrypted = chunkCrypto.encrypt(
              sodium: sodium,
              plaintext: plaintext,
              nonce: nonce,
              key: chunkKey,
              aad: aad,
            );
            plaintext.fillRange(0, plaintext.length, 0);
            await out.writeFrom(nextEncrypted);
            nextChunks.add(
              chunk.copyWith(
                offset: nextOffset,
                encryptedSize: nextEncrypted.length,
                nonceB64: base64Encode(nonce),
              ),
            );
          } else {
            await out.writeFrom(encrypted);
            nextChunks.add(chunk.copyWith(offset: nextOffset));
          }
        }
        documents.add(document.copyWith(chunks: nextChunks));
      }

      for (final import in imports) {
        documents.add(
          await _writeImportedDocument(
            sodium: sodium,
            out: out,
            headerBytes: headerBytes,
            chunkKey: chunkKey,
            import: import,
          ),
        );
      }

      final nextData = data.copyWith(documents: documents);
      final manifestPlaintext = Uint8List.fromList(
        utf8.encode(
          jsonEncode(VaultManifestV3.fromVaultData(nextData).toJson()),
        ),
      );
      final manifestOffset = await out.position();
      final manifestNonce = sodium.randombytes.buf(
        sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
      );
      final predictedEncryptedSize =
          manifestPlaintext.length +
          sodium.crypto.aeadXChaCha20Poly1305IETF.aBytes;
      final footer = VaultFooterV3(
        manifestOffset: manifestOffset,
        manifestEncryptedSize: predictedEncryptedSize,
        manifestPlainSize: manifestPlaintext.length,
        manifestNonce: manifestNonce,
      );
      manifestKey = chunkCrypto.deriveManifestKey(sodium, key);
      final manifestCiphertext = chunkCrypto.encrypt(
        sodium: sodium,
        plaintext: manifestPlaintext,
        nonce: manifestNonce,
        key: manifestKey,
        aad: chunkCrypto.manifestAad(headerBytes: headerBytes, footer: footer),
      );
      manifestPlaintext.fillRange(0, manifestPlaintext.length, 0);
      await out.writeFrom(manifestCiphertext);
      await out.writeFrom(footer.toBytes());
      await out.flush();
      await out.close();
      await source?.close();
      await fileService.replaceVaultWithTemp(target: target, tmp: tmp);
      return VaultChunkedWriteResult(
        header: header,
        headerBytes: headerBytes,
        data: nextData,
      );
    } catch (_) {
      try {
        await out.close();
      } catch (_) {}
      try {
        await source?.close();
      } catch (_) {}
      if (await tmp.exists()) {
        await tmp.delete();
      }
      rethrow;
    } finally {
      chunkKey?.dispose();
      oldChunkKey?.dispose();
      manifestKey?.dispose();
    }
  }

  Future<VaultDocumentMetadata> _writeImportedDocument({
    required SodiumSumo sodium,
    required RandomAccessFile out,
    required Uint8List headerBytes,
    required SecureKey chunkKey,
    required VaultDocumentImport import,
  }) async {
    final input = await File(import.sourcePath).open();
    final chunks = <VaultDocumentChunkMetadata>[];
    try {
      var index = 0;
      while (true) {
        final plain = Uint8List.fromList(
          await input.read(VaultDocumentLimits.defaultChunkSize),
        );
        if (plain.isEmpty) break;
        final offset = await out.position();
        final nonce = sodium.randombytes.buf(
          sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
        );
        final aad = chunkCrypto.chunkAad(
          headerBytes: headerBytes,
          documentId: import.id,
          chunkIndex: index,
          plainSize: plain.length,
        );
        final encrypted = chunkCrypto.encrypt(
          sodium: sodium,
          plaintext: plain,
          nonce: nonce,
          key: chunkKey,
          aad: aad,
        );
        plain.fillRange(0, plain.length, 0);
        await out.writeFrom(encrypted);
        chunks.add(
          VaultDocumentChunkMetadata(
            index: index,
            offset: offset,
            encryptedSize: encrypted.length,
            plainSize: plain.length,
            nonceB64: base64Encode(nonce),
          ),
        );
        index += 1;
      }
    } finally {
      await input.close();
    }
    return VaultDocumentMetadata(
      id: import.id,
      fileName: import.fileName,
      extension: import.extension,
      mimeType: import.mimeType,
      sizeBytes: import.sizeBytes,
      createdAt: import.createdAt,
      updatedAt: import.createdAt,
      chunkSize: VaultDocumentLimits.defaultChunkSize,
      chunks: chunks,
    );
  }
}
