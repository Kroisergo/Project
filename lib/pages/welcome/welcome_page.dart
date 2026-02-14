import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../create_master/create_master_page.dart';
import '../unlock/unlock_page.dart';
import 'import_vault_page.dart';

class WelcomePage extends StatelessWidget {
  static const routePath = '/welcome';
  static const routeName = 'welcome';

  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EncryVault')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 16),
            Text(
              'Bem-vindo ao EncryVault',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gestor de passwords 100% offline num único cofre cifrado.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go(CreateMasterPage.routePath),
              child: const Text('Criar'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go(UnlockPage.routePath),
              child: const Text('Entrar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(ImportVaultPage.routePath),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Configurar (Importar)'),
            ),
          ],
        ),
      ),
    );
  }
}
