import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodium/sodium_sumo.dart';

import 'package:encryvault/services/crypto/crypto_service.dart';
import 'package:encryvault/services/crypto/sodium_provider.dart';
import 'package:encryvault/services/security/trash_pin_service.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('CryptoService encrypt/decrypt roundtrip', () {
    if (!sodiumReady) return;
    final crypto = CryptoService();
    final params = crypto.defaultParams(sodium);
    final salt = crypto.randomBytes(sodium, sodium.crypto.pwhash.saltBytes);
    final nonce = crypto.randomBytes(
      sodium,
      sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
    );
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

  test('Trash PIN stores a sodium hash and verifies valid PIN only', () async {
    if (!sodiumReady) return;
    const storage = FlutterSecureStorage();
    final service = TrashPinService(
      storage: storage,
      sodiumLoader: () async => sodium,
    );

    await service.setPin(TrashPinAction.enter, '1234');

    expect(await service.isEnabled(TrashPinAction.enter), isTrue);
    expect(await service.verify(TrashPinAction.enter, '1234'), isTrue);
    expect(await service.verify(TrashPinAction.enter, '0000'), isFalse);

    final raw = await storage.read(key: 'trash_pin_enter_pin');
    expect(raw, isNotNull);
    expect(raw, isNot('1234'));
    final decoded = jsonDecode(raw!);
    expect(decoded, isA<Map>());
    expect(decoded['hash'], isA<String>());
    expect(decoded['hash'], isNot('1234'));
  });

  test(
    'Trash PIN migrates legacy plaintext PIN after valid verification',
    () async {
      if (!sodiumReady) return;
      FlutterSecureStorage.setMockInitialValues({
        'trash_pin_enter_enabled': 'true',
        'trash_pin_enter_pin': '4321',
      });
      const storage = FlutterSecureStorage();
      final service = TrashPinService(
        storage: storage,
        sodiumLoader: () async => sodium,
      );

      expect(await service.verify(TrashPinAction.enter, '0000'), isFalse);
      expect(await storage.read(key: 'trash_pin_enter_pin'), '4321');
      expect(await service.verify(TrashPinAction.enter, '4321'), isTrue);

      final migrated = await storage.read(key: 'trash_pin_enter_pin');
      expect(migrated, isNot('4321'));
      expect(jsonDecode(migrated!)['hash'], isA<String>());
    },
  );

  test('Trash PIN can change and disable hashed PIN', () async {
    if (!sodiumReady) return;
    const storage = FlutterSecureStorage();
    final service = TrashPinService(
      storage: storage,
      sodiumLoader: () async => sodium,
    );

    await service.setPin(TrashPinAction.delete, '1234');

    expect(
      await service.changePin(
        TrashPinAction.delete,
        oldPin: '0000',
        newPin: '9876',
      ),
      isFalse,
    );
    expect(
      await service.changePin(
        TrashPinAction.delete,
        oldPin: '1234',
        newPin: '9876',
      ),
      isTrue,
    );
    expect(await service.verify(TrashPinAction.delete, '1234'), isFalse);
    expect(await service.verify(TrashPinAction.delete, '9876'), isTrue);

    await service.disable(TrashPinAction.delete);

    expect(await service.isEnabled(TrashPinAction.delete), isFalse);
    expect(await service.verify(TrashPinAction.delete, 'wrong'), isTrue);
    expect(await storage.read(key: 'trash_pin_delete_pin'), isNull);
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
    await vaultService.createVault(masterPassword: master);

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
    await vs.createVault(masterPassword: master);
    final file = await fileService.defaultVaultFile();
    final raf = await file.open();
    final headerLenBytes = await raf.read(4);
    final headerLen = ByteData.sublistView(
      Uint8List.fromList(headerLenBytes),
    ).getUint32(0, Endian.big);
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

    expect(
      () => repo.loadAndDecrypt(masterPassword: master),
      throwsA(isA<Exception>()),
    );
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
    await vs.createVault(masterPassword: master);
    final repo = container.read(vaultRepositoryProvider);
    final initial = await repo.loadAndDecrypt(masterPassword: master);
    final initialNonce = initial.header.nonceB64;

    container
        .read(vaultProvider.notifier)
        .setVault(initial.header, initial.data, initial.key);
    await container
        .read(vaultProvider.notifier)
        .addEntry(title: 't', username: 'u', password: 'p', notes: '');
    final after = await repo.loadAndDecrypt(masterPassword: master);

    expect(after.header.nonceB64 == initialNonce, isFalse);
  });

  test('Entry password history follows global preference', () async {
    if (!sodiumReady) return;
    final tempDir = await Directory.systemTemp.createTemp('vault_history_test');
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
    await container
        .read(vaultServiceProvider)
        .createVault(masterPassword: master);
    final repo = container.read(vaultRepositoryProvider);
    final initial = await repo.loadAndDecrypt(masterPassword: master);
    container
        .read(vaultProvider.notifier)
        .setVault(initial.header, initial.data, initial.key);

    final entryId = await container
        .read(vaultProvider.notifier)
        .addEntry(title: 'Email', username: 'u', password: 'first', notes: '');
    await container
        .read(vaultProvider.notifier)
        .updateEntry(
          id: entryId,
          title: 'Email',
          username: 'u',
          password: 'second',
          notes: '',
        );

    var entry = container
        .read(vaultProvider)
        .data!
        .entries
        .singleWhere((entry) => entry.id == entryId);
    expect(entry.passwordHistory.map((item) => item.password), ['first']);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.savePasswordHistory, false);
    await container
        .read(vaultProvider.notifier)
        .updateEntry(
          id: entryId,
          title: 'Email',
          username: 'u',
          password: 'third',
          notes: '',
        );

    entry = container
        .read(vaultProvider)
        .data!
        .entries
        .singleWhere((entry) => entry.id == entryId);
    expect(entry.passwordHistory.map((item) => item.password), ['first']);

    await container
        .read(vaultProvider.notifier)
        .removePasswordHistoryItem(id: entryId, historyIndex: 0);
    entry = container
        .read(vaultProvider)
        .data!
        .entries
        .singleWhere((entry) => entry.id == entryId);
    expect(entry.passwordHistory, isEmpty);

    await prefs.setBool(PrefsKeys.savePasswordHistory, true);
    await container
        .read(vaultProvider.notifier)
        .updateEntry(
          id: entryId,
          title: 'Email',
          username: 'u',
          password: 'fourth',
          notes: '',
        );
    await container.read(vaultProvider.notifier).clearPasswordHistory(entryId);
    entry = container
        .read(vaultProvider)
        .data!
        .entries
        .singleWhere((entry) => entry.id == entryId);
    expect(entry.passwordHistory, isEmpty);
  });

  test('Master password change re-encrypts vault and preserves data', () async {
    if (!sodiumReady) return;
    final tempDir = await Directory.systemTemp.createTemp('vault_rekey_test');
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
    const oldMaster = 'OldStrongPassword12!';
    const newMaster = 'NewStrongPassword34!';
    await container
        .read(vaultServiceProvider)
        .createVault(masterPassword: oldMaster);
    final repo = container.read(vaultRepositoryProvider);
    final initial = await repo.loadAndDecrypt(masterPassword: oldMaster);
    container
        .read(vaultProvider.notifier)
        .setVault(
          initial.header,
          initial.data,
          initial.key,
          fileName: initial.fileName,
        );
    await container
        .read(vaultProvider.notifier)
        .addEntry(
          title: 'Email',
          username: 'user@example.com',
          password: 'EntryPassword12!',
          notes: 'note',
        );
    final beforeState = container.read(vaultProvider);
    final beforeHeader = beforeState.header!;
    final beforeData = beforeState.data!;

    await container
        .read(vaultProvider.notifier)
        .changeMasterPassword(
          currentPassword: oldMaster,
          newPassword: newMaster,
        );
    final afterState = container.read(vaultProvider);

    await expectLater(
      repo.loadAndDecrypt(masterPassword: oldMaster),
      throwsA(isA<VaultAuthException>()),
    );
    final reopened = await repo.loadAndDecrypt(masterPassword: newMaster);

    expect(afterState.header!.magic, VaultConstants.magic);
    expect(afterState.header!.formatVersion, VaultConstants.formatVersion);
    expect(afterState.header!.saltB64, isNot(beforeHeader.saltB64));
    expect(afterState.header!.nonceB64, isNot(beforeHeader.nonceB64));
    expect(reopened.header.magic, VaultConstants.magic);
    expect(reopened.header.formatVersion, VaultConstants.formatVersion);
    expect(reopened.header.saltB64, afterState.header!.saltB64);
    expect(reopened.header.nonceB64, afterState.header!.nonceB64);
    expect(reopened.data.version, beforeData.version);
    expect(reopened.data.entries, hasLength(1));
    expect(reopened.data.entries.single.id, beforeData.entries.single.id);
    expect(reopened.data.entries.single.title, 'Email');
    expect(reopened.data.entries.single.username, 'user@example.com');
    expect(reopened.data.entries.single.password, 'EntryPassword12!');
    expect(reopened.data.entries.single.notes, 'note');
    reopened.key.dispose();
  });

  test('Wrong current master password does not rewrite vault', () async {
    if (!sodiumReady) return;
    final tempDir = await Directory.systemTemp.createTemp(
      'vault_rekey_wrong_test',
    );
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
    const oldMaster = 'OldStrongPassword12!';
    await container
        .read(vaultServiceProvider)
        .createVault(masterPassword: oldMaster);
    final repo = container.read(vaultRepositoryProvider);
    final initial = await repo.loadAndDecrypt(masterPassword: oldMaster);
    container
        .read(vaultProvider.notifier)
        .setVault(
          initial.header,
          initial.data,
          initial.key,
          fileName: initial.fileName,
        );
    await container
        .read(vaultProvider.notifier)
        .addEntry(title: 'Email', username: 'u', password: 'p', notes: '');
    final file = await fileService.defaultVaultFile();
    final beforeBytes = await file.readAsBytes();
    final beforeHeader = container.read(vaultProvider).header!;

    await expectLater(
      container
          .read(vaultProvider.notifier)
          .changeMasterPassword(
            currentPassword: 'wrong-password',
            newPassword: 'NewStrongPassword34!',
          ),
      throwsA(isA<VaultAuthException>()),
    );

    expect(await file.readAsBytes(), beforeBytes);
    expect(container.read(vaultProvider).header!.saltB64, beforeHeader.saltB64);
    expect(
      container.read(vaultProvider).header!.nonceB64,
      beforeHeader.nonceB64,
    );
    final reopened = await repo.loadAndDecrypt(masterPassword: oldMaster);
    expect(reopened.data.entries.single.title, 'Email');
    reopened.key.dispose();
  });

  test(
    'Write failure during master password change keeps old vault readable',
    () async {
      if (!sodiumReady) return;
      final tempDir = await Directory.systemTemp.createTemp(
        'vault_rekey_write_failure_test',
      );
      final fileService = _FailingVaultFileService(baseDir: tempDir);
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
      const oldMaster = 'OldStrongPassword12!';
      await container
          .read(vaultServiceProvider)
          .createVault(masterPassword: oldMaster);
      final repo = container.read(vaultRepositoryProvider);
      final initial = await repo.loadAndDecrypt(masterPassword: oldMaster);
      container
          .read(vaultProvider.notifier)
          .setVault(
            initial.header,
            initial.data,
            initial.key,
            fileName: initial.fileName,
          );
      await container
          .read(vaultProvider.notifier)
          .addEntry(title: 'Email', username: 'u', password: 'p', notes: '');
      fileService.failNextWrite = true;

      await expectLater(
        container
            .read(vaultProvider.notifier)
            .changeMasterPassword(
              currentPassword: oldMaster,
              newPassword: 'NewStrongPassword34!',
            ),
        throwsA(isA<Exception>()),
      );

      final reopened = await repo.loadAndDecrypt(masterPassword: oldMaster);
      expect(reopened.data.entries.single.title, 'Email');
      reopened.key.dispose();
    },
  );

  test(
    'Backup validation accepts valid vault and rejects corrupted file',
    () async {
      if (!sodiumReady) return;
      final tempDir = await Directory.systemTemp.createTemp(
        'vault_backup_test',
      );
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
        ],
      );
      await container
          .read(vaultServiceProvider)
          .createVault(masterPassword: 'StrongPassword12!');
      final file = await fileService.defaultVaultFile();

      final valid = await fileService.validateVaultFileStructure(file.path);
      expect(valid.isValid, isTrue);
      expect(valid.payloadBytes, greaterThan(0));

      await file.writeAsBytes([0, 1, 2, 3], flush: true);
      final invalid = await fileService.validateVaultFileStructure(file.path);
      expect(invalid.isValid, isFalse);
    },
  );

  test('Automatic local backups are created and pruned on overwrite', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'vault_auto_backup_test',
    );
    final fileService = VaultFileService(baseDir: tempDir);
    final target = await fileService.defaultVaultFile();

    await fileService.writeVault(
      target: target,
      headerBytes: Uint8List.fromList([1]),
      cipherBytes: Uint8List.fromList([2]),
    );
    final firstBytes = await target.readAsBytes();

    await fileService.writeVault(
      target: target,
      headerBytes: Uint8List.fromList([3]),
      cipherBytes: Uint8List.fromList([4]),
    );

    var backups = await _automaticBackups(fileService);
    expect(backups, hasLength(1));
    expect(await backups.single.readAsBytes(), firstBytes);

    for (var i = 0; i < 6; i += 1) {
      await fileService.writeVault(
        target: target,
        headerBytes: Uint8List.fromList([10 + i]),
        cipherBytes: Uint8List.fromList([20 + i]),
      );
    }

    backups = await _automaticBackups(fileService);
    expect(backups, hasLength(VaultFileService.automaticBackupRetention));
  });
}

class _FailingVaultFileService extends VaultFileService {
  _FailingVaultFileService({required super.baseDir});

  bool failNextWrite = false;

  @override
  Future<File> writeVault({
    required File target,
    required Uint8List headerBytes,
    required Uint8List cipherBytes,
  }) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw Exception('simulated write failure');
    }
    return super.writeVault(
      target: target,
      headerBytes: headerBytes,
      cipherBytes: cipherBytes,
    );
  }
}

Future<List<File>> _automaticBackups(VaultFileService fileService) async {
  final dir = await fileService.automaticBackupDirectory();
  if (!await dir.exists()) return [];
  final backups = <File>[];
  await for (final entity in dir.list()) {
    if (entity is File) backups.add(entity);
  }
  backups.sort((a, b) => a.path.compareTo(b.path));
  return backups;
}
