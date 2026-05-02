import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/storage/preferences_service.dart';
import '../../services/storage/vault_file_service.dart';
import '../create_master/create_master_page.dart';
import '../unlock/unlock_page.dart';
import 'import_vault_page.dart';

class WelcomePage extends ConsumerStatefulWidget {
  static const routePath = '/welcome';
  static const routeName = 'welcome';

  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  late final Future<bool> _hasVaultFuture;

  @override
  void initState() {
    super.initState();
    _hasVaultFuture = _loadHasVault();
  }

  Future<bool> _loadHasVault() async {
    final prefs = ref.read(preferencesServiceProvider);
    final preferredName = await prefs.getVaultFileName();
    return VaultFileService().hasExistingVault(preferredName: preferredName);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('EncryVault'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<bool>(
        future: _hasVaultFuture,
        builder: (context, snapshot) {
          final hasVault = snapshot.data ?? false;
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF0D1728),
                        Color(0xFF102A43),
                        Color(0xFF121212),
                      ]
                    : [
                        const Color(0xFFEAF3FF),
                        const Color(0xFFD8E9FF),
                        scheme.surface,
                      ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(
                        alpha: isDark ? 0.2 : 0.72,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.24 : 0.08,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/branding/app_icon.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.contain,
                        ),
                      ),
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
                    'Gestor de palavras-passe num único cofre cifrado.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => context.go(CreateMasterPage.routePath),
                    child: const Text('Criar cofre'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: loading || !hasVault
                        ? null
                        : () => context.go(UnlockPage.routePath),
                    child: const Text('Entrar'),
                  ),
                  if (!loading && !hasVault)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Cria ou importa um cofre para poderes entrar.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go(ImportVaultPage.routePath),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Configurar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
