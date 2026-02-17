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
    final fallbackUpdatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final updatedRaw = json['updatedAt'];
    final parsedUpdatedAt = updatedRaw is String ? DateTime.tryParse(updatedRaw) : null;
    final updatedAt = (parsedUpdatedAt ?? fallbackUpdatedAt).toUtc();
    final entriesJson = json['entries'] as List<dynamic>? ?? [];
    return VaultData(
      version: json['version'] as int? ?? 1,
      updatedAt: updatedAt,
      entries: entriesJson
          .map(
            (entry) => VaultEntry.fromJson(
              entry as Map<String, dynamic>,
              fallbackUpdatedAt: updatedAt,
            ),
          )
          .toList(),
    );
  }
}
