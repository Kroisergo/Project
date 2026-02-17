import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/security/unlock_penalty_service.dart';
import '../../services/security/unlock_penalty_state.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/vault/vault_repository.dart';
import '../../services/vault/vault_state.dart';
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
    final status = await penaltyService.clearIfExpired(now: DateTime.now().toUtc());
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
      notifier.setVault(result.header, result.data, result.key, fileName: result.fileName ?? fileName);
      if (!mounted) return;
      context.go(VaultHomePage.routePath);
    } on VaultAuthException catch (_) {
      final status = await penaltyService.registerFailure(now: DateTime.now().toUtc());
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
        _showSnack('Password mestra incorreta.');
      }
    } on VaultLoadException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Falha ao abrir cofre: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _penalty.isLocked || _loadingStatus;

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
            const SizedBox(height: 8),
            if (_penalty.isLocked)
              Text(
                'Bloqueado por tentativas falhadas. Tenta novamente em ${_formatDuration(_penalty.remaining)}.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            const SizedBox(height: 20),
            UnlockForm(
              onUnlock: _onUnlock,
              enabled: !isLocked,
            ),
          ],
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
