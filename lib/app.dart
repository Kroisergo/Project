import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'services/theme/theme_mode_controller.dart';
import 'widgets/app_security_effects.dart';

class EncryVaultApp extends ConsumerWidget {
  const EncryVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode =
        ref.watch(themeModeControllerProvider).valueOrNull ?? ThemeMode.system;
    return AppSecurityEffects(
      child: MaterialApp.router(
        title: 'EncryVault',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        builder: (context, child) => AppLifecycleLockGuard(
          router: router,
          child: child ?? const SizedBox.shrink(),
        ),
        debugShowCheckedModeBanner: false,
        locale: const Locale('pt', 'PT'),
        supportedLocales: const [Locale('pt', 'PT'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    );
  }
}
