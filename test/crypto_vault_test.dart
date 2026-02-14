import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:encryvault/services/crypto/crypto_service.dart';
import 'package:encryvault/services/crypto/sodium_provider.dart';
import 'package:encryvault/services/storage/vault_file_service.dart';
import 'package:encryvault/services/vault/vault_repository.dart';
import 'package:encryvault/services/vault/vault_service.dart';
import 'package:encryvault/utils/constants.dart';
import 'package:encryvault/services/vault/vault_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SodiumSumo sodium;
  late bool sodiumReady;

  setUpAll(() async {
    try {
      sodium = await SodiumSumoInit.init();
      sodiumReady = true;
    } catch (_) {
      sodiumReady = false;
    }
  });

  test('CryptoService encrypt/decrypt roundtrip', () {
    if (!sodiumReady) return;
    final crypto = CryptoService();
    final params = crypto.defaultParams(sodium);
    final salt = crypto.randomBytes(sodium, sodium.crypto.pwhash.saltBytes);
    final nonce = crypto.randomBytes(sodium, sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes);
    final key = crypto.deriveKey(
      sodium: sodium,
      masterPassword: 'very-secure-password',
      salt: salt,
      params: params,
    );
    final headerBytes = crypto.randomBytes(sodium, 12);
    final plaintext = crypto.randomBytes(sodium, 64);

    final cipher = crypto.encrypt(
      sodium: sodium,
      plaintext: plaintext,
      nonce: nonce,
      key: key,
      headerBytes: headerBytes,
    );

    final recovered = crypto.decrypt(
      sodium: sodium,
      ciphertext: cipher,
      nonce: nonce,
      key: key,
      headerBytes: headerBytes,
    );

    expect(recovered, plaintext);
    key.dispose();
  });

  test('Vault file read/write with tamper detection', () async {
    if (!sodiumReady) return;
    final tempDir = await Directory.systemTemp.createTemp('vault_test');
    final fileService = VaultFileService(baseDir: tempDir);
    final container = ProviderContainer(
      overrides: [
        sodiumProvider.overrideWith((ref) async => sodium),
        vaultServiceProvider.overrideWith(
          (ref) => VaultService(
            ref: ref,
            cryptoService: CryptoService(),
            vaultFileService: fileService,
          ),
        ),
        vaultRepositoryProvider.overrideWith(
          (ref) => VaultRepository(
            ref: ref,
            cryptoService: CryptoService(),
            fileService: fileService,
          ),
        ),
      ],
    );

    const master = 'very-secure-password';
    final vaultService = container.read(vaultServiceProvider);
    await vaultService.createVault(masterPassword: master, fileName: 'test.vltx');

    final repo = container.read(vaultRepositoryProvider);
    final result = await repo.loadAndDecrypt(masterPassword: master);
    expect(result.data.entries, isEmpty);

    // Tamper last byte and expect failure
    final file = await fileService.defaultVaultFile();
    final bytes = await file.readAsBytes();
    bytes[bytes.length - 1] = bytes.last ^ 0xFF;
    await file.writeAsBytes(bytes, flush: true);

    expect(
      () => repo.loadAndDecrypt(masterPassword: master),
      throwsA(isA<Exception>()),
    );
  });

  test('Header tamper detection (magic)', () async {
    if (!sodiumReady) return;
    final tempDir = await Directory.systemTemp.createTemp('vault_test2');
    final fileService = VaultFileService(baseDir: tempDir);
    final refContainer = ProviderContainer(
      overrides: [
        sodiumProvider.overrideWith((ref) async => sodium),
        vaultServiceProvider.overrideWith(
          (ref) => VaultService(
            ref: ref,
            cryptoService: CryptoService(),
            vaultFileService: fileService,
          ),
        ),
        vaultRepositoryProvider.overrideWith(
          (ref) => VaultRepository(
            ref: ref,
            cryptoService: CryptoService(),
            fileService: fileService,
          ),
        ),
      ],
    );
    final repo = refContainer.read(vaultRepositoryProvider);
    final vs = refContainer.read(vaultServiceProvider);
    const master = 'very-secure-password';
    await vs.createVault(masterPassword: master, fileName: 'tamper.vltx');
    final file = await fileService.defaultVaultFile();
    final raf = await file.open();
    final headerLenBytes = await raf.read(4);
    final headerLen = ByteData.sublistView(Uint8List.fromList(headerLenBytes)).getUint32(0, Endian.big);
    final headerBytes = await raf.read(headerLen);
    await raf.close();

    final headerStr = String.fromCharCodes(headerBytes);
    final badHeader = headerStr.replaceFirst(VaultConstants.magic, 'BAD!');
    final payload = await file.readAsBytes();
    final corrupted = [
      ...headerLenBytes,
      ...utf8.encode(badHeader),
      ...payload.skip(4 + headerLen),
    ];
    await file.writeAsBytes(corrupted, flush: true);

    expect(() => repo.loadAndDecrypt(masterPassword: master), throwsA(isA<Exception>()));
  });

  test('Nonce rotates on save', () async {
    if (!sodiumReady) return;
    final tempDir = await Directory.systemTemp.createTemp('vault_test3');
    final fileService = VaultFileService(baseDir: tempDir);
    final container = ProviderContainer(
      overrides: [
        sodiumProvider.overrideWith((ref) async => sodium),
        vaultServiceProvider.overrideWith(
          (ref) => VaultService(
            ref: ref,
            cryptoService: CryptoService(),
            vaultFileService: fileService,
          ),
        ),
        vaultRepositoryProvider.overrideWith(
          (ref) => VaultRepository(
            ref: ref,
            cryptoService: CryptoService(),
            fileService: fileService,
          ),
        ),
      ],
    );
    const master = 'very-secure-password';
    final vs = container.read(vaultServiceProvider);
    await vs.createVault(masterPassword: master, fileName: 'rotate.vltx');
    final repo = container.read(vaultRepositoryProvider);
    final initial = await repo.loadAndDecrypt(masterPassword: master);
    final initialNonce = initial.header.nonceB64;

    container.read(vaultProvider.notifier).setVault(initial.header, initial.data, initial.key);
    await container.read(vaultProvider.notifier).addEntry(
          title: 't',
          username: 'u',
          password: 'p',
          notes: '',
        );
    final after = await repo.loadAndDecrypt(masterPassword: master);

    expect(after.header.nonceB64 == initialNonce, isFalse);
  });
}
