class VaultPasswordHistoryItem {
  final String password;
  final DateTime changedAt;

  const VaultPasswordHistoryItem({
    required this.password,
    required this.changedAt,
  });

  Map<String, dynamic> toJson() {
    return {'password': password, 'changedAt': changedAt.toIso8601String()};
  }

  factory VaultPasswordHistoryItem.fromJson(
    Map<String, dynamic> json, {
    required DateTime fallbackChangedAt,
  }) {
    final parsedChangedAt = VaultEntry._tryParseDate(json['changedAt']);
    return VaultPasswordHistoryItem(
      password: json['password'] as String? ?? '',
      changedAt: (parsedChangedAt ?? fallbackChangedAt).toUtc(),
    );
  }
}

class VaultEntry {
  final String id;
  final String title;
  final String username;
  final String password;
  final String notes;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime passwordUpdatedAt;
  final DateTime lastOpenedAt;
  final int openCount;
  final List<VaultPasswordHistoryItem> passwordHistory;
  final DateTime? deletedAt;

  const VaultEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.notes,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.passwordUpdatedAt,
    required this.lastOpenedAt,
    this.openCount = 0,
    required this.passwordHistory,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  VaultEntry copyWith({
    String? title,
    String? username,
    String? password,
    String? notes,
    List<String>? tags,
    DateTime? updatedAt,
    DateTime? passwordUpdatedAt,
    DateTime? lastOpenedAt,
    int? openCount,
    List<VaultPasswordHistoryItem>? passwordHistory,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return VaultEntry(
      id: id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      passwordUpdatedAt: passwordUpdatedAt ?? this.passwordUpdatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      openCount: openCount ?? this.openCount,
      passwordHistory: passwordHistory ?? this.passwordHistory,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'password': password,
      'notes': notes,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'passwordUpdatedAt': passwordUpdatedAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt.toIso8601String(),
      'openCount': openCount,
      'passwordHistory': passwordHistory.map((item) => item.toJson()).toList(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }

  factory VaultEntry.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackUpdatedAt,
  }) {
    final fallback =
        (fallbackUpdatedAt ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
            .toUtc();
    final parsedUpdated = _tryParseDate(json['updatedAt']);
    final updatedAt = (parsedUpdated ?? fallback).toUtc();
    final parsedCreated = _tryParseDate(json['createdAt']);
    final createdAt = (parsedCreated ?? updatedAt).toUtc();
    final parsedPasswordUpdated = _tryParseDate(json['passwordUpdatedAt']);
    final passwordUpdatedAt = (parsedPasswordUpdated ?? updatedAt).toUtc();
    final parsedLastOpened = _tryParseDate(json['lastOpenedAt']);
    final lastOpenedAt = (parsedLastOpened ?? updatedAt).toUtc();
    final parsedOpenCount = json['openCount'];
    final openCount = parsedOpenCount is num ? parsedOpenCount.toInt() : 0;
    final deletedAt = _tryParseDate(json['deletedAt'])?.toUtc();
    final password = json['password'] as String? ?? '';
    final passwordHistory = _parsePasswordHistory(
      json['passwordHistory'],
      fallbackChangedAt: passwordUpdatedAt,
      currentPassword: password,
    );

    return VaultEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      username: json['username'] as String? ?? '',
      password: password,
      notes: json['notes'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      passwordUpdatedAt: passwordUpdatedAt,
      lastOpenedAt: lastOpenedAt,
      openCount: openCount < 0 ? 0 : openCount,
      passwordHistory: passwordHistory,
      deletedAt: deletedAt,
    );
  }

  static List<VaultPasswordHistoryItem> _parsePasswordHistory(
    dynamic rawHistory, {
    required DateTime fallbackChangedAt,
    required String currentPassword,
  }) {
    final history = <VaultPasswordHistoryItem>[];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is Map<String, dynamic>) {
          history.add(
            VaultPasswordHistoryItem.fromJson(
              item,
              fallbackChangedAt: fallbackChangedAt,
            ),
          );
        } else if (item is Map) {
          history.add(
            VaultPasswordHistoryItem.fromJson(
              Map<String, dynamic>.from(item),
              fallbackChangedAt: fallbackChangedAt,
            ),
          );
        }
      }
    }

    if (history.isEmpty || history.last.password != currentPassword) {
      history.add(
        VaultPasswordHistoryItem(
          password: currentPassword,
          changedAt: fallbackChangedAt,
        ),
      );
    }
    return history;
  }

  static DateTime? _tryParseDate(dynamic raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }
}
