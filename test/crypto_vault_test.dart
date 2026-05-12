import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodium/sodium_sumo.dart';

import 'package:encryvault/services/crypto/crypto_params.dart';
import 'package:encryvault/services/crypto/crypto_service.dart';
import 'package:encryvault/services/crypto/sodium_provider.dart';
import 'package:encryvault/services/security/trash_pin_service.dart';
import 'package:encryvault/services/storage/vault_file_service.dart';
import 'package:encryvault/services/vault/vault_document_limits.dart';
import 'package:encryvault/services/vault/vault_document_service.dart';
import 'package:encryvault/models/vault_container_format.dart';
import 'package:encryvault/models/vault_footer_v3.dart';
import 'package:encryvault/models/vault_header.dart';
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

  test('CryptoService derives equivalent keys in background', () async {
    if (!sodiumReady) return;
    final crypto = CryptoService();
    final params = CryptoParams(
      memLimit: sodium.crypto.pwhash.memLimitInteractive,
      opsLimit: sodium.crypto.pwhash.opsLimitInteractive,
      parallelism: 1,
    );
    final salt = Uint8List.fromList(
      List<int>.generate(sodium.crypto.pwhash.saltBytes, (index) => index),
    );

    final foregroundKey = crypto.deriveKey(
      sodium: sodium,
      masterPassword: 'background-derivation-password',
      salt: salt,
      params: params,
    );
    final backgroundKey = await crypto.deriveKeyInBackground(
      sodium: sodium,
      masterPassword: 'background-derivation-password',
      salt: salt,
      params: params,
    );

    expect(backgroundKey.extractBytes(), foregroundKey.extractBytes());
    foregroundKey.dispose();
    backgroundKey.dispose();
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

  test('Saving a v3 vault rewrites encrypted content', () async {
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
    expect(initial.format, VaultContainerFormat.v3);

    container
        .read(vaultProvider.notifier)
        .setVault(
          initial.header,
          initial.data,
          initial.key,
          fileName: initial.fileName,
          format: initial.format,
          headerBytes: initial.headerBytes,
        );
    final file = await fileService.defaultVaultFile();
    final beforeBytes = await file.readAsBytes();
    await container
        .read(vaultProvider.notifier)
        .addEntry(title: 't', username: 'u', password: 'p', notes: '');
    final after = await repo.loadAndDecrypt(masterPassword: master);

    expect(after.format, VaultContainerFormat.v3);
    expect(await file.readAsBytes(), isNot(beforeBytes));
    after.key.dispose();
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
    expect(afterState.header!.formatVersion, VaultConstants.v3FormatVersion);
    expect(afterState.header!.saltB64, isNot(beforeHeader.saltB64));
    expect(reopened.header.magic, VaultConstants.magic);
    expect(reopened.header.formatVersion, VaultConstants.v3FormatVersion);
    expect(reopened.header.saltB64, afterState.header!.saltB64);
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

  test('VaultDocumentService is exposed through a provider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(vaultDocumentServiceProvider),
      isA<VaultDocumentService>(),
    );
  });

  test('VaultState starts and clears in the v3 format', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(vaultProvider).format, VaultContainerFormat.v3);

    container.read(vaultProvider.notifier).clear();

    expect(container.read(vaultProvider).format, VaultContainerFormat.v3);
  });

  test('VaultDocumentLimits rejects total document limit overflow', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'vault_doc_limit_test',
    );
    final file = File('${tempDir.path}/tiny.txt');
    await file.writeAsBytes([1, 2, 3], flush: true);

    await expectLater(
      VaultDocumentLimits.validateFile(
        file: file,
        currentTotalBytes: VaultDocumentLimits.maxTotalDocumentBytes,
      ),
      throwsA(isA<VaultDocumentLimitException>()),
    );
  });

  test('createVault creates canonical v3 vault', () async {
    if (!sodiumReady) return;
    final tempDir = await Directory.systemTemp.createTemp(
      'vault_create_v3_test',
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
    addTearDown(container.dispose);

    const master = 'DocumentStrongPassword12!';
    await container
        .read(vaultServiceProvider)
        .createVault(masterPassword: master);
    final opened = await container
        .read(vaultRepositoryProvider)
        .loadAndDecrypt(masterPassword: master);

    expect(opened.format, VaultContainerFormat.v3);
    expect(opened.header.formatVersion, VaultConstants.v3FormatVersion);
    expect(opened.data.version, VaultConstants.v3DataVersion);
    expect(opened.data.documents, isEmpty);
    opened.key.dispose();
  });

  test(
    'unsupported non-v3 vaults are rejected without rewriting file',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'vault_unsupported_rejected_test',
      );
      final fileService = VaultFileService(baseDir: tempDir);
      const master = 'UnsupportedStrongPassword12!';
      await _writeUnsupportedNonV3Vault(fileService: fileService);
      final vaultFile = await fileService.defaultVaultFile();
      final beforeBytes = await vaultFile.readAsBytes();
      final container = ProviderContainer(
        overrides: [
          vaultRepositoryProvider.overrideWith(
            (ref) => VaultRepository(
              ref: ref,
              cryptoService: CryptoService(),
              fileService: fileService,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(vaultRepositoryProvider)
            .loadAndDecrypt(masterPassword: master),
        throwsA(isA<VaultLoadException>()),
      );
      expect(await vaultFile.readAsBytes(), beforeBytes);
    },
  );

  test('Backup validation rejects unsupported non-v3 vault files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'vault_unsupported_backup_rejected_test',
    );
    final fileService = VaultFileService(baseDir: tempDir);
    await _writeUnsupportedNonV3Vault(fileService: fileService);

    final vaultFile = await fileService.defaultVaultFile();
    final validation = await fileService.validateVaultFileStructure(
      vaultFile.path,
    );

    expect(validation.isValid, isFalse);
  });

  test('Unknown vault format fails with a clear PT-PT message', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'vault_unknown_format_test',
    );
    final fileService = VaultFileService(baseDir: tempDir);
    final container = ProviderContainer(
      overrides: [
        vaultRepositoryProvider.overrideWith(
          (ref) => VaultRepository(
            ref: ref,
            cryptoService: CryptoService(),
            fileService: fileService,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final header = VaultHeader(
      magic: VaultConstants.magic,
      formatVersion: 99,
      cipherId: VaultConstants.cipherId,
      kdf: VaultConstants.kdfId,
      memLimit: 1,
      opsLimit: 1,
      parallelism: 1,
      saltB64: base64Encode([1, 2, 3, 4]),
    );
    final headerBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(header.toJson())),
    );
    await fileService.writeVault(
      target: await fileService.defaultVaultFile(),
      headerBytes: headerBytes,
      cipherBytes: Uint8List.fromList([1, 2, 3]),
    );

    await expectLater(
      container
          .read(vaultRepositoryProvider)
          .loadAndDecrypt(masterPassword: 'qualquer-palavra-passe'),
      throwsA(
        isA<VaultLoadException>().having(
          (error) => error.message,
          'message',
          'Cofre corrompido ou versão não suportada.',
        ),
      ),
    );
  });

  test('Vault v3 footer uses fixed 64 byte encoding', () {
    final nonce = Uint8List.fromList(List<int>.generate(24, (index) => index));
    final footer = VaultFooterV3(
      manifestOffset: 123,
      manifestEncryptedSize: 456,
      manifestPlainSize: 440,
      manifestNonce: nonce,
    );

    final encoded = footer.toBytes();
    final parsed = VaultFooterV3.fromBytes(encoded);

    expect(encoded, hasLength(VaultFooterV3.length));
    expect(parsed.manifestOffset, footer.manifestOffset);
    expect(parsed.manifestEncryptedSize, footer.manifestEncryptedSize);
    expect(parsed.manifestPlainSize, footer.manifestPlainSize);
    expect(parsed.manifestNonce, footer.manifestNonce);
  });

  test('Vault v3 rejects oversized document without rewriting vault', () async {
    if (!sodiumReady) return;
    final tempDir = await Directory.systemTemp.createTemp(
      'vault_v3_doc_oversized_test',
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
    addTearDown(container.dispose);

    const master = 'DocumentStrongPassword12!';
    await container
        .read(vaultServiceProvider)
        .createVault(masterPassword: master);
    final repo = container.read(vaultRepositoryProvider);
    final initial = await repo.loadAndDecrypt(masterPassword: master);
    container
        .read(vaultProvider.notifier)
        .setVault(
          initial.header,
          initial.data,
          initial.key,
          fileName: initial.fileName,
          format: initial.format,
          headerBytes: initial.headerBytes,
        );

    final vaultFile = await fileService.defaultVaultFile();
    final beforeBytes = await vaultFile.readAsBytes();
    final oversized = File('${tempDir.path}/too-large.bin');
    final raf = await oversized.open(mode: FileMode.write);
    await raf.truncate(VaultDocumentLimits.maxDocumentBytes + 1);
    await raf.close();

    await expectLater(
      container
          .read(vaultProvider.notifier)
          .addDocumentFromFile(oversized.path),
      throwsA(
        isA<VaultDocumentLimitException>().having(
          (error) => error.message,
          'message',
          'Ficheiro demasiado grande.',
        ),
      ),
    );

    expect(container.read(vaultProvider).format, VaultContainerFormat.v3);
    expect(await vaultFile.readAsBytes(), beforeBytes);
  });

  test(
    'Adding a document to a v3 vault updates state and persists metadata',
    () async {
      if (!sodiumReady) return;
      final tempDir = await Directory.systemTemp.createTemp(
        'vault_v3_add_document_updates_state_test',
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
      addTearDown(container.dispose);

      const master = 'DocumentStrongPassword12!';
      await container
          .read(vaultServiceProvider)
          .createVault(masterPassword: master);
      final repo = container.read(vaultRepositoryProvider);
      final initial = await repo.loadAndDecrypt(masterPassword: master);
      container
          .read(vaultProvider.notifier)
          .setVault(
            initial.header,
            initial.data,
            initial.key,
            fileName: initial.fileName,
            format: initial.format,
            headerBytes: initial.headerBytes,
          );
      final documentCounts = <int>[];
      final subscription = container.listen<VaultState>(
        vaultProvider,
        (_, next) => documentCounts.add(next.data?.documents.length ?? 0),
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final entryId = await container
          .read(vaultProvider.notifier)
          .addEntry(
            title: 'Banco',
            username: 'cliente',
            password: 'EntryPassword12!',
            notes: 'nota',
          );

      final source = File('${tempDir.path}/contrato.pdf');
      await source.writeAsBytes([1, 2, 3, 4, 5], flush: true);

      final documentId = await container
          .read(vaultProvider.notifier)
          .addDocumentFromFile(source.path);
      final stateAfterAdd = container.read(vaultProvider);

      expect(stateAfterAdd.format, VaultContainerFormat.v3);
      expect(
        stateAfterAdd.header!.formatVersion,
        VaultConstants.v3FormatVersion,
      );
      expect(stateAfterAdd.data!.entries, hasLength(1));
      expect(stateAfterAdd.data!.entries.single.id, entryId);
      expect(stateAfterAdd.data!.entries.single.title, 'Banco');
      expect(stateAfterAdd.data!.documents, hasLength(1));
      expect(stateAfterAdd.data!.documents.single.id, documentId);
      expect(documentCounts, contains(1));

      final reopened = await repo.loadAndDecrypt(masterPassword: master);
      expect(reopened.format, VaultContainerFormat.v3);
      expect(reopened.data.entries.single.id, entryId);
      expect(reopened.data.entries.single.title, 'Banco');
      expect(reopened.data.documents.single.fileName, 'contrato.pdf');
      reopened.key.dispose();
    },
  );

  test('Vault v3 stores and exports documents by chunks', () async {
    if (!sodiumReady) return;
    final tempDir = await Directory.systemTemp.createTemp('vault_v3_doc_test');
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
    const master = 'DocumentStrongPassword12!';
    await container
        .read(vaultServiceProvider)
        .createVault(masterPassword: master);
    final repo = container.read(vaultRepositoryProvider);
    final initial = await repo.loadAndDecrypt(masterPassword: master);
    container
        .read(vaultProvider.notifier)
        .setVault(
          initial.header,
          initial.data,
          initial.key,
          fileName: initial.fileName,
          format: initial.format,
        );

    final plain = Uint8List.fromList(
      List<int>.generate(
        VaultDocumentLimits.defaultChunkSize + 73,
        (index) => index % 251,
      ),
    );
    final source = File('${tempDir.path}/contrato.pdf');
    await source.writeAsBytes(plain, flush: true);

    final documentId = await container
        .read(vaultProvider.notifier)
        .addDocumentFromFile(source.path);
    final afterAdd = container.read(vaultProvider);

    expect(afterAdd.header!.formatVersion, VaultConstants.v3FormatVersion);
    expect(afterAdd.format, VaultContainerFormat.v3);
    expect(afterAdd.data!.documents, hasLength(1));
    expect(afterAdd.data!.activeDocuments, hasLength(1));
    expect(afterAdd.data!.deletedDocuments, isEmpty);
    expect(afterAdd.data!.documents.single.id, documentId);
    expect(afterAdd.data!.documents.single.chunks.length, greaterThan(1));

    await container
        .read(vaultProvider.notifier)
        .addEntry(
          title: 'Banco',
          username: 'cliente',
          password: 'EntryPassword12!',
          notes: 'nota',
        );
    expect(container.read(vaultProvider).data!.documents, hasLength(1));

    final exported = File('${tempDir.path}/exported.pdf');
    await container
        .read(vaultProvider.notifier)
        .exportDocument(documentId, exported.path);
    expect(await exported.readAsBytes(), plain);

    final reopened = await repo.loadAndDecrypt(masterPassword: master);
    expect(reopened.format, VaultContainerFormat.v3);
    expect(reopened.data.documents.single.fileName, 'contrato.pdf');
    expect(reopened.data.documents.single.sizeBytes, plain.length);
    reopened.key.dispose();

    await expectLater(
      repo.loadAndDecrypt(masterPassword: 'password-errada'),
      throwsA(isA<VaultAuthException>()),
    );

    await container.read(vaultProvider.notifier).deleteDocument(documentId);
    final afterDelete = container.read(vaultProvider);
    expect(afterDelete.data!.documents, hasLength(1));
    expect(afterDelete.data!.activeDocuments, isEmpty);
    expect(afterDelete.data!.deletedDocuments, hasLength(1));
    expect(afterDelete.data!.deletedDocuments.single.deletedAt, isNotNull);
    final reopenedAfterDelete = await repo.loadAndDecrypt(
      masterPassword: master,
    );
    expect(reopenedAfterDelete.format, VaultContainerFormat.v3);
    expect(reopenedAfterDelete.data.activeDocuments, isEmpty);
    expect(reopenedAfterDelete.data.deletedDocuments.single.id, documentId);
    reopenedAfterDelete.key.dispose();

    await container.read(vaultProvider.notifier).restoreDocument(documentId);
    final afterRestore = container.read(vaultProvider);
    expect(afterRestore.data!.activeDocuments.single.id, documentId);
    expect(afterRestore.data!.deletedDocuments, isEmpty);

    await container.read(vaultProvider.notifier).deleteDocument(documentId);
    await container.read(vaultProvider.notifier).permanentlyDeleteDocuments({
      documentId,
    });
    expect(container.read(vaultProvider).data!.documents, isEmpty);
  });

  test('Vault v3 previews small text documents without exporting', () async {
    if (!sodiumReady) return;
    final tempDir = await Directory.systemTemp.createTemp(
      'vault_v3_doc_preview_test',
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
    const master = 'PreviewStrongPassword12!';
    await container
        .read(vaultServiceProvider)
        .createVault(masterPassword: master);
    final initial = await container
        .read(vaultRepositoryProvider)
        .loadAndDecrypt(masterPassword: master);
    container
        .read(vaultProvider.notifier)
        .setVault(
          initial.header,
          initial.data,
          initial.key,
          fileName: initial.fileName,
          format: initial.format,
        );

    const contents = 'Contrato interno\nLinha confidencial';
    final source = File('${tempDir.path}/contrato.txt');
    await source.writeAsString(contents, flush: true);

    final documentId = await container
        .read(vaultProvider.notifier)
        .addDocumentFromFile(source.path);
    final preview = await container
        .read(vaultProvider.notifier)
        .previewDocument(documentId);

    expect(preview.kind, VaultDocumentPreviewKind.text);
    expect(preview.text, contents);
    expect(preview.bytes, isNull);
  });

  test('Vault v3 previews PDF documents as in-app renderable bytes', () async {
    if (!sodiumReady) return;
    final fixture = await _createUnlockedVaultFixture(
      sodium,
      tempPrefix: 'vault_v3_pdf_preview_test',
      masterPassword: 'PdfPreviewStrongPassword12!',
    );
    const pdfBytes = [
      0x25,
      0x50,
      0x44,
      0x46,
      0x2D,
      0x31,
      0x2E,
      0x34,
      0x0A,
      0x25,
      0x45,
      0x4F,
      0x46,
    ];

    final documentId = await _addDocumentBytes(
      fixture,
      fileName: 'livro_de_musica.pdf',
      bytes: pdfBytes,
    );
    final preview = await fixture.container
        .read(vaultProvider.notifier)
        .previewDocument(documentId);

    expect(preview.kind, VaultDocumentPreviewKind.pdf);
    expect(preview.bytes, isNull);
    expect(preview.text, isNull);
    expect(preview.temporaryFilePath, isNotNull);
    final previewFile = File(preview.temporaryFilePath!);
    addTearDown(() async {
      if (await previewFile.exists()) {
        await previewFile.delete();
      }
    });
    expect(await previewFile.readAsBytes(), pdfBytes);
  });

  test('Vault v3 extracts DOCX text for in-app preview', () async {
    if (!sodiumReady) return;
    final fixture = await _createUnlockedVaultFixture(
      sodium,
      tempPrefix: 'vault_v3_docx_preview_test',
      masterPassword: 'DocxPreviewStrongPassword12!',
    );

    final documentId = await _addDocumentBytes(
      fixture,
      fileName: 'notas.docx',
      bytes: _docxBytes('Primeira linha', 'Segunda linha confidencial'),
    );
    final preview = await fixture.container
        .read(vaultProvider.notifier)
        .previewDocument(documentId);

    expect(preview.kind, VaultDocumentPreviewKind.text);
    expect(preview.text, contains('Primeira linha'));
    expect(preview.text, contains('Segunda linha confidencial'));
    expect(preview.bytes, isNull);
  });

  test('Vault v3 detects tampered document chunks during export', () async {
    if (!sodiumReady) return;
    final tempDir = await Directory.systemTemp.createTemp(
      'vault_v3_doc_tamper_test',
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
    const master = 'DocumentStrongPassword12!';
    await container
        .read(vaultServiceProvider)
        .createVault(masterPassword: master);
    final repo = container.read(vaultRepositoryProvider);
    final initial = await repo.loadAndDecrypt(masterPassword: master);
    container
        .read(vaultProvider.notifier)
        .setVault(
          initial.header,
          initial.data,
          initial.key,
          fileName: initial.fileName,
          format: initial.format,
        );

    final source = File('${tempDir.path}/segredo.bin');
    await source.writeAsBytes(
      Uint8List.fromList(List<int>.generate(4096, (index) => index % 199)),
      flush: true,
    );
    final documentId = await container
        .read(vaultProvider.notifier)
        .addDocumentFromFile(source.path);
    final document = container.read(vaultProvider).data!.documents.single;
    final vaultFile = await fileService.defaultVaultFile();
    final vaultBytes = await vaultFile.readAsBytes();
    vaultBytes[document.chunks.single.offset] =
        vaultBytes[document.chunks.single.offset] ^ 0xFF;
    await vaultFile.writeAsBytes(vaultBytes, flush: true);

    await expectLater(
      container
          .read(vaultProvider.notifier)
          .exportDocument(documentId, '${tempDir.path}/tampered-export.bin'),
      throwsA(isA<VaultAuthException>()),
    );
  });

  test('Vault v3 detects tampered encrypted manifest during open', () async {
    if (!sodiumReady) return;
    final fixture = await _createUnlockedVaultFixture(
      sodium,
      tempPrefix: 'vault_v3_manifest_tamper_test',
    );
    await _addDocumentBytes(
      fixture,
      fileName: 'manifesto.pdf',
      bytes: Uint8List.fromList(List<int>.generate(4096, (index) => index)),
    );

    final vaultFile = await fixture.fileService.defaultVaultFile();
    final vaultBytes = await vaultFile.readAsBytes();
    final footer = _footerFromVaultBytes(vaultBytes);
    vaultBytes[footer.manifestOffset] =
        vaultBytes[footer.manifestOffset] ^ 0xFF;
    await vaultFile.writeAsBytes(vaultBytes, flush: true);

    await expectLater(
      fixture.repo.loadAndDecrypt(masterPassword: fixture.masterPassword),
      throwsA(isA<VaultAuthException>()),
    );
  });

  test('Vault v3 detects tampered footer during open', () async {
    if (!sodiumReady) return;
    final fixture = await _createUnlockedVaultFixture(
      sodium,
      tempPrefix: 'vault_v3_footer_tamper_test',
    );
    await _addDocumentBytes(
      fixture,
      fileName: 'footer.pdf',
      bytes: Uint8List.fromList(List<int>.generate(4096, (index) => index)),
    );

    final vaultFile = await fixture.fileService.defaultVaultFile();
    final vaultBytes = await vaultFile.readAsBytes();
    vaultBytes[vaultBytes.length - 1] = vaultBytes.last ^ 0xFF;
    await vaultFile.writeAsBytes(vaultBytes, flush: true);

    await expectLater(
      fixture.repo.loadAndDecrypt(masterPassword: fixture.masterPassword),
      throwsA(isA<VaultAuthException>()),
    );
  });

  test('Vault v3 rekey preserves and re-encrypts document chunks', () async {
    if (!sodiumReady) return;
    final fixture = await _createUnlockedVaultFixture(
      sodium,
      tempPrefix: 'vault_v3_rekey_documents_test',
    );
    final plain = Uint8List.fromList(
      List<int>.generate(
        VaultDocumentLimits.defaultChunkSize + 257,
        (index) => index % 241,
      ),
    );
    final documentId = await _addDocumentBytes(
      fixture,
      fileName: 'rekey.pdf',
      bytes: plain,
    );
    final beforeState = fixture.container.read(vaultProvider);
    final beforeChunkNonces = beforeState.data!.documents.single.chunks
        .map((chunk) => chunk.nonceB64)
        .toList();
    final beforeVaultBytes =
        await (await fixture.fileService.defaultVaultFile()).readAsBytes();

    const nextMaster = 'NewDocumentStrongPassword34!';
    await fixture.container
        .read(vaultProvider.notifier)
        .changeMasterPassword(
          currentPassword: fixture.masterPassword,
          newPassword: nextMaster,
        );

    await expectLater(
      fixture.repo.loadAndDecrypt(masterPassword: fixture.masterPassword),
      throwsA(isA<VaultAuthException>()),
    );
    final afterState = fixture.container.read(vaultProvider);
    expect(afterState.format, VaultContainerFormat.v3);
    final afterChunkNonces = afterState.data!.documents.single.chunks
        .map((chunk) => chunk.nonceB64)
        .toList();
    expect(afterChunkNonces, isNot(beforeChunkNonces));
    final afterVaultBytes = await (await fixture.fileService.defaultVaultFile())
        .readAsBytes();
    expect(_bytesEqual(afterVaultBytes, beforeVaultBytes), isFalse);

    final exported = File('${fixture.tempDir.path}/rekey-export.pdf');
    await fixture.container
        .read(vaultProvider.notifier)
        .exportDocument(documentId, exported.path);
    expect(await exported.readAsBytes(), plain);

    final reopened = await fixture.repo.loadAndDecrypt(
      masterPassword: nextMaster,
    );
    expect(reopened.format, VaultContainerFormat.v3);
    expect(reopened.data.documents.single.id, documentId);
    reopened.key.dispose();
  });

  test('Vault v3 can store multiple chunked documents', () async {
    if (!sodiumReady) return;
    final fixture = await _createUnlockedVaultFixture(
      sodium,
      tempPrefix: 'vault_v3_multiple_documents_test',
    );
    final first = Uint8List.fromList(
      List<int>.generate(
        VaultDocumentLimits.defaultChunkSize + 11,
        (index) => index % 211,
      ),
    );
    final second = Uint8List.fromList(
      List<int>.generate(
        VaultDocumentLimits.defaultChunkSize + 29,
        (index) => index % 197,
      ),
    );

    final firstId = await _addDocumentBytes(
      fixture,
      fileName: 'primeiro.bin',
      bytes: first,
    );
    final secondId = await _addDocumentBytes(
      fixture,
      fileName: 'segundo.bin',
      bytes: second,
    );

    final documents = fixture.container.read(vaultProvider).data!.documents;
    expect(documents, hasLength(2));
    expect(
      documents.map((document) => document.id),
      containsAll([firstId, secondId]),
    );
    expect(
      documents.every(
        (document) =>
            document.chunks.length > 1 &&
            document.chunks.every(
              (chunk) =>
                  chunk.plainSize <= VaultDocumentLimits.defaultChunkSize,
            ),
      ),
      isTrue,
    );

    final exported = File('${fixture.tempDir.path}/segundo-export.bin');
    await fixture.container
        .read(vaultProvider.notifier)
        .exportDocument(secondId, exported.path);
    expect(await exported.readAsBytes(), second);
  });

  test(
    'Vault file replacement restores backup if temp promotion fails',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'vault_replace_rollback_test',
      );
      final fileService = VaultFileService(baseDir: tempDir);
      final target = await fileService.defaultVaultFile();
      final originalBytes = Uint8List.fromList([7, 8, 9, 10]);
      await target.writeAsBytes(originalBytes, flush: true);
      final missingTmp = File('${target.path}.missing.tmp');
      if (await missingTmp.exists()) {
        await missingTmp.delete();
      }

      await expectLater(
        fileService.replaceVaultWithTemp(target: target, tmp: missingTmp),
        throwsA(isA<FileSystemException>()),
      );

      expect(await target.exists(), isTrue);
      expect(await target.readAsBytes(), originalBytes);
      expect(await File('${target.path}.bak').exists(), isFalse);
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

  bool _shouldFail() {
    if (!failNextWrite) return false;
    failNextWrite = false;
    return true;
  }

  @override
  Future<File> writeVault({
    required File target,
    required Uint8List headerBytes,
    required Uint8List cipherBytes,
  }) async {
    if (_shouldFail()) {
      throw Exception('simulated write failure');
    }
    return super.writeVault(
      target: target,
      headerBytes: headerBytes,
      cipherBytes: cipherBytes,
    );
  }

  @override
  Future<void> replaceVaultWithTemp({
    required File target,
    required File tmp,
  }) async {
    if (_shouldFail()) {
      throw Exception('simulated write failure');
    }
    return super.replaceVaultWithTemp(target: target, tmp: tmp);
  }
}

class _VaultDocumentFixture {
  const _VaultDocumentFixture({
    required this.tempDir,
    required this.fileService,
    required this.container,
    required this.repo,
    required this.masterPassword,
  });

  final Directory tempDir;
  final VaultFileService fileService;
  final ProviderContainer container;
  final VaultRepository repo;
  final String masterPassword;
}

Future<_VaultDocumentFixture> _createUnlockedVaultFixture(
  SodiumSumo sodium, {
  required String tempPrefix,
  String masterPassword = 'DocumentStrongPassword12!',
}) async {
  final tempDir = await Directory.systemTemp.createTemp(tempPrefix);
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
  addTearDown(() {
    container.read(vaultProvider.notifier).clear();
    container.dispose();
  });

  await container
      .read(vaultServiceProvider)
      .createVault(masterPassword: masterPassword);
  final repo = container.read(vaultRepositoryProvider);
  final initial = await repo.loadAndDecrypt(masterPassword: masterPassword);
  container
      .read(vaultProvider.notifier)
      .setVault(
        initial.header,
        initial.data,
        initial.key,
        fileName: initial.fileName,
        format: initial.format,
        headerBytes: initial.headerBytes,
      );

  return _VaultDocumentFixture(
    tempDir: tempDir,
    fileService: fileService,
    container: container,
    repo: repo,
    masterPassword: masterPassword,
  );
}

Future<String> _addDocumentBytes(
  _VaultDocumentFixture fixture, {
  required String fileName,
  required List<int> bytes,
}) async {
  final source = File('${fixture.tempDir.path}/$fileName');
  await source.writeAsBytes(bytes, flush: true);
  return fixture.container
      .read(vaultProvider.notifier)
      .addDocumentFromFile(source.path);
}

List<int> _docxBytes(String firstLine, String secondLine) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        '[Content_Types].xml',
        '<?xml version="1.0" encoding="UTF-8"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '</Types>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'word/document.xml',
        '<?xml version="1.0" encoding="UTF-8"?>'
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
            '<w:body>'
            '<w:p><w:r><w:t>$firstLine</w:t></w:r></w:p>'
            '<w:p><w:r><w:t>$secondLine</w:t></w:r></w:p>'
            '</w:body>'
            '</w:document>',
      ),
    );
  return ZipEncoder().encodeBytes(archive);
}

VaultFooterV3 _footerFromVaultBytes(List<int> vaultBytes) {
  return VaultFooterV3.fromBytes(
    Uint8List.fromList(
      vaultBytes.sublist(vaultBytes.length - VaultFooterV3.length),
    ),
  );
}

Future<void> _writeUnsupportedNonV3Vault({
  required VaultFileService fileService,
  int formatVersion = 99,
}) async {
  final header = VaultHeader(
    magic: VaultConstants.magic,
    formatVersion: formatVersion,
    cipherId: VaultConstants.cipherId,
    kdf: VaultConstants.kdfId,
    memLimit: 1,
    opsLimit: 1,
    parallelism: 1,
    saltB64: base64Encode([1, 2, 3, 4]),
  );
  final headerBytes = Uint8List.fromList(
    utf8.encode(jsonEncode(header.toJson())),
  );
  await fileService.writeVault(
    target: await fileService.defaultVaultFile(),
    headerBytes: headerBytes,
    cipherBytes: Uint8List.fromList([1, 2, 3]),
  );
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

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
