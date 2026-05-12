import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:path/path.dart' as p;

import '../../models/vault_data.dart';
import '../../models/vault_header.dart';
import '../../utils/constants.dart';
import '../crypto/crypto_params.dart';
import '../crypto/crypto_service.dart';
import '../crypto/sodium_provider.dart';
import '../storage/vault_file_service.dart';
import 'vault_data_migrator.dart';

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
    final sodium = await ref.read(sodiumProvider.future);
    final file = fileName == null || fileName.trim().isEmpty
        ? await fileService.defaultVaultFile()
        : await fileService.vaultFileForName(fileName);
    final activeFileName = p.basename(file.path);
    if (!await file.exists()) {
      throw const VaultLoadException('Cofre não encontrado.');
    }

    final raf = await file.open();
    Uint8List headerBytes;
    Uint8List cipherBytes;
    try {
      final totalLen = await raf.length();
      if (totalLen < 4) {
        throw const VaultLoadException('Cabeçalho do cofre inválido.');
      }
      final headerLenBytes = await raf.read(4);
      if (headerLenBytes.length != 4) {
        throw const VaultLoadException('Cabeçalho do cofre inválido.');
      }
      final headerLen = ByteData.sublistView(
        Uint8List.fromList(headerLenBytes),
      ).getUint32(0, Endian.big);
      const maxHeaderLen = 1024 * 1024;
      if (headerLen == 0 ||
          headerLen > maxHeaderLen ||
          headerLen > totalLen - 4) {
        throw const VaultLoadException('Cabeçalho do cofre inválido.');
      }
      headerBytes = Uint8List.fromList(await raf.read(headerLen));
      if (headerBytes.lengthInBytes != headerLen) {
        throw const VaultLoadException('Cabeçalho do cofre inválido.');
      }
      final remaining = totalLen - 4 - headerLen;
      if (remaining <= 0) {
        throw const VaultLoadException('Conteúdo inválido.');
      }
      cipherBytes = Uint8List.fromList(await raf.read(remaining));
      if (cipherBytes.lengthInBytes != remaining) {
        throw const VaultLoadException('Conteúdo inválido.');
      }
    } finally {
      await raf.close();
    }

    late final VaultHeader header;
    try {
      final decodedHeader = jsonDecode(utf8.decode(headerBytes));
      if (decodedHeader is! Map) {
        throw const FormatException('Header is not an object.');
      }
      header = VaultHeader.fromJson(Map<String, dynamic>.from(decodedHeader));
      _validateHeader(header, sodium);
    } on VaultLoadException {
      rethrow;
    } catch (_) {
      throw const VaultLoadException('Cabeçalho do cofre inválido.');
    }

    final salt = base64Decode(header.saltB64);
    final nonce = base64Decode(header.nonceB64);
    final params = CryptoParams(
      memLimit: header.memLimit,
      opsLimit: header.opsLimit,
      parallelism: header.parallelism,
    );

    final key = await cryptoService.deriveKeyInBackground(
      sodium: sodium,
      masterPassword: masterPassword,
      salt: salt,
      params: params,
    );

    late final Uint8List plaintext;
    try {
      plaintext = cryptoService.decrypt(
        sodium: sodium,
        ciphertext: Uint8List.fromList(cipherBytes),
        nonce: nonce,
        key: key,
        headerBytes: Uint8List.fromList(headerBytes),
      );
    } catch (_) {
      key.dispose();
      throw const VaultAuthException(
        'Não foi possível validar a integridade do cofre. A palavra-passe pode estar incorreta ou o ficheiro pode ter sido alterado.',
      );
    }

    late final VaultData data;
    try {
      final decodedData = jsonDecode(utf8.decode(plaintext));
      if (decodedData is! Map) {
        throw const FormatException('Vault data is not an object.');
      }
      final migratedData = VaultDataMigrator.migrate(
        Map<String, dynamic>.from(decodedData),
      );
      data = VaultData.fromJson(migratedData);
    } catch (_) {
      key.dispose();
      throw const VaultLoadException(
        'Conteúdo do cofre inválido ou corrompido.',
      );
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }

    return VaultOpenResult(
      header: header,
      data: data,
      key: key,
      fileName: activeFileName,
    );
  }

  Future<VaultHeader> saveVault({
    required VaultHeader header,
    required VaultData data,
    required SecureKey key,
    String? fileName,
  }) async {
    final sodium = await ref.read(sodiumProvider.future);
    final oldNonceB64 = header.nonceB64;
    String newNonceB64;
    Uint8List nonce;
    do {
      nonce = cryptoService.randomBytes(
        sodium,
        sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
      );
      newNonceB64 = base64Encode(nonce);
    } while (newNonceB64 == oldNonceB64);

    final newHeader = VaultHeader(
      magic: header.magic,
      formatVersion: header.formatVersion,
      cipherId: header.cipherId,
      kdf: header.kdf,
      memLimit: header.memLimit,
      opsLimit: header.opsLimit,
      parallelism: header.parallelism,
      saltB64: header.saltB64,
      nonceB64: newNonceB64,
    );

    final headerBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(newHeader.toJson())),
    );
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode(data.toJson())),
    );
    late final Uint8List cipherBytes;
    try {
      cipherBytes = cryptoService.encrypt(
        sodium: sodium,
        plaintext: plaintext,
        nonce: nonce,
        key: key,
        headerBytes: headerBytes,
      );
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }

    final target = await fileService.vaultFileForName(fileName);
    await fileService.writeVault(
      target: target,
      headerBytes: headerBytes,
      cipherBytes: cipherBytes,
    );

    return newHeader;
  }

  Future<VaultRekeyResult> changeMasterPassword({
    required VaultHeader header,
    required VaultData data,
    required String currentPassword,
    required String newPassword,
    String? fileName,
  }) async {
    final validation = await loadAndDecrypt(
      masterPassword: currentPassword,
      fileName: fileName,
    );
    validation.key.dispose();

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
    final nonce = cryptoService.randomBytes(
      sodium,
      sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
    );
    final newKey = await cryptoService.deriveKeyInBackground(
      sodium: sodium,
      masterPassword: newPassword,
      salt: salt,
      params: params,
    );
    final newHeader = VaultHeader(
      magic: header.magic,
      formatVersion: header.formatVersion,
      cipherId: header.cipherId,
      kdf: header.kdf,
      memLimit: header.memLimit,
      opsLimit: header.opsLimit,
      parallelism: header.parallelism,
      saltB64: base64Encode(salt),
      nonceB64: base64Encode(nonce),
    );
    final headerBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(newHeader.toJson())),
    );
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode(data.toJson())),
    );

    try {
      final cipherBytes = cryptoService.encrypt(
        sodium: sodium,
        plaintext: plaintext,
        nonce: nonce,
        key: newKey,
        headerBytes: headerBytes,
      );
      final target = await fileService.vaultFileForName(fileName);
      await fileService.writeVault(
        target: target,
        headerBytes: headerBytes,
        cipherBytes: cipherBytes,
      );
      return VaultRekeyResult(
        header: newHeader,
        key: newKey,
        fileName: p.basename(target.path),
      );
    } catch (_) {
      newKey.dispose();
      rethrow;
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  void _validateHeader(VaultHeader header, SodiumSumo sodium) {
    if (header.magic != VaultConstants.magic) {
      throw const VaultLoadException('Identificador do cofre inválido.');
    }
    if (header.formatVersion != VaultConstants.formatVersion) {
      throw const VaultLoadException('Versão não suportada.');
    }
    if (header.cipherId != VaultConstants.cipherId) {
      throw const VaultLoadException('Cifra não suportada.');
    }
    if (header.kdf != VaultConstants.kdfId) {
      throw const VaultLoadException('Derivação de chave não suportada.');
    }
    if (base64Decode(header.nonceB64).length !=
        sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes) {
      throw const VaultLoadException('Nonce inválido.');
    }
    final saltLen = base64Decode(header.saltB64).length;
    if (saltLen != sodium.crypto.pwhash.saltBytes) {
      throw const VaultLoadException('Salt inválido.');
    }
    final pwhash = sodium.crypto.pwhash;
    final maxMem = pwhash.memLimitSensitive * 16;
    final maxOps = pwhash.opsLimitSensitive * 16;
    if (header.memLimit <= 0 ||
        header.memLimit > maxMem ||
        header.opsLimit <= 0 ||
        header.opsLimit > maxOps) {
      throw const VaultLoadException(
        'Parâmetros de derivação de chave inválidos.',
      );
    }
    if (header.parallelism <= 0 || header.parallelism > 16) {
      throw const VaultLoadException(
        'Parâmetros de derivação de chave inválidos.',
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

  VaultOpenResult({
    required this.header,
    required this.data,
    required this.key,
    required this.fileName,
  });
}

class VaultRekeyResult {
  final VaultHeader header;
  final SecureKey key;
  final String? fileName;

  VaultRekeyResult({
    required this.header,
    required this.key,
    required this.fileName,
  });
}
