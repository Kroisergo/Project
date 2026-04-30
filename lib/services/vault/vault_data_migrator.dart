import '../../utils/constants.dart';

class VaultDataMigrator {
  const VaultDataMigrator._();

  static Map<String, dynamic> migrate(Map<String, dynamic> json) {
    final migrated = Map<String, dynamic>.from(json);
    final rawVersion = migrated['version'];
    final version = rawVersion is int ? rawVersion : 1;
    migrated['version'] = version > VaultConstants.currentDataVersion
        ? version
        : VaultConstants.currentDataVersion;

    final fallbackUpdatedAt = _dateStringOrFallback(
      migrated['updatedAt'],
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String(),
    );
    migrated['updatedAt'] = fallbackUpdatedAt;

    final entries = migrated['entries'];
    migrated['entries'] = entries is List
        ? entries
              .map((entry) => _migrateEntry(entry, fallbackUpdatedAt))
              .toList()
        : <Map<String, dynamic>>[];

    return migrated;
  }

  static Map<String, dynamic> _migrateEntry(
    dynamic rawEntry,
    String fallbackUpdatedAt,
  ) {
    final entry = rawEntry is Map
        ? Map<String, dynamic>.from(rawEntry)
        : <String, dynamic>{};
    final updatedAt = _dateStringOrFallback(
      entry['updatedAt'],
      fallbackUpdatedAt,
    );
    final createdAt = _dateStringOrFallback(entry['createdAt'], updatedAt);
    final passwordUpdatedAt = _dateStringOrFallback(
      entry['passwordUpdatedAt'],
      updatedAt,
    );
    final lastOpenedAt = _dateStringOrFallback(
      entry['lastOpenedAt'],
      updatedAt,
    );
    final password = entry['password'] as String? ?? '';

    entry['id'] = entry['id'] as String? ?? '';
    entry['title'] = entry['title'] as String? ?? '';
    entry['username'] = entry['username'] as String? ?? '';
    entry['password'] = password;
    entry['notes'] = entry['notes'] as String? ?? '';
    final tags = entry['tags'];
    entry['tags'] = tags is List
        ? tags.whereType<String>().toList()
        : <String>[];
    entry['createdAt'] = createdAt;
    entry['updatedAt'] = updatedAt;
    entry['passwordUpdatedAt'] = passwordUpdatedAt;
    entry['lastOpenedAt'] = lastOpenedAt;
    entry['openCount'] = entry['openCount'] is num
        ? (entry['openCount'] as num).toInt()
        : 0;

    final deletedAt = entry['deletedAt'];
    if (deletedAt is! String || DateTime.tryParse(deletedAt) == null) {
      entry.remove('deletedAt');
    }

    entry['passwordHistory'] = _migratePasswordHistory(
      entry['passwordHistory'],
      currentPassword: password,
      fallbackChangedAt: passwordUpdatedAt,
    );
    return entry;
  }

  static List<Map<String, dynamic>> _migratePasswordHistory(
    dynamic rawHistory, {
    required String currentPassword,
    required String fallbackChangedAt,
  }) {
    final history = <Map<String, dynamic>>[];
    if (rawHistory is List) {
      for (final rawItem in rawHistory) {
        if (rawItem is String) {
          history.add({'password': rawItem, 'changedAt': fallbackChangedAt});
          continue;
        }
        if (rawItem is Map) {
          final item = Map<String, dynamic>.from(rawItem);
          history.add({
            'password': item['password'] as String? ?? '',
            'changedAt': _dateStringOrFallback(
              item['changedAt'],
              fallbackChangedAt,
            ),
          });
        }
      }
    }

    if (history.isNotEmpty && history.last['password'] == currentPassword) {
      history.removeLast();
    }
    return history;
  }

  static String _dateStringOrFallback(dynamic raw, String fallback) {
    if (raw is String && DateTime.tryParse(raw) != null) return raw;
    return fallback;
  }
}
