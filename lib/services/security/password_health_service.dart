import 'package:password_strength_checker/password_strength_checker.dart';

import '../../models/vault_entry.dart';
import '../vault/trash_retention_policy.dart';
import 'password_entry_recommendation.dart';

enum PasswordHealthIssue {
  weak,
  reused,
  old,
  empty,
  uncategorized,
  neverOpened,
  rarelyUsed,
  largeHistory,
  oldTrash,
}

class PasswordHealthReport {
  final int total;
  final int weak;
  final int reused;
  final int reusedGroups;
  final int old;
  final int empty;
  final int uncategorized;
  final int neverOpened;
  final int rarelyUsed;
  final int largeHistory;
  final int oldTrash;

  const PasswordHealthReport({
    required this.total,
    required this.weak,
    required this.reused,
    required this.reusedGroups,
    required this.old,
    required this.empty,
    required this.uncategorized,
    required this.neverOpened,
    required this.rarelyUsed,
    required this.largeHistory,
    required this.oldTrash,
  });

  bool get hasImportantAlerts =>
      weak > 0 || reused > 0 || old > 0 || empty > 0 || oldTrash > 0;

  String get summary {
    if (total == 0) return 'Ainda não existem entradas ativas.';
    if (!hasImportantAlerts) return 'O cofre não tem alertas relevantes.';
    final parts = <String>[];
    if (weak > 0) parts.add('$weak fraca(s)');
    if (reused > 0) parts.add('$reused reutilizada(s)');
    if (old > 0) parts.add('$old a mudar');
    if (empty > 0) parts.add('$empty sem palavra-passe');
    if (oldTrash > 0) parts.add('$oldTrash no Lixo há muito tempo');
    return 'Alertas: ${parts.join(', ')}.';
  }
}

class PasswordHealthService {
  static const largeHistoryThreshold = 5;
  static const oldTrashAge = Duration(days: 30);

  const PasswordHealthService._();

  static PasswordHealthReport analyze(
    List<VaultEntry> entries, {
    DateTime? now,
    TrashRetentionOption trashRetention = TrashRetentionPolicy.defaultOption,
  }) {
    final activeEntries = entries.where((entry) => !entry.isDeleted).toList();
    final deletedEntries = entries.where((entry) => entry.isDeleted).toList();
    final passwordCounts = _passwordCounts(activeEntries);
    final referenceNow = (now ?? DateTime.now()).toUtc();
    var weak = 0;
    var reused = 0;
    var old = 0;
    var empty = 0;
    var uncategorized = 0;
    var neverOpened = 0;
    var rarelyUsed = 0;
    var largeHistory = 0;

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
      if (entry.openCount == 0) {
        neverOpened++;
      }
      if (entry.openCount <= 1) {
        rarelyUsed++;
      }
      if (entry.passwordHistory.length >= largeHistoryThreshold) {
        largeHistory++;
      }
    }

    final oldTrash = deletedEntries
        .where(
          (entry) => isOldTrashEntry(
            entry,
            now: referenceNow,
            trashRetention: trashRetention,
          ),
        )
        .length;

    return PasswordHealthReport(
      total: activeEntries.length,
      weak: weak,
      reused: reused,
      reusedGroups: passwordCounts.values.where((count) => count > 1).length,
      old: old,
      empty: empty,
      uncategorized: uncategorized,
      neverOpened: neverOpened,
      rarelyUsed: rarelyUsed,
      largeHistory: largeHistory,
      oldTrash: oldTrash,
    );
  }

  static List<VaultEntry> entriesForIssue(
    List<VaultEntry> entries,
    PasswordHealthIssue issue, {
    DateTime? now,
    TrashRetentionOption trashRetention = TrashRetentionPolicy.defaultOption,
  }) {
    final referenceNow = (now ?? DateTime.now()).toUtc();
    final activeEntries = entries.where((entry) => !entry.isDeleted).toList();
    return switch (issue) {
      PasswordHealthIssue.weak => activeEntries.where(isWeakEntry).toList(),
      PasswordHealthIssue.reused =>
        activeEntries
            .where((entry) => isReusedEntry(activeEntries, entry))
            .toList(),
      PasswordHealthIssue.old =>
        activeEntries
            .where(
              (entry) => !referenceNow.isBefore(
                PasswordEntryRecommendationService.evaluate(
                  password: entry.password,
                  passwordUpdatedAt: entry.passwordUpdatedAt,
                ).dueAt,
              ),
            )
            .toList(),
      PasswordHealthIssue.empty =>
        activeEntries.where((entry) => entry.password.trim().isEmpty).toList(),
      PasswordHealthIssue.uncategorized =>
        activeEntries.where((entry) => entry.tags.isEmpty).toList(),
      PasswordHealthIssue.neverOpened =>
        activeEntries.where((entry) => entry.openCount == 0).toList(),
      PasswordHealthIssue.rarelyUsed =>
        activeEntries.where((entry) => entry.openCount <= 1).toList(),
      PasswordHealthIssue.largeHistory =>
        activeEntries
            .where(
              (entry) => entry.passwordHistory.length >= largeHistoryThreshold,
            )
            .toList(),
      PasswordHealthIssue.oldTrash =>
        entries
            .where(
              (entry) => isOldTrashEntry(
                entry,
                now: referenceNow,
                trashRetention: trashRetention,
              ),
            )
            .toList(),
    };
  }

  static String reasonForIssue({
    required PasswordHealthIssue issue,
    required List<VaultEntry> entries,
    required VaultEntry entry,
  }) {
    return switch (issue) {
      PasswordHealthIssue.weak =>
        entry.password.trim().isEmpty
            ? 'Esta entrada não tem palavra-passe guardada.'
            : 'Esta palavra-passe é fraca.',
      PasswordHealthIssue.reused => _reusedReason(entries, entry),
      PasswordHealthIssue.old => 'Recomenda-se alterar esta palavra-passe.',
      PasswordHealthIssue.empty =>
        'Esta entrada não tem palavra-passe guardada.',
      PasswordHealthIssue.uncategorized =>
        'Esta entrada não tem categoria/tag.',
      PasswordHealthIssue.neverOpened => 'Esta entrada nunca foi aberta.',
      PasswordHealthIssue.rarelyUsed => 'Esta entrada é pouco usada.',
      PasswordHealthIssue.largeHistory =>
        'Esta entrada tem histórico de palavra-passes grande.',
      PasswordHealthIssue.oldTrash =>
        'Esta entrada está no Lixo há muito tempo.',
    };
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

  static String _reusedReason(List<VaultEntry> entries, VaultEntry entry) {
    final count =
        reuseCountForPassword(
          entries,
          entry.password,
          excludeEntryId: entry.id,
        ) +
        1;
    return 'Esta palavra-passe está a ser usada em $count entradas.';
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
        'Esta palavra-passe está a ser usada em ${reuseCount + 1} entradas.',
      );
    }
    if (entry.password.trim().isEmpty) {
      alerts.add('Esta entrada não tem palavra-passe guardada.');
    } else if (isWeakPassword(entry.password)) {
      alerts.add('Esta palavra-passe é fraca.');
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
    if (password.trim().isEmpty) return true;
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

  static bool isOldTrashEntry(
    VaultEntry entry, {
    DateTime? now,
    TrashRetentionOption trashRetention = TrashRetentionPolicy.defaultOption,
  }) {
    final deletedAt = entry.deletedAt;
    if (deletedAt == null) return false;
    final referenceNow = (now ?? DateTime.now()).toUtc();
    final permanentAt = TrashRetentionPolicy.permanentDeletionAt(
      deletedAt,
      option: trashRetention,
    );
    if (permanentAt != null &&
        !referenceNow.isBefore(permanentAt.subtract(const Duration(days: 7)))) {
      return true;
    }
    return !referenceNow.isBefore(deletedAt.toUtc().add(oldTrashAge));
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
