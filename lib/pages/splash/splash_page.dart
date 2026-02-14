import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/bootstrap/bootstrap_service.dart';
import '../terms/terms_page.dart';
import '../unlock/unlock_page.dart';
import '../welcome/welcome_page.dart';

class SplashPage extends ConsumerWidget {
  static const routePath = '/';
  static const routeName = 'splash';

  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);

    ref.listen<AsyncValue<BootstrapResult>>(bootstrapProvider, (prev, next) {
      next.whenData((result) {
        final target = _nextRoute(result);
        if (!context.mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future.delayed(const Duration(milliseconds: 5000));
          if (!context.mounted) return;
          context.go(target);
        });
      });
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'EncryVault',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'A inicializar o cofre…',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            bootstrap.maybeWhen(
              loading: () => const CircularProgressIndicator(),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _nextRoute(BootstrapResult result) {
    if (!result.termsAccepted) {
      return TermsPage.routePath;
    }
    if (result.hasVault) {
      return UnlockPage.routePath;
    }
    return WelcomePage.routePath;
  }
}
