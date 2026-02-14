import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_service.dart';
import 'vault_state.dart';

class AutoLockController {
  AutoLockController({
    required this.ref,
    required this.onTimeout,
  });

  final WidgetRef ref;
  final VoidCallback onTimeout;

  Timer? _lockTimer;
  Duration _timeout = const Duration(minutes: 2);
  bool _loaded = false;

  Future<void> restart() async {
    await _ensureTimeout();
    _lockTimer?.cancel();
    _lockTimer = Timer(_timeout, _triggerLock);
  }

  Future<void> refreshTimeout() async {
    await _loadTimeout();
    await restart();
  }

  void cancel() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }

  Future<void> handleLifecycle(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _triggerLock();
    } else if (state == AppLifecycleState.resumed) {
      await restart();
    }
  }

  Future<void> _loadTimeout() async {
    final prefs = ref.read(preferencesServiceProvider);
    final minutes = await prefs.getAutoLockMinutes();
    _timeout = Duration(minutes: minutes.clamp(1, 30));
    _loaded = true;
  }

  Future<void> _ensureTimeout() async {
    if (_loaded) return;
    await _loadTimeout();
  }

  void _triggerLock() {
    cancel();
    final current = ref.read(vaultProvider);
    if (!current.isUnlocked) return;
    ref.read(vaultProvider.notifier).clear();
    onTimeout();
  }
}
