import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/design_tokens.dart';
import '../../models/app_design_mode.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/storage/vault_file_service.dart';
import '../../widgets/app_brand_mark.dart';
import '../../widgets/app_surface.dart';
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
    final tokens = EncryVaultTheme.of(context);
    final isClassic = tokens.designMode == AppDesignMode.classic;

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
          final canCreate = canCreateVaultFromWelcome(
            hasVault: hasVault,
            loading: loading,
          );

          return DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.background,
              gradient: tokens.usesSoftGradient
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: tokens.isDark
                          ? const [
                              Color(0xFF030812),
                              Color(0xFF081223),
                              Color(0xFF170D2D),
                            ]
                          : [
                              tokens.background,
                              tokens.surfaceRaised,
                              tokens.background,
                            ],
                    )
                  : null,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.pagePadding + 4,
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: isClassic ? 82 : 86),
                          AppBrandMark(size: isClassic ? 72 : 104),
                          SizedBox(height: isClassic ? 44 : 34),
                          Text(
                            isClassic
                                ? 'O teu cofre digital offline'
                                : 'Bem-vindo ao EncryVault',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontSize: isClassic ? 27 : 26,
                                  height: isClassic ? 1.25 : 1.08,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            isClassic
                                ? 'Guarda palavras-passe e segredos num cofre local cifrado. Simples, discreto e sem sincronização remota.'
                                : 'Gestor de palavras-passe num único cofre cifrado, guardado localmente no teu dispositivo.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontSize: 15, height: 1.45),
                          ),
                          SizedBox(height: isClassic ? 62 : 48),
                          AppSurface(
                            elevated: !isClassic,
                            minHeight: isClassic ? 76 : 94,
                            padding: EdgeInsets.fromLTRB(
                              isClassic ? 20 : 22,
                              isClassic ? 16 : 20,
                              isClassic ? 20 : 22,
                              isClassic ? 16 : 20,
                            ),
                            radius: isClassic ? 10 : 20,
                            leadingAccentColor: isClassic
                                ? tokens.accentMuted
                                : null,
                            leadingAccentWidth: isClassic ? 3 : 0,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isClassic
                                            ? 'Privacidade por defeito'
                                            : 'Sem sincronização remota',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(fontSize: 14),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        isClassic
                                            ? 'Os dados permanecem no dispositivo.'
                                            : 'Os dados ficam contigo',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isClassic)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens.success.withValues(
                                        alpha: tokens.isDark ? 0.2 : 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: tokens.success.withValues(
                                          alpha: tokens.isDark ? 0.64 : 0.24,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Offline',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: tokens.textPrimary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: isClassic ? 78 : 72),
                          _WelcomeButton(
                            label: 'Criar cofre',
                            primary: true,
                            onPressed: canCreate
                                ? () => context.go(CreateMasterPage.routePath)
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _WelcomeButton(
                            label: 'Entrar',
                            primary: false,
                            onPressed: loading || !hasVault
                                ? null
                                : () => context.go(UnlockPage.routePath),
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
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () =>
                                context.go(ImportVaultPage.routePath),
                            child: const Text('Configurar'),
                          ),
                          const SizedBox(height: 34),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

bool canCreateVaultFromWelcome({
  required bool hasVault,
  required bool loading,
}) {
  return !loading && !hasVault;
}

class _WelcomeButton extends StatelessWidget {
  const _WelcomeButton({
    required this.label,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final isClassic = tokens.designMode == AppDesignMode.classic;
    final useModernGradient = primary && !isClassic && tokens.isDark;
    final secondaryModernDark = !primary && !isClassic && tokens.isDark;

    final button = SizedBox(
      width: double.infinity,
      height: tokens.buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: useModernGradient ? 0 : tokens.cardElevation,
          shadowColor: Colors.transparent,
          backgroundColor: useModernGradient
              ? Colors.transparent
              : secondaryModernDark
              ? tokens.surfaceRaised
              : tokens.accent,
          foregroundColor: secondaryModernDark
              ? tokens.textPrimary
              : tokens.onAccent,
          disabledBackgroundColor: tokens.surfaceRaised,
          disabledForegroundColor: tokens.textMuted,
          side: secondaryModernDark
              ? BorderSide(color: tokens.strongBorder)
              : BorderSide.none,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );

    if (!useModernGradient || onPressed == null) return button;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [tokens.accent, tokens.accentMuted]),
        borderRadius: BorderRadius.circular(tokens.buttonRadius),
      ),
      child: button,
    );
  }
}
