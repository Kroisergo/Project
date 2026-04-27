import 'package:password_strength_checker/password_strength_checker.dart';

import '../../models/vault_entry.dart';
import 'password_entry_recommendation.dart';

class PasswordHealthReport {
  final int total;
  final int weak;
  final int reused;
  final int reusedGroups;
  final int old;
  final int empty;
  final int uncategorized;

  const PasswordHealthReport({
    required this.total,
    required this.weak,
    required this.reused,
    required this.reusedGroups,
    required this.old,
    required this.empty,
    required this.uncategorized,
  });

  bool get hasImportantAlerts => weak > 0 || reused > 0 || old > 0;

  String get summary {
    if (total == 0) return 'Ainda nao existem entradas ativas.';
    if (!hasImportantAlerts) return 'O cofre nao tem alertas relevantes.';
    final parts = <String>[];
    if (weak > 0) parts.add('$weak fraca(s)');
    if (reused > 0) parts.add('$reused reutilizada(s)');
    if (old > 0) parts.add('$old a mudar');
    return 'Alertas: ${parts.join(', ')}.';
  }
}

class PasswordHealthService {
  const PasswordHealthService._();

  static PasswordHealthReport analyze(
    List<VaultEntry> entries, {
    DateTime? now,
  }) {
    final activeEntries = entries.where((entry) => !entry.isDeleted).toList();
    final passwordCounts = _passwordCounts(activeEntries);
    final referenceNow = (now ?? DateTime.now()).toUtc();
    var weak = 0;
    var reused = 0;
    var old = 0;
    var empty = 0;
    var uncategorized = 0;

    for (final entry in activeEntries) {
      final password = entry.password;
      if (password.trim().isEmpty) {
        empty++;
        weak++;
      } else if (isWeakPassword(password)) {
        weak++;
      }
      if (password.isNotEmpty && (passwordCounts[password] ?? 0) > 1) {
        reused++;
      }
      final recommendation = PasswordEntryRecommendationService.evaluate(
        password: password,
        passwordUpdatedAt: entry.passwordUpdatedAt,
      );
      if (!referenceNow.isBefore(recommendation.dueAt)) {
        old++;
      }
      if (entry.tags.isEmpty) {
        uncategorized++;
      }
    }

    return PasswordHealthReport(
      total: activeEntries.length,
      weak: weak,
      reused: reused,
      reusedGroups: passwordCounts.values.where((count) => count > 1).length,
      old: old,
      empty: empty,
      uncategorized: uncategorized,
    );
  }

  static int reuseCountForPassword(
    List<VaultEntry> entries,
    String password, {
    String? excludeEntryId,
  }) {
    if (password.isEmpty) return 0;
    return entries
        .where((entry) => !entry.isDeleted)
        .where((entry) => entry.id != excludeEntryId)
        .where((entry) => entry.password == password)
        .length;
  }

  static List<String> alertsForEntry({
    required List<VaultEntry> entries,
    required VaultEntry entry,
    DateTime? now,
  }) {
    final alerts = <String>[];
    final reuseCount = reuseCountForPassword(
      entries,
      entry.password,
      excludeEntryId: entry.id,
    );
    if (reuseCount > 0) {
      alerts.add(
        'Esta palavra-passe esta a ser usada em ${reuseCount + 1} entradas.',
      );
    }
    if (entry.password.trim().isEmpty) {
      alerts.add('Esta entrada nao tem palavra-passe guardada.');
    } else if (isWeakPassword(entry.password)) {
      alerts.add('Esta palavra-passe e fraca.');
    }

    final recommendation = PasswordEntryRecommendationService.evaluate(
      password: entry.password,
      passwordUpdatedAt: entry.passwordUpdatedAt,
    );
    final referenceNow = (now ?? DateTime.now()).toUtc();
    if (!referenceNow.isBefore(recommendation.dueAt)) {
      alerts.add('Esta palavra-passe devia ser mudada.');
    }
    return alerts;
  }

  static bool isWeakPassword(String password) {
    final strength = PasswordStrength.calculate(text: password);
    return strength == PasswordStrength.alreadyExposed ||
        strength == PasswordStrength.weak;
  }

  static bool isWeakEntry(VaultEntry entry) {
    return entry.password.trim().isEmpty || isWeakPassword(entry.password);
  }

  static bool isReusedEntry(List<VaultEntry> entries, VaultEntry entry) {
    return reuseCountForPassword(
          entries,
          entry.password,
          excludeEntryId: entry.id,
        ) >
        0;
  }

  static Map<String, int> _passwordCounts(List<VaultEntry> entries) {
    final counts = <String, int>{};
    for (final entry in entries) {
      if (entry.password.isEmpty) continue;
      counts[entry.password] = (counts[entry.password] ?? 0) + 1;
    }
    return counts;
  }
}
