import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../../models/vault_footer_v3.dart';

class VaultChunkCryptoService {
  static const manifestContext = 'EV3MNFST';
  static const chunkContext = 'EV3CHNKS';
  static const chunkDomain = 'EVLT3-CHUNK-v1';

  SecureKey deriveManifestKey(SodiumSumo sodium, SecureKey masterKey) {
    return sodium.crypto.kdf.deriveFromKey(
      masterKey: masterKey,
      context: manifestContext,
      subkeyId: BigInt.one,
      subkeyLen: sodium.crypto.aeadXChaCha20Poly1305IETF.keyBytes,
    );
  }

  SecureKey deriveChunkKey(SodiumSumo sodium, SecureKey masterKey) {
    return sodium.crypto.kdf.deriveFromKey(
      masterKey: masterKey,
      context: chunkContext,
      subkeyId: BigInt.from(2),
      subkeyLen: sodium.crypto.aeadXChaCha20Poly1305IETF.keyBytes,
    );
  }

  Uint8List manifestAad({
    required Uint8List headerBytes,
    required VaultFooterV3 footer,
  }) {
    final builder = BytesBuilder(copy: false)
      ..add(headerBytes)
      ..add(footer.aadBytes());
    return builder.takeBytes();
  }

  Uint8List chunkAad({
    required Uint8List headerBytes,
    required String documentId,
    required int chunkIndex,
    required int plainSize,
  }) {
    final meta = utf8.encode(
      '$chunkDomain\n$documentId\n$chunkIndex\n$plainSize',
    );
    final builder = BytesBuilder(copy: false)
      ..add(meta)
      ..add(headerBytes);
    return builder.takeBytes();
  }

  Uint8List encrypt({
    required SodiumSumo sodium,
    required Uint8List plaintext,
    required Uint8List nonce,
    required SecureKey key,
    required Uint8List aad,
  }) {
    return sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: plaintext,
      nonce: nonce,
      key: key,
      additionalData: aad,
    );
  }

  Uint8List decrypt({
    required SodiumSumo sodium,
    required Uint8List ciphertext,
    required Uint8List nonce,
    required SecureKey key,
    required Uint8List aad,
  }) {
    return sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: ciphertext,
      nonce: nonce,
      key: key,
      additionalData: aad,
    );
  }
}
