import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/security/screen_protection_controller.dart';
import '../services/storage/preferences_service.dart';
import '../services/vault/vault_state.dart';
import '../pages/unlock/unlock_page.dart';

class AppSecurityEffects extends ConsumerWidget {
  const AppSecurityEffects({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(screenProtectionControllerProvider);
    unawaited(controller.ensureEnabledByDefault());

    ref.listen<VaultState>(vaultProvider, (_, next) {
      unawaited(controller.syncForVaultState(next.isUnlocked));
    });
    return child;
  }
}

class AppLifecycleLockGuard extends ConsumerStatefulWidget {
  const AppLifecycleLockGuard({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<AppLifecycleLockGuard> createState() =>
      _AppLifecycleLockGuardState();
}

class _AppLifecycleLockGuardState extends ConsumerState<AppLifecycleLockGuard>
    with WidgetsBindingObserver {
  bool _redirectPending = false;
  bool _showVisualShield = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isUnsafeLifecycleState(state)) {
      _showShieldIfEnabled();
      _lockForLifecycle();
      return;
    }
    if (state == AppLifecycleState.resumed && _redirectPending) {
      _redirectToUnlock();
    }
    if (state == AppLifecycleState.resumed && _showVisualShield) {
      setState(() => _showVisualShield = false);
    }
  }

  void _showShieldIfEnabled() {
    unawaited(_showShieldAfterPreferenceCheck());
  }

  Future<void> _showShieldAfterPreferenceCheck() async {
    final enabled = await ref
        .read(preferencesServiceProvider)
        .getVisualProtection();
    if (!mounted) return;
    if (!enabled || _showVisualShield) return;
    setState(() => _showVisualShield = true);
  }

  bool _isUnsafeLifecycleState(AppLifecycleState state) {
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
  }

  void _lockForLifecycle() {
    final current = ref.read(vaultProvider);
    if (!current.isUnlocked) return;
    ref.read(vaultProvider.notifier).clear();
    _redirectPending = true;
  }

  void _redirectToUnlock() {
    _redirectPending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.router.go(UnlockPage.routePath);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showVisualShield)
          const Positioned.fill(child: ColoredBox(color: Color(0xFF121212))),
      ],
    );
  }
}
