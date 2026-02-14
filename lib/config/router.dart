import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pages/create_master/create_master_page.dart';
import '../pages/splash/splash_page.dart';
import '../pages/terms/terms_page.dart';
import '../pages/unlock/unlock_page.dart';
import '../pages/vault_entry_edit/vault_entry_edit_page.dart';
import '../pages/vault_entry_view/vault_entry_view_page.dart';
import '../pages/vault_home/vault_home_page.dart';
import '../pages/vault_settings/vault_settings_page.dart';
import '../pages/welcome/welcome_page.dart';
import '../pages/welcome/import_vault_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: SplashPage.routePath,
    routes: [
      GoRoute(
        path: SplashPage.routePath,
        name: SplashPage.routeName,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: TermsPage.routePath,
        name: TermsPage.routeName,
        builder: (context, state) => const TermsPage(),
      ),
      GoRoute(
        path: WelcomePage.routePath,
        name: WelcomePage.routeName,
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: ImportVaultPage.routePath,
        name: ImportVaultPage.routeName,
        builder: (context, state) => const ImportVaultPage(),
      ),
      GoRoute(
        path: CreateMasterPage.routePath,
        name: CreateMasterPage.routeName,
        builder: (context, state) => const CreateMasterPage(),
      ),
      GoRoute(
        path: UnlockPage.routePath,
        name: UnlockPage.routeName,
        builder: (context, state) => const UnlockPage(),
      ),
      GoRoute(
        path: VaultHomePage.routePath,
        name: VaultHomePage.routeName,
        builder: (context, state) => const VaultHomePage(),
        routes: [
          GoRoute(
            path: VaultEntryEditPage.newSubPath,
            name: '${VaultEntryEditPage.routeName}-new',
            builder: (context, state) => const VaultEntryEditPage(),
          ),
          GoRoute(
            path: VaultEntryViewPage.subPath,
            name: VaultEntryViewPage.routeName,
            builder: (context, state) => VaultEntryViewPage(
              entryId: state.pathParameters['entryId'] ?? '',
            ),
          ),
          GoRoute(
            path: VaultEntryEditPage.subPath,
            name: VaultEntryEditPage.routeName,
            builder: (context, state) => VaultEntryEditPage(
              entryId: state.pathParameters['entryId'],
            ),
          ),
          GoRoute(
            path: VaultSettingsPage.subPath,
            name: VaultSettingsPage.routeName,
            builder: (context, state) => const VaultSettingsPage(),
          ),
        ],
      ),
    ],
  );
});
