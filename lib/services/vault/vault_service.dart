import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vault_data.dart';
import '../../utils/constants.dart';
import '../crypto/crypto_service.dart';
import '../crypto/sodium_provider.dart';
import '../storage/vault_file_service.dart';
import 'vault_chunk_crypto_service.dart';
import 'vault_chunked_file_writer.dart';
import 'vault_v3_header_factory.dart';

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
    final salt = cryptoService.randomBytes(
      sodium,
      sodium.crypto.pwhash.saltBytes,
    );
    final key = await cryptoService.deriveKeyInBackground(
      sodium: sodium,
      masterPassword: masterPassword,
      salt: salt,
      params: kdfParams,
    );
    final header = VaultV3HeaderFactory.create(
      sodium: sodium,
      kdfParams: kdfParams,
      salt: salt,
    );
    final vaultData = VaultData(
      version: VaultConstants.v3DataVersion,
      updatedAt: DateTime.now().toUtc(),
      entries: const [],
      documents: const [],
    );
    final target = await vaultFileService.vaultFileForName(fileName);

    try {
      await VaultChunkedFileWriter(
        fileService: vaultFileService,
        chunkCrypto: VaultChunkCryptoService(),
      ).write(
        sodium: sodium,
        target: target,
        header: header,
        data: vaultData,
        key: key,
      );
    } finally {
      key.dispose();
    }
  }
}

final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService(
    ref: ref,
    cryptoService: CryptoService(),
    vaultFileService: VaultFileService(),
  );
});
