import 'vault_entry.dart';

class VaultData {
  final int version;
  final DateTime updatedAt;
  final List<VaultEntry> entries;

  const VaultData({
    required this.version,
    required this.updatedAt,
    required this.entries,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'updatedAt': updatedAt.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  factory VaultData.fromJson(Map<String, dynamic> json) {
    final entriesJson = json['entries'] as List<dynamic>? ?? [];
    return VaultData(
      version: json['version'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      entries: entriesJson.map((e) => VaultEntry.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
