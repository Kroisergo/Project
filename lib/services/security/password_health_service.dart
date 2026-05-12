import 'package:password_strength_checker/password_strength_checker.dart';

import '../../models/vault_entry.dart';
import '../../utils/constants.dart';
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

class PasswordHealthEntryAlert {
  final PasswordHealthIssue issue;
  final String message;
  final String ignoreKey;

  const PasswordHealthEntryAlert({
    required this.issue,
    required this.message,
    required this.ignoreKey,
  });
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
    if (weak > 0) parts.add(_countLabel(weak, 'fraca', 'fracas'));
    if (reused > 0) {
      parts.add(_countLabel(reused, 'reutilizada', 'reutilizadas'));
    }
    if (old > 0) parts.add('$old a mudar');
    if (empty > 0) parts.add('$empty sem palavra-passe');
    if (oldTrash > 0) parts.add('$oldTrash no Lixo há muito tempo');
    return 'Alertas: ${parts.join(', ')}.';
  }

  static String _countLabel(int count, String singular, String plural) {
    return '$count ${count == 1 ? singular : plural}';
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
    Map<String, int> ignoredAlertExpiries = const {},
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
        if (!isIssueIgnored(
          entry: entry,
          issue: PasswordHealthIssue.empty,
          ignoredAlertExpiries: ignoredAlertExpiries,
          now: referenceNow,
        )) {
          empty++;
        }
        if (!isIssueIgnored(
          entry: entry,
          issue: PasswordHealthIssue.weak,
          ignoredAlertExpiries: ignoredAlertExpiries,
          now: referenceNow,
        )) {
          weak++;
        }
      } else if (isWeakPassword(password)) {
        if (!isIssueIgnored(
          entry: entry,
          issue: PasswordHealthIssue.weak,
          ignoredAlertExpiries: ignoredAlertExpiries,
          now: referenceNow,
        )) {
          weak++;
        }
      }
      if (password.isNotEmpty && (passwordCounts[password] ?? 0) > 1) {
        if (!isIssueIgnored(
          entry: entry,
          issue: PasswordHealthIssue.reused,
          ignoredAlertExpiries: ignoredAlertExpiries,
          now: referenceNow,
        )) {
          reused++;
        }
      }
      final recommendation = PasswordEntryRecommendationService.evaluate(
        password: password,
        passwordUpdatedAt: entry.passwordUpdatedAt,
      );
      if (!referenceNow.isBefore(recommendation.dueAt)) {
        if (!isIssueIgnored(
          entry: entry,
          issue: PasswordHealthIssue.old,
          ignoredAlertExpiries: ignoredAlertExpiries,
          now: referenceNow,
        )) {
          old++;
        }
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
          (entry) =>
              isOldTrashEntry(
                entry,
                now: referenceNow,
                trashRetention: trashRetention,
              ) &&
              !isIssueIgnored(
                entry: entry,
                issue: PasswordHealthIssue.oldTrash,
                ignoredAlertExpiries: ignoredAlertExpiries,
                now: referenceNow,
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

  static int vaultHealthScore(PasswordHealthReport report) {
    final penalty = report.weak * 8 + report.old * 4 + report.empty * 10;
    return (100 - penalty).clamp(0, 100).toInt();
  }

  static int vaultHealthAttentionPoints(PasswordHealthReport report) {
    var points = 0;
    if (report.weak > 0) points++;
    if (report.old > 0) points++;
    if (report.empty > 0) points++;
    return points;
  }

  static List<VaultEntry> entriesForIssue(
    List<VaultEntry> entries,
    PasswordHealthIssue issue, {
    DateTime? now,
    TrashRetentionOption trashRetention = TrashRetentionPolicy.defaultOption,
    Map<String, int> ignoredAlertExpiries = const {},
  }) {
    final referenceNow = (now ?? DateTime.now()).toUtc();
    final activeEntries = entries.where((entry) => !entry.isDeleted).toList();
    final affected = switch (issue) {
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
    return affected
        .where(
          (entry) => !isIssueIgnored(
            entry: entry,
            issue: issue,
            ignoredAlertExpiries: ignoredAlertExpiries,
            now: referenceNow,
          ),
        )
        .toList();
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
        'Esta entrada não tem categoria/etiqueta.',
      PasswordHealthIssue.neverOpened => 'Esta entrada nunca foi aberta.',
      PasswordHealthIssue.rarelyUsed => 'Esta entrada é pouco usada.',
      PasswordHealthIssue.largeHistory =>
        'Esta entrada tem um histórico de palavras-passe grande.',
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

  static String alertIgnoreKey({
    required String entryId,
    required PasswordHealthIssue issue,
  }) {
    return '$entryId:${issue.name}';
  }

  static bool isIssueIgnored({
    required VaultEntry entry,
    required PasswordHealthIssue issue,
    required Map<String, int> ignoredAlertExpiries,
    DateTime? now,
  }) {
    final expiry =
        ignoredAlertExpiries[alertIgnoreKey(entryId: entry.id, issue: issue)];
    if (expiry == null) return false;
    if (expiry == VaultConstants.ignoredAlertNoExpiryValue) return true;
    final reference = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return expiry > reference;
  }

  static List<PasswordHealthEntryAlert> typedAlertsForEntry({
    required List<VaultEntry> entries,
    required VaultEntry entry,
    DateTime? now,
  }) {
    final alerts = <PasswordHealthEntryAlert>[];
    final reuseCount = reuseCountForPassword(
      entries,
      entry.password,
      excludeEntryId: entry.id,
    );
    if (reuseCount > 0) {
      alerts.add(
        PasswordHealthEntryAlert(
          issue: PasswordHealthIssue.reused,
          message:
              'Esta palavra-passe está a ser usada em ${reuseCount + 1} entradas.',
          ignoreKey: alertIgnoreKey(
            entryId: entry.id,
            issue: PasswordHealthIssue.reused,
          ),
        ),
      );
    }
    if (entry.password.trim().isEmpty) {
      alerts.add(
        PasswordHealthEntryAlert(
          issue: PasswordHealthIssue.empty,
          message: 'Esta entrada não tem palavra-passe guardada.',
          ignoreKey: alertIgnoreKey(
            entryId: entry.id,
            issue: PasswordHealthIssue.empty,
          ),
        ),
      );
    } else if (isWeakPassword(entry.password)) {
      alerts.add(
        PasswordHealthEntryAlert(
          issue: PasswordHealthIssue.weak,
          message: 'Esta palavra-passe é fraca.',
          ignoreKey: alertIgnoreKey(
            entryId: entry.id,
            issue: PasswordHealthIssue.weak,
          ),
        ),
      );
    }

    final recommendation = PasswordEntryRecommendationService.evaluate(
      password: entry.password,
      passwordUpdatedAt: entry.passwordUpdatedAt,
    );
    final referenceNow = (now ?? DateTime.now()).toUtc();
    if (!referenceNow.isBefore(recommendation.dueAt)) {
      alerts.add(
        PasswordHealthEntryAlert(
          issue: PasswordHealthIssue.old,
          message: 'Esta palavra-passe deve ser alterada.',
          ignoreKey: alertIgnoreKey(
            entryId: entry.id,
            issue: PasswordHealthIssue.old,
          ),
        ),
      );
    }
    return alerts;
  }

  static List<PasswordHealthEntryAlert> visibleAlertsForEntry({
    required List<VaultEntry> entries,
    required VaultEntry entry,
    required Map<String, int> ignoredAlertExpiries,
    DateTime? now,
  }) {
    final referenceNow = (now ?? DateTime.now()).toUtc();
    return typedAlertsForEntry(
          entries: entries,
          entry: entry,
          now: referenceNow,
        )
        .where(
          (alert) => !isIssueIgnored(
            entry: entry,
            issue: alert.issue,
            ignoredAlertExpiries: ignoredAlertExpiries,
            now: referenceNow,
          ),
        )
        .toList();
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
      alerts.add('Esta palavra-passe deve ser alterada.');
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
