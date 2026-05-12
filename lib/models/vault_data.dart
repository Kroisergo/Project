import 'vault_document.dart';
import 'vault_entry.dart';
import '../utils/constants.dart';

class VaultData {
  final int version;
  final DateTime updatedAt;
  final List<VaultEntry> entries;
  final List<VaultDocumentMetadata> documents;

  const VaultData({
    required this.version,
    required this.updatedAt,
    required this.entries,
    this.documents = const [],
  });

  List<VaultEntry> get activeEntries =>
      entries.where((entry) => !entry.isDeleted).toList();

  List<VaultEntry> get deletedEntries =>
      entries.where((entry) => entry.isDeleted).toList();

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'updatedAt': updatedAt.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'documents': documents.map((document) => document.toJson()).toList(),
    };
  }

  factory VaultData.fromJson(Map<String, dynamic> json) {
    final fallbackUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
      0,
      isUtc: true,
    );
    final updatedRaw = json['updatedAt'];
    final parsedUpdatedAt = updatedRaw is String
        ? DateTime.tryParse(updatedRaw)
        : null;
    final updatedAt = (parsedUpdatedAt ?? fallbackUpdatedAt).toUtc();
    final entriesJson = json['entries'] as List<dynamic>? ?? [];
    final documentsJson = json['documents'] as List<dynamic>? ?? [];
    return VaultData(
      version: json['version'] as int? ?? VaultConstants.currentDataVersion,
      updatedAt: updatedAt,
      entries: entriesJson
          .map(
            (entry) => VaultEntry.fromJson(
              entry as Map<String, dynamic>,
              fallbackUpdatedAt: updatedAt,
            ),
          )
          .toList(),
      documents: documentsJson
          .whereType<Map>()
          .map(
            (document) => VaultDocumentMetadata.fromJson(
              Map<String, dynamic>.from(document),
              fallbackDate: updatedAt,
            ),
          )
          .toList(),
    );
  }

  VaultData copyWith({
    int? version,
    DateTime? updatedAt,
    List<VaultEntry>? entries,
    List<VaultDocumentMetadata>? documents,
  }) {
    return VaultData(
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      entries: entries ?? this.entries,
      documents: documents ?? this.documents,
    );
  }
}
