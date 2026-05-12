import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/design_tokens.dart';
import '../../models/app_design_mode.dart';
import '../../services/security/unlock_penalty_service.dart';
import '../../services/security/unlock_penalty_state.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/vault/vault_repository.dart';
import '../../services/vault/vault_state.dart';
import '../../widgets/app_brand_mark.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/vault_operation_loading_overlay.dart';
import '../vault_home/vault_home_page.dart';
import 'unlock_form.dart';

class UnlockPage extends ConsumerStatefulWidget {
  static const routePath = '/unlock';
  static const routeName = 'unlock';

  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  UnlockPenaltyState _penalty = UnlockPenaltyState.empty;
  Timer? _countdownTicker;
  bool _loadingStatus = true;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPenaltyStatus());
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  Future<void> _refreshPenaltyStatus() async {
    final penaltyService = ref.read(unlockPenaltyServiceProvider);
    final status = await penaltyService.clearIfExpired(
      now: DateTime.now().toUtc(),
    );
    if (!mounted) return;
    setState(() {
      _penalty = status;
      _loadingStatus = false;
    });
    _syncCountdownTicker();
  }

  void _syncCountdownTicker() {
    if (_penalty.isLocked) {
      _countdownTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(_refreshPenaltyStatus());
      });
      return;
    }
    _countdownTicker?.cancel();
    _countdownTicker = null;
  }

  Future<void> _onUnlock(String master) async {
    final repo = ref.read(vaultRepositoryProvider);
    final notifier = ref.read(vaultProvider.notifier);
    final prefs = ref.read(preferencesServiceProvider);
    final penaltyService = ref.read(unlockPenaltyServiceProvider);

    await _refreshPenaltyStatus();
    if (!mounted) return;
    if (_penalty.isLocked) {
      _showSnack(
        'Demasiadas tentativas. Aguarda ${_formatDuration(_penalty.remaining)}.',
      );
      return;
    }

    try {
      final fileName = await prefs.getVaultFileName();
      final result = await repo.loadAndDecrypt(
        masterPassword: master,
        fileName: fileName,
      );
      await penaltyService.registerSuccess();
      notifier.setVault(
        result.header,
        result.data,
        result.key,
        fileName: result.fileName ?? fileName,
        format: result.format,
        headerBytes: result.headerBytes,
      );
      if (!mounted) return;
      context.go(VaultHomePage.routePath);
    } on VaultAuthException catch (e) {
      final status = await penaltyService.registerFailure(
        now: DateTime.now().toUtc(),
      );
      if (!mounted) return;
      setState(() {
        _penalty = status;
      });
      _syncCountdownTicker();
      if (status.isLocked) {
        _showSnack(
          'Demasiadas tentativas. Aguarda ${_formatDuration(status.remaining)}.',
        );
      } else {
        _showSnack(e.message);
      }
    } on VaultLoadException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Falha ao abrir o cofre: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _penalty.isLocked || _loadingStatus;
    final tokens = EncryVaultTheme.of(context);
    final isClassic = tokens.designMode == AppDesignMode.classic;

    return Scaffold(
      appBar: AppBar(title: const Text('Desbloquear cofre')),
      backgroundColor: tokens.background,
      body: Stack(
        children: [
          DecoratedBox(
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
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding + 4),
              child: Column(
                children: [
                  SizedBox(height: isClassic ? 64 : 48),
                  AppBrandMark(size: isClassic ? 72 : 104),
                  SizedBox(height: isClassic ? 44 : 36),
                  Text(
                    isClassic ? 'Entrar no cofre' : 'Abrir cofre pessoal',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: isClassic ? 26 : 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isClassic
                        ? 'Introduz a palavra-passe mestra para aceder ao cofre offline.'
                        : 'Introduz a palavra-passe mestra. A app bloqueia após tentativas falhadas.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: isClassic ? 60 : 58),
                  UnlockForm(
                    onUnlock: _onUnlock,
                    enabled: !isLocked,
                    buttonLabel: 'Entrar',
                    onLoadingChanged: (loading) {
                      if (!mounted) return;
                      setState(() => _unlocking = loading);
                    },
                    middle: _UnlockNotice(
                      locked: _penalty.isLocked,
                      formattedRemaining: _formatDuration(_penalty.remaining),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          if (_unlocking)
            const VaultOperationLoadingOverlay(
              title: 'A desbloquear cofre',
              message: 'A verificar a palavra-passe e a decifrar os dados.',
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60);
    final seconds = safe.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UnlockNotice extends StatelessWidget {
  const _UnlockNotice({required this.locked, required this.formattedRemaining});

  final bool locked;
  final String formattedRemaining;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final isClassic = tokens.designMode == AppDesignMode.classic;
    final color = locked ? tokens.danger : tokens.warning;

    return AppSurface(
      elevated: !isClassic,
      minHeight: isClassic ? 76 : 74,
      radius: isClassic ? 10 : 18,
      padding: EdgeInsets.fromLTRB(isClassic ? 20 : 18, 14, 18, 14),
      leadingAccentColor: isClassic ? color : null,
      leadingAccentWidth: isClassic ? 3 : 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isClassic) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(
                locked ? Icons.lock_clock_outlined : Icons.priority_high,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locked
                      ? 'Bloqueado por tentativas falhadas'
                      : isClassic
                      ? 'Proteção contra tentativas falhadas'
                      : 'Proteção contra força bruta ativa',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: tokens.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  locked
                      ? 'Tenta novamente em $formattedRemaining.'
                      : 'Tentativas excessivas aplicam espera temporária.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
