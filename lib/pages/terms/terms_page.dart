import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/storage/preferences_service.dart';
import '../welcome/welcome_page.dart';

class TermsPage extends ConsumerStatefulWidget {
  static const routePath = '/terms';
  static const routeName = 'terms';

  const TermsPage({super.key});

  @override
  ConsumerState<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends ConsumerState<TermsPage> {
  bool saving = false;

  Future<void> _accept() async {
    setState(() => saving = true);
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setTermsAccepted(true);
    if (!mounted) return;
    context.go(WelcomePage.routePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termos de Utilização')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EncryVault é 100% offline. Garante que guardas a tua master password de forma segura. Ao continuar, aceitas que a recuperação é impossível se a master for perdida.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  '• Não existe sync remoto.\n'
                  '• O ficheiro do cofre é encriptado com Argon2id + XChaCha20-Poly1305.\n'
                  '• Qualquer corrupção ou password errada impede o acesso.\n'
                  '• Exporta o cofre regularmente para backup seguro.\n',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: saving ? null : _accept,
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Aceitar e continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
