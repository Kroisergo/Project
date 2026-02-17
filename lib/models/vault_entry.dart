class VaultEntry {
  final String id;
  final String title;
  final String username;
  final String password;
  final String notes;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VaultEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.notes,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  VaultEntry copyWith({
    String? title,
    String? username,
    String? password,
    String? notes,
    List<String>? tags,
    DateTime? updatedAt,
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
    };
  }

  factory VaultEntry.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackUpdatedAt,
  }) {
    final fallback = (fallbackUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)).toUtc();
    final parsedUpdated = _tryParseDate(json['updatedAt']);
    final updatedAt = (parsedUpdated ?? fallback).toUtc();
    final parsedCreated = _tryParseDate(json['createdAt']);
    final createdAt = (parsedCreated ?? updatedAt).toUtc();

    return VaultEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _tryParseDate(dynamic raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }
}
