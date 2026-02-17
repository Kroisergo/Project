class UnlockPenaltyState {
  const UnlockPenaltyState({
    required this.failedCount,
    required this.lockUntil,
    required this.remaining,
  });

  final int failedCount;
  final DateTime? lockUntil;
  final Duration remaining;

  bool get isLocked => remaining > Duration.zero;

  static const empty = UnlockPenaltyState(
    failedCount: 0,
    lockUntil: null,
    remaining: Duration.zero,
  );
}
