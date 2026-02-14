import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/storage/preferences_service.dart';
import '../../services/vault/vault_repository.dart';
import '../../services/vault/vault_state.dart';
import '../vault_home/vault_home_page.dart';
import 'unlock_form.dart';

class UnlockPage extends ConsumerWidget {
  static const routePath = '/unlock';
  static const routeName = 'unlock';

  const UnlockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> onUnlock(String master) async {
      final repo = ref.read(vaultRepositoryProvider);
      final notifier = ref.read(vaultProvider.notifier);
      final prefs = ref.read(preferencesServiceProvider);
      final messenger = ScaffoldMessenger.of(context);
      try {
        final fileName = await prefs.getVaultFileName();
        final result = await repo.loadAndDecrypt(
          masterPassword: master,
          fileName: fileName,
        );
        notifier.setVault(result.header, result.data, result.key, fileName: result.fileName ?? fileName);
        if (context.mounted) {
          context.go(VaultHomePage.routePath);
        }
      } on VaultLoadException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Falha ao abrir cofre: $e')));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Desbloquear Cofre')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Introduz a password mestra para abrir o cofre.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            UnlockForm(onUnlock: onUnlock),
          ],
        ),
      ),
    );
  }
}
