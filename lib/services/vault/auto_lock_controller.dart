import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_service.dart';
import 'vault_state.dart';

final lifecycleLockSuspensionProvider = StateProvider<int>((ref) => 0);

class AutoLockController {
  AutoLockController({required this.ref, required this.onTimeout});

  final WidgetRef ref;
  final VoidCallback onTimeout;

  Timer? _lockTimer;
  Duration _timeout = const Duration(minutes: 2);
  bool _loaded = false;
  bool _disabled = false;

  Future<void> restart() async {
    await _ensureTimeout();
    _lockTimer?.cancel();
    if (_disabled || _lifecycleLockSuspended) return;
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
    await _ensureTimeout();
    if (_disabled || _lifecycleLockSuspended) return;
    if (_isUnsafeLifecycleState(state)) {
      _triggerLock();
    } else if (state == AppLifecycleState.resumed) {
      await restart();
    }
  }

  Future<T> runWithLifecycleLockSuspended<T>(
    Future<T> Function() operation,
  ) async {
    await _ensureTimeout();
    final suspensions = ref.read(lifecycleLockSuspensionProvider.notifier);
    suspensions.state += 1;
    _lockTimer?.cancel();
    _lockTimer = null;
    try {
      return await operation();
    } finally {
      final current = ref.read(lifecycleLockSuspensionProvider);
      ref.read(lifecycleLockSuspensionProvider.notifier).state = current <= 1
          ? 0
          : current - 1;
      if (!_lifecycleLockSuspended) {
        await restart();
      }
    }
  }

  bool get _lifecycleLockSuspended =>
      ref.read(lifecycleLockSuspensionProvider) > 0;

  bool _isUnsafeLifecycleState(AppLifecycleState state) {
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
  }

  Future<void> _loadTimeout() async {
    final prefs = ref.read(preferencesServiceProvider);
    final minutes = await prefs.getAutoLockMinutes();
    _disabled = minutes == PreferencesService.autoLockNever;
    _timeout = _disabled
        ? Duration.zero
        : Duration(minutes: minutes.clamp(1, 30));
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
