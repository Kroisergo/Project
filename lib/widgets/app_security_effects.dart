import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/security/screen_protection_controller.dart';
import '../services/vault/vault_state.dart';

class AppSecurityEffects extends ConsumerWidget {
  const AppSecurityEffects({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(screenProtectionControllerProvider);
    final current = ref.read(vaultProvider);
    unawaited(controller.syncForVaultState(current.isUnlocked));

    ref.listen<VaultState>(
      vaultProvider,
      (_, next) {
        unawaited(controller.syncForVaultState(next.isUnlocked));
      },
    );
    return child;
  }
}
