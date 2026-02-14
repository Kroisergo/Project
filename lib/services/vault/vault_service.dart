import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vault_data.dart';
import '../../models/vault_header.dart';
import '../../utils/constants.dart';
import '../crypto/crypto_params.dart';
import '../crypto/crypto_service.dart';
import '../crypto/sodium_provider.dart';
import '../storage/vault_file_service.dart';

class VaultService {
  VaultService({
    required this.ref,
    required this.cryptoService,
    required this.vaultFileService,
  });

  final Ref ref;
  final CryptoService cryptoService;
  final VaultFileService vaultFileService;

  Future<void> createVault({
    required String masterPassword,
    String? fileName,
  }) async {
    final sodium = await ref.read(sodiumProvider.future);
    final kdfParams = cryptoService.defaultParams(sodium);
    final salt = cryptoService.randomBytes(sodium, sodium.crypto.pwhash.saltBytes);
    final nonce = cryptoService.randomBytes(
      sodium,
      sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
    );

    final key = cryptoService.deriveKey(
      sodium: sodium,
      masterPassword: masterPassword,
      salt: salt,
      params: kdfParams,
    );

    final vaultData = VaultData(
      version: VaultConstants.formatVersion,
      updatedAt: DateTime.now().toUtc(),
      entries: const [],
    );

    final plaintext = utf8.encode(jsonEncode(vaultData.toJson()));
    final header = _buildHeader(
      kdfParams: kdfParams,
      salt: salt,
      nonce: nonce,
    );
    final headerBytes = utf8.encode(jsonEncode(header.toJson()));

    late final Uint8List cipherBytes;
    try {
      cipherBytes = cryptoService.encrypt(
        sodium: sodium,
        plaintext: Uint8List.fromList(plaintext),
        nonce: nonce,
        key: key,
        headerBytes: Uint8List.fromList(headerBytes),
      );
    } finally {
      key.dispose();
    }

    final target = await vaultFileService.vaultFileForName(fileName);
    await vaultFileService.writeVault(
      target: target,
      headerBytes: Uint8List.fromList(headerBytes),
      cipherBytes: cipherBytes,
    );
  }

  VaultHeader _buildHeader({
    required CryptoParams kdfParams,
    required Uint8List salt,
    required Uint8List nonce,
  }) {
    return VaultHeader(
      magic: VaultConstants.magic,
      formatVersion: VaultConstants.formatVersion,
      cipherId: VaultConstants.cipherId,
      kdf: VaultConstants.kdfId,
      memLimit: kdfParams.memLimit,
      opsLimit: kdfParams.opsLimit,
      parallelism: kdfParams.parallelism,
      saltB64: base64Encode(salt),
      nonceB64: base64Encode(nonce),
    );
  }
}

final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService(
    ref: ref,
    cryptoService: CryptoService(),
    vaultFileService: VaultFileService(),
  );
});
