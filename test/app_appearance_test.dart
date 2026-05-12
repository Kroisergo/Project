import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:encryvault/app.dart';
import 'package:encryvault/config/theme.dart';
import 'package:encryvault/config/theme/design_tokens.dart';
import 'package:encryvault/models/app_design_mode.dart';
import 'package:encryvault/pages/splash/splash_page.dart';
import 'package:encryvault/pages/welcome/import_vault_page.dart';
import 'package:encryvault/pages/welcome/welcome_page.dart';
import 'package:encryvault/pages/vault_entry_edit/vault_entry_edit_page.dart';
import 'package:encryvault/pages/vault_home/vault_home_page.dart';
import 'package:encryvault/pages/vault_settings/vault_settings_page.dart';
import 'package:encryvault/pages/vault_trash/vault_trash_page.dart';
import 'package:encryvault/services/bootstrap/bootstrap_service.dart';
import 'package:encryvault/pages/vault_settings/widgets/appearance_settings_section.dart';
import 'package:encryvault/services/storage/preferences_service.dart';
import 'package:encryvault/services/theme/app_design_controller.dart';
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
}
