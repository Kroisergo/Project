import '../utils/constants.dart';
import 'vault_data.dart';
import 'vault_document.dart';
import 'vault_entry.dart';

class VaultManifestV3 {
  final int manifestVersion;
  final int dataVersion;
  final DateTime updatedAt;
  final List<VaultEntry> entries;
  final List<VaultDocumentMetadata> documents;

  const VaultManifestV3({
    required this.manifestVersion,
    required this.dataVersion,
    required this.updatedAt,
    required this.entries,
    required this.documents,
  });

  factory VaultManifestV3.fromVaultData(VaultData data) {
    return VaultManifestV3(
      manifestVersion: 1,
      dataVersion: data.version,
      updatedAt: data.updatedAt,
      entries: data.entries,
      documents: data.documents,
    );
  }

  VaultData toVaultData() {
    return VaultData(
      version: dataVersion,
      updatedAt: updatedAt,
      entries: entries,
      documents: documents,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'manifestVersion': manifestVersion,
      'dataVersion': dataVersion,
      'updatedAt': updatedAt.toIso8601String(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'documents': documents.map((document) => document.toJson()).toList(),
    };
  }

  factory VaultManifestV3.fromJson(Map<String, dynamic> json) {
    final fallbackUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
      0,
      isUtc: true,
    );
    final parsedUpdatedAt = DateTime.tryParse(
      json['updatedAt'] as String? ?? '',
    );
    final updatedAt = (parsedUpdatedAt ?? fallbackUpdatedAt).toUtc();
    final entriesJson = json['entries'] as List<dynamic>? ?? [];
    final documentsJson = json['documents'] as List<dynamic>? ?? [];
    return VaultManifestV3(
      manifestVersion: json['manifestVersion'] as int? ?? 1,
      dataVersion: json['dataVersion'] as int? ?? VaultConstants.v3DataVersion,
      updatedAt: updatedAt,
      entries: entriesJson
          .whereType<Map>()
          .map(
            (entry) => VaultEntry.fromJson(
              Map<String, dynamic>.from(entry),
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
}
