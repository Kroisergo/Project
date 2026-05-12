import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodium/sodium_sumo.dart';

import 'package:encryvault/app.dart';
import 'package:encryvault/config/theme.dart';
import 'package:encryvault/config/theme/design_tokens.dart';
import 'package:encryvault/models/app_design_mode.dart';
import 'package:encryvault/models/vault_container_format.dart';
import 'package:encryvault/models/vault_data.dart';
import 'package:encryvault/models/vault_document.dart';
import 'package:encryvault/models/vault_header.dart';
import 'package:encryvault/pages/vault_documents/vault_documents_page.dart';
import 'package:encryvault/pages/vault_documents/widgets/vault_document_card.dart';
import 'package:encryvault/pages/vault_documents/widgets/vault_documents_card_actions.dart';
import 'package:encryvault/pages/splash/splash_page.dart';
import 'package:encryvault/pages/welcome/import_vault_page.dart';
import 'package:encryvault/pages/welcome/welcome_page.dart';
import 'package:encryvault/pages/vault_entry_edit/vault_entry_edit_page.dart';
import 'package:encryvault/pages/vault_home/vault_home_page.dart';
import 'package:encryvault/pages/vault_settings/vault_settings_page.dart';
import 'package:encryvault/pages/vault_trash/vault_trash_page.dart';
import 'package:encryvault/pages/unlock/unlock_page.dart';
import 'package:encryvault/services/bootstrap/bootstrap_service.dart';
import 'package:encryvault/pages/vault_settings/widgets/appearance_settings_section.dart';
import 'package:encryvault/services/storage/preferences_service.dart';
import 'package:encryvault/services/theme/app_design_controller.dart';
import 'package:encryvault/services/vault/auto_lock_controller.dart';
import 'package:encryvault/services/vault/vault_document_service.dart';
import 'package:encryvault/services/vault/vault_repository.dart';
import 'package:encryvault/services/vault/vault_state.dart';
import 'package:encryvault/utils/constants.dart';
import 'package:encryvault/widgets/vault_operation_loading_overlay.dart';
import 'package:encryvault/widgets/theme_mode_card_selector.dart';

void main() {
  group('AppDesignMode', () {
    test('uses modern as the fallback preference', () {
      expect(appDesignModeFromPreference(null), AppDesignMode.modern);
      expect(appDesignModeFromPreference('unknown'), AppDesignMode.modern);
    });

    test('exposes PT-PT labels and stable preference values', () {
      expect(AppDesignMode.modern.label, 'Moderno');
      expect(AppDesignMode.modern.preferenceValue, 'modern');
      expect(AppDesignMode.classic.label, 'Clássico');
      expect(AppDesignMode.classic.preferenceValue, 'classic');
    });
  });

  group('PreferencesService appearance settings', () {
    test('defaults to modern design and system theme', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = PreferencesService();

      expect(await preferences.getAppDesignMode(), AppDesignMode.modern);
      expect(await preferences.getThemeMode(), ThemeMode.system);
    });

    test('persists design mode separately from theme mode', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = PreferencesService();

      await preferences.setAppDesignMode(AppDesignMode.classic);
      await preferences.setThemeMode(ThemeMode.dark);

      expect(await preferences.getAppDesignMode(), AppDesignMode.classic);
      expect(await preferences.getThemeMode(), ThemeMode.dark);
    });
  });

  group('AppTheme appearance tokens', () {
    test('attaches EncryVaultTheme to every design and brightness', () {
      final themes = [
        AppTheme.light(AppDesignMode.modern),
        AppTheme.dark(AppDesignMode.modern),
        AppTheme.light(AppDesignMode.classic),
        AppTheme.dark(AppDesignMode.classic),
      ];

      for (final theme in themes) {
        expect(theme.extension<EncryVaultTheme>(), isNotNull);
      }
    });

    test('keeps modern and classic visually distinct', () {
      final modern = AppTheme.dark(
        AppDesignMode.modern,
      ).extension<EncryVaultTheme>()!;
      final classic = AppTheme.dark(
        AppDesignMode.classic,
      ).extension<EncryVaultTheme>()!;

      expect(modern.designMode, AppDesignMode.modern);
      expect(classic.designMode, AppDesignMode.classic);
      expect(modern.cardRadius, isNot(classic.cardRadius));
      expect(modern.cardElevation, isNot(classic.cardElevation));
      expect(modern.usesSoftGradient, isTrue);
      expect(classic.usesSoftGradient, isFalse);
    });

    test('keeps light and dark visually distinct', () {
      final light = AppTheme.light(
        AppDesignMode.modern,
      ).extension<EncryVaultTheme>()!;
      final dark = AppTheme.dark(
        AppDesignMode.modern,
      ).extension<EncryVaultTheme>()!;

      expect(light.isDark, isFalse);
      expect(dark.isDark, isTrue);
      expect(light.background, isNot(dark.background));
      expect(light.textPrimary, isNot(dark.textPrimary));
    });
  });

  group('AppearanceSettingsSection', () {
    test('uses cards for the main modern settings categories', () {
      expect(usesModernSettingsCategoryCards('Segurança'), isTrue);
      expect(usesModernSettingsCategoryCards('Dados'), isTrue);
      expect(usesModernSettingsCategoryCards('Aparência'), isTrue);
      expect(usesModernSettingsCategoryCards('Lixo'), isTrue);
      expect(usesModernSettingsCategoryCards('Links rápidos'), isTrue);
      expect(usesModernSettingsCategoryCards('Auditoria / Saúde'), isFalse);
      expect(usesModernSettingsCategoryCards('Sessão'), isFalse);
      expect(usesModernQuickLinksSettingsCards(AppDesignMode.modern), isTrue);
      expect(usesModernQuickLinksSettingsCards(AppDesignMode.classic), isFalse);
      expect(usesModernQuickLinkMenu(AppDesignMode.modern), isTrue);
      expect(usesModernQuickLinkMenu(AppDesignMode.classic), isFalse);
    });

    test('uses card entries on the trash page only in modern design', () {
      expect(usesModernTrashEntryCards(AppDesignMode.modern), isTrue);
      expect(usesModernTrashEntryCards(AppDesignMode.classic), isFalse);
    });

    test('uses modern cards for health details, filters and categories', () {
      expect(
        usesModernPasswordHealthDetailsCards(AppDesignMode.modern),
        isTrue,
      );
      expect(
        usesModernPasswordHealthDetailsCards(AppDesignMode.classic),
        isFalse,
      );
      expect(usesModernVaultFilterSurfaces(AppDesignMode.modern), isTrue);
      expect(usesModernVaultFilterSurfaces(AppDesignMode.classic), isFalse);
      expect(usesModernEntryCategoryCards(AppDesignMode.modern), isTrue);
      expect(usesModernEntryCategoryCards(AppDesignMode.classic), isFalse);
      expect(usesModernPreVaultThemeCards(AppDesignMode.modern), isTrue);
      expect(usesModernPreVaultThemeCards(AppDesignMode.classic), isFalse);
      expect(usesModernThemeModeCards(AppDesignMode.modern), isTrue);
      expect(usesModernThemeModeCards(AppDesignMode.classic), isFalse);
    });

    test('uses distinct operation loading style for modern and classic', () {
      expect(usesModernVaultLoadingStyle(AppDesignMode.modern), isTrue);
      expect(usesModernVaultLoadingStyle(AppDesignMode.classic), isFalse);
    });

    testWidgets('shows design and theme choices in PT-PT', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(AppDesignMode.modern),
            home: const Scaffold(body: AppearanceSettingsSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Design'), findsOneWidget);
      expect(find.text('Moderno'), findsOneWidget);
      expect(find.text('Clássico'), findsOneWidget);
      expect(find.text('Tema'), findsOneWidget);
      expect(find.text('Sistema'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Escuro'), findsOneWidget);
    });

    testWidgets('EncryVaultApp starts with modern and system defaults', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(appDesignControllerProvider.future),
        AppDesignMode.modern,
      );

      await tester.pumpWidget(const ProviderScope(child: EncryVaultApp()));

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('Pre-vault navigation', () {
    test('starts on welcome after terms even when a vault exists', () {
      expect(
        startupRouteForBootstrap(
          const BootstrapResult(termsAccepted: true, hasVault: true),
        ),
        WelcomePage.routePath,
      );
    });

    test('create vault action is disabled when a vault already exists', () {
      expect(
        canCreateVaultFromWelcome(hasVault: false, loading: false),
        isTrue,
      );
      expect(
        canCreateVaultFromWelcome(hasVault: true, loading: false),
        isFalse,
      );
      expect(
        canCreateVaultFromWelcome(hasVault: false, loading: true),
        isFalse,
      );
    });
  });

  group('Vault documents UI', () {
    testWidgets('page shows core PT-PT labels', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark(AppDesignMode.modern),
            home: const VaultDocumentsPage(),
          ),
        ),
      );

      expect(find.text('Documentos sigilosos'), findsWidgets);
      expect(find.text('Adicionar documento'), findsWidgets);
      expect(
        find.textContaining(
          'Este documento ficará guardado dentro do cofre cifrado.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ativar suporte a documentos?'), findsNothing);
      expect(
        find.textContaining('formato v3', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('document card shows metadata and actions', (tester) async {
      final document = VaultDocumentMetadata(
        id: 'doc-1',
        fileName: 'contrato.pdf',
        extension: 'pdf',
        mimeType: 'application/pdf',
        sizeBytes: 2048,
        createdAt: DateTime.utc(2026, 5, 12),
        updatedAt: DateTime.utc(2026, 5, 12),
        chunkSize: 2 * 1024 * 1024,
        chunks: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(AppDesignMode.modern),
          home: Scaffold(
            body: VaultDocumentCard(
              document: document,
              onExport: () {},
              onDelete: () {},
              onDetails: () {},
            ),
          ),
        ),
      );

      expect(find.text('contrato.pdf'), findsOneWidget);
      expect(find.textContaining('.pdf  |'), findsOneWidget);
      expect(find.textContaining('2.0 KB'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<VaultDocumentAction>));
      await tester.pumpAndSettle();

      expect(find.text('Detalhes'), findsOneWidget);
      expect(find.text('Exportar documento'), findsOneWidget);
      expect(find.text('Eliminar documento'), findsOneWidget);
    });

    testWidgets('document cards remain usable with 20 documents', (
      tester,
    ) async {
      final documents = List<VaultDocumentMetadata>.generate(
        20,
        (index) => VaultDocumentMetadata(
          id: 'doc-$index',
          fileName: 'documento-$index.pdf',
          extension: 'pdf',
          mimeType: 'application/pdf',
          sizeBytes: (index + 1) * 1024 * 1024,
          createdAt: DateTime.utc(2026, 5, 12),
          updatedAt: DateTime.utc(2026, 5, 12),
          chunkSize: 2 * 1024 * 1024,
          chunks: const [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(AppDesignMode.modern),
          home: Scaffold(
            body: ListView.builder(
              itemCount: documents.length,
              itemBuilder: (context, index) => VaultDocumentCard(
                document: documents[index],
                onExport: () {},
                onDelete: () {},
                onDetails: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('documento-0.pdf'), findsOneWidget);
      await tester.fling(find.byType(ListView), const Offset(0, -900), 1200);
      await tester.pumpAndSettle();

      expect(find.textContaining('documento-'), findsWidgets);
      expect(find.byType(PopupMenuButton<VaultDocumentAction>), findsWidgets);
    });

    testWidgets('keeps auto-lock suspended until added document is visible', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({PrefsKeys.autoLockMinutes: 1});
      FilePicker? originalFilePicker;
      try {
        originalFilePicker = FilePicker.platform;
      } catch (_) {
        originalFilePicker = null;
      }
      final fakeFilePicker = _FakeFilePicker(
        pickResult: FilePickerResult([
          PlatformFile(
            name: 'contrato.pdf',
            path: 'C:\\temp\\contrato.pdf',
            size: 2048,
          ),
        ]),
      );
      FilePicker.platform = fakeFilePicker;
      addTearDown(() {
        final original = originalFilePicker;
        if (original != null) {
          FilePicker.platform = original;
        }
      });

      final documentService = _DelayedVaultDocumentService();
      final container = ProviderContainer(
        overrides: [
          vaultDocumentServiceProvider.overrideWithValue(documentService),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(vaultProvider.notifier)
          .setVault(
            _testV3Header(),
            VaultData(
              version: VaultConstants.v3DataVersion,
              updatedAt: DateTime.utc(2026, 5, 12),
              entries: const [],
              documents: const [],
            ),
            _FakeSecureKey(),
            fileName: VaultConstants.defaultVaultName,
            format: VaultContainerFormat.v3,
            headerBytes: Uint8List.fromList([1, 2, 3]),
          );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const VaultDocumentsPage(),
          ),
          GoRoute(
            path: UnlockPage.routePath,
            builder: (context, state) => const Text('unlock'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.dark(AppDesignMode.modern),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Adicionar documento'));
      await tester.pump();
      await documentService.addStarted.future;

      await tester.pump(const Duration(seconds: 61));

      expect(container.read(vaultProvider).isUnlocked, isTrue);
      expect(find.text('contrato.pdf'), findsOneWidget);

      documentService.completeAdd();
      await tester.pump();
      await tester.pump();

      expect(find.text('contrato.pdf'), findsOneWidget);

      await tester.pump(const Duration(seconds: 61));

      expect(container.read(vaultProvider).isUnlocked, isFalse);
    });
  });

  group('AutoLockController', () {
    testWidgets('locks on paused outside picker suspension', (tester) async {
      SharedPreferences.setMockInitialValues({});
      late AutoLockController controller;
      var locked = false;

      await tester.pumpWidget(
        ProviderScope(
          child: _AutoLockHarness(
            onController: (value) => controller = value,
            onLocked: () => locked = true,
          ),
        ),
      );
      await tester.pump();

      await controller.handleLifecycle(AppLifecycleState.paused);

      expect(locked, isTrue);
    });

    testWidgets('does not lock while picker lifecycle is suspended', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      late AutoLockController controller;
      var locked = false;

      await tester.pumpWidget(
        ProviderScope(
          child: _AutoLockHarness(
            onController: (value) => controller = value,
            onLocked: () => locked = true,
          ),
        ),
      );
      await tester.pump();

      await controller.runWithLifecycleLockSuspended(() async {
        await controller.handleLifecycle(AppLifecycleState.inactive);
        await controller.handleLifecycle(AppLifecycleState.paused);
      });

      expect(locked, isFalse);
      await controller.handleLifecycle(AppLifecycleState.paused);
      expect(locked, isTrue);
    });
  });
}

class _AutoLockHarness extends ConsumerStatefulWidget {
  const _AutoLockHarness({required this.onController, required this.onLocked});

  final ValueChanged<AutoLockController> onController;
  final VoidCallback onLocked;

  @override
  ConsumerState<_AutoLockHarness> createState() => _AutoLockHarnessState();
}

class _AutoLockHarnessState extends ConsumerState<_AutoLockHarness> {
  late final AutoLockController controller;

  @override
  void initState() {
    super.initState();
    controller = AutoLockController(ref: ref, onTimeout: widget.onLocked);
    widget.onController(controller);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _unlockVault();
    });
  }

  void _unlockVault() {
    ref
        .read(vaultProvider.notifier)
        .setVault(
          _testV3Header(),
          VaultData(
            version: VaultConstants.v3DataVersion,
            updatedAt: DateTime.utc(2026, 5, 12),
            entries: const [],
          ),
          _FakeSecureKey(),
          fileName: VaultConstants.defaultVaultName,
          format: VaultContainerFormat.v3,
          headerBytes: Uint8List.fromList([1, 2, 3]),
        );
  }

  @override
  void dispose() {
    controller.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

VaultHeader _testV3Header() {
  return const VaultHeader(
    magic: VaultConstants.magic,
    formatVersion: VaultConstants.v3FormatVersion,
    container: VaultConstants.v3ContainerId,
    cipherId: VaultConstants.cipherId,
    kdf: VaultConstants.kdfId,
    subkeyKdf: VaultConstants.v3SubkeyKdfId,
    memLimit: 1,
    opsLimit: 1,
    parallelism: 1,
    saltB64: 'AQIDBA==',
    vaultIdB64: 'AQIDBA==',
    defaultChunkSize: 2 * 1024 * 1024,
  );
}

class _FakeSecureKey extends Fake implements SecureKey {
  @override
  void dispose() {}
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker({this.pickResult});

  final FilePickerResult? pickResult;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return pickResult;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    return null;
  }
}

class _DelayedVaultDocumentService extends VaultDocumentService {
  _DelayedVaultDocumentService() : super(repository: _FakeVaultRepository());

  final Completer<void> addStarted = Completer<void>();
  final Completer<void> _completeAdd = Completer<void>();

  void completeAdd() {
    if (!_completeAdd.isCompleted) {
      _completeAdd.complete();
    }
  }

  @override
  Future<VaultDocumentServiceResult> addFromFileWithResult({
    required VaultState current,
    required String sourcePath,
    void Function(VaultDocumentMetadata document)? onPendingDocument,
  }) async {
    if (!addStarted.isCompleted) {
      addStarted.complete();
    }
    final now = DateTime.utc(2026, 5, 12, 12);
    final pendingDocument = VaultDocumentMetadata(
      id: 'doc-added',
      fileName: 'contrato.pdf',
      extension: 'pdf',
      mimeType: 'application/pdf',
      sizeBytes: 2048,
      createdAt: now,
      updatedAt: now,
      chunkSize: 2 * 1024 * 1024,
      chunks: const [],
    );
    onPendingDocument?.call(pendingDocument);
    await _completeAdd.future;
    return VaultDocumentServiceResult(
      header: current.header!,
      headerBytes: current.headerBytes ?? Uint8List.fromList([1, 2, 3]),
      data: current.data!.copyWith(
        updatedAt: now,
        documents: [pendingDocument],
      ),
      format: VaultContainerFormat.v3,
      fileName: current.fileName,
      documentId: pendingDocument.id,
    );
  }
}

class _FakeVaultRepository extends Fake implements VaultRepository {}
