import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_service.dart';
import 'unlock_penalty_state.dart';

class UnlockPenaltyService {
  UnlockPenaltyService({
    required this.preferencesService,
  });

  final PreferencesService preferencesService;
  Future<void> _queue = Future<void>.value();

  Future<UnlockPenaltyState> getStatus({DateTime? now}) {
    return _enqueue(() async {
      final currentNow = (now ?? DateTime.now()).toUtc();
      var failedCount = await preferencesService.getUnlockFailedCount();
      DateTime? lockUntil = _readLockUntil(await preferencesService.getUnlockLockUntilEpochMs());

      if (failedCount < 0) {
        failedCount = 0;
        await preferencesService.setUnlockFailedCount(0);
      }

      if (lockUntil != null && !lockUntil.isAfter(currentNow)) {
        lockUntil = null;
        await preferencesService.setUnlockLockUntilEpochMs(null);
      }

      final remaining = lockUntil == null ? Duration.zero : lockUntil.difference(currentNow);
      return UnlockPenaltyState(
        failedCount: failedCount,
        lockUntil: lockUntil,
        remaining: remaining.isNegative ? Duration.zero : remaining,
      );
    });
  }

  Future<UnlockPenaltyState> registerFailure({DateTime? now}) {
    return _enqueue(() async {
      final currentNow = (now ?? DateTime.now()).toUtc();
      final nextCount = (await preferencesService.getUnlockFailedCount()) + 1;
      await preferencesService.setUnlockFailedCount(nextCount);

      DateTime? lockUntil;
      if (nextCount >= 3) {
        final minutes = _penaltyMinutesForFailureCount(nextCount);
        lockUntil = currentNow.add(Duration(minutes: minutes));
      }
      await preferencesService.setUnlockLockUntilEpochMs(lockUntil?.millisecondsSinceEpoch);

      final remaining = lockUntil == null ? Duration.zero : lockUntil.difference(currentNow);
      return UnlockPenaltyState(
        failedCount: nextCount,
        lockUntil: lockUntil,
        remaining: remaining.isNegative ? Duration.zero : remaining,
      );
    });
  }

  Future<void> registerSuccess() {
    return _enqueue(() async {
      await preferencesService.setUnlockFailedCount(0);
      await preferencesService.setUnlockLockUntilEpochMs(null);
    });
  }

  Future<UnlockPenaltyState> clearIfExpired({DateTime? now}) {
    return getStatus(now: now);
  }

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  DateTime? _readLockUntil(int? epochMs) {
    if (epochMs == null || epochMs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
  }

  int _penaltyMinutesForFailureCount(int failedCount) {
    if (failedCount < 3) return 0;
    final extraBlocks = (failedCount - 3) ~/ 2;
    return 10 + (extraBlocks * 15);
  }
}

final unlockPenaltyServiceProvider = Provider<UnlockPenaltyService>((ref) {
  return UnlockPenaltyService(
    preferencesService: ref.read(preferencesServiceProvider),
  );
});
