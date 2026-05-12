import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import 'crypto_params.dart';

class CryptoService {
  CryptoParams defaultParams(SodiumSumo sodium) {
    final pwhash = sodium.crypto.pwhash;
    return CryptoParams(
      memLimit: pwhash.memLimitSensitive,
      opsLimit: pwhash.opsLimitModerate,
      parallelism: 1,
    );
  }

  Uint8List randomBytes(SodiumSumo sodium, int length) {
    return sodium.randombytes.buf(length);
  }

  SecureKey deriveKey({
    required SodiumSumo sodium,
    required String masterPassword,
    required Uint8List salt,
    required CryptoParams params,
  }) {
    return _deriveKey(
      sodium: sodium,
      masterPassword: masterPassword,
      salt: salt,
      memLimit: params.memLimit,
      opsLimit: params.opsLimit,
      parallelism: params.parallelism,
    );
  }

  Future<SecureKey> deriveKeyInBackground({
    required SodiumSumo sodium,
    required String masterPassword,
    required Uint8List salt,
    required CryptoParams params,
  }) async {
    final saltCopy = Uint8List.fromList(salt);
    final memLimit = params.memLimit;
    final opsLimit = params.opsLimit;
    final parallelism = params.parallelism;

    return sodium.runIsolated((_, _) {
      return _deriveKey(
        sodium: sodium,
        masterPassword: masterPassword,
        salt: saltCopy,
        memLimit: memLimit,
        opsLimit: opsLimit,
        parallelism: parallelism,
      );
    });
  }

  static SecureKey _deriveKey({
    required SodiumSumo sodium,
    required String masterPassword,
    required Uint8List salt,
    required int memLimit,
    required int opsLimit,
    required int parallelism,
  }) {
    final masterBytes = Int8List.fromList(utf8.encode(masterPassword));
    final pwhash = sodium.crypto.pwhash;
    final effectiveOpsLimit = (opsLimit * parallelism).clamp(
      pwhash.opsLimitMin,
      pwhash.opsLimitMax,
    );
    try {
      return sodium.crypto.pwhash.call(
        outLen: sodium.crypto.aeadXChaCha20Poly1305IETF.keyBytes,
        password: masterBytes,
        salt: salt,
        opsLimit: effectiveOpsLimit,
        memLimit: memLimit,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );
    } finally {
      masterBytes.fillRange(0, masterBytes.length, 0);
    }
  }

  Uint8List encrypt({
    required SodiumSumo sodium,
    required Uint8List plaintext,
    required Uint8List nonce,
    required SecureKey key,
    required Uint8List headerBytes,
  }) {
    return sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: plaintext,
      nonce: nonce,
      key: key,
      additionalData: headerBytes,
    );
  }

  Uint8List decrypt({
    required SodiumSumo sodium,
    required Uint8List ciphertext,
    required Uint8List nonce,
    required SecureKey key,
    required Uint8List headerBytes,
  }) {
    return sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: ciphertext,
      nonce: nonce,
      key: key,
      additionalData: headerBytes,
    );
  }
}
