import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../../models/vault_header.dart';
import '../../utils/constants.dart';
import '../crypto/crypto_params.dart';
import 'vault_document_limits.dart';

class VaultV3HeaderFactory {
  const VaultV3HeaderFactory._();

  static VaultHeader create({
    required SodiumSumo sodium,
    required CryptoParams kdfParams,
    required Uint8List salt,
  }) {
    final vaultId = sodium.randombytes.buf(24);
    return VaultHeader(
      magic: VaultConstants.magic,
      formatVersion: VaultConstants.v3FormatVersion,
      container: VaultConstants.v3ContainerId,
      cipherId: VaultConstants.cipherId,
      kdf: VaultConstants.kdfId,
      subkeyKdf: VaultConstants.v3SubkeyKdfId,
      memLimit: kdfParams.memLimit,
      opsLimit: kdfParams.opsLimit,
      parallelism: kdfParams.parallelism,
      saltB64: base64Encode(salt),
      vaultIdB64: base64Encode(vaultId),
      defaultChunkSize: VaultDocumentLimits.defaultChunkSize,
    );
  }
}
