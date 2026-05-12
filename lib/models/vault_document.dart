class VaultDocumentChunkMetadata {
  final int index;
  final int offset;
  final int encryptedSize;
  final int plainSize;
  final String nonceB64;

  const VaultDocumentChunkMetadata({
    required this.index,
    required this.offset,
    required this.encryptedSize,
    required this.plainSize,
    required this.nonceB64,
  });

  VaultDocumentChunkMetadata copyWith({
    int? index,
    int? offset,
    int? encryptedSize,
    int? plainSize,
    String? nonceB64,
  }) {
    return VaultDocumentChunkMetadata(
      index: index ?? this.index,
      offset: offset ?? this.offset,
      encryptedSize: encryptedSize ?? this.encryptedSize,
      plainSize: plainSize ?? this.plainSize,
      nonceB64: nonceB64 ?? this.nonceB64,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'offset': offset,
      'encryptedSize': encryptedSize,
      'plainSize': plainSize,
      'nonce': nonceB64,
    };
  }

  factory VaultDocumentChunkMetadata.fromJson(Map<String, dynamic> json) {
    return VaultDocumentChunkMetadata(
      index: _intFromJson(json['index']),
      offset: _intFromJson(json['offset']),
      encryptedSize: _intFromJson(json['encryptedSize']),
      plainSize: _intFromJson(json['plainSize']),
      nonceB64: json['nonce'] as String? ?? '',
    );
  }
}

class VaultDocumentMetadata {
  final String id;
  final String fileName;
  final String extension;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int chunkSize;
  final List<VaultDocumentChunkMetadata> chunks;

  const VaultDocumentMetadata({
    required this.id,
    required this.fileName,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.chunkSize,
    required this.chunks,
  });

  bool get isDeleted => deletedAt != null;

  VaultDocumentMetadata copyWith({
    String? id,
    String? fileName,
    String? extension,
    String? mimeType,
    int? sizeBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? chunkSize,
    List<VaultDocumentChunkMetadata>? chunks,
  }) {
    return VaultDocumentMetadata(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      extension: extension ?? this.extension,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      chunkSize: chunkSize ?? this.chunkSize,
      chunks: chunks ?? this.chunks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'extension': extension,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      'chunkSize': chunkSize,
      'chunks': chunks.map((chunk) => chunk.toJson()).toList(),
    };
  }

  factory VaultDocumentMetadata.fromJson(
    Map<String, dynamic> json, {
    required DateTime fallbackDate,
  }) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    final deletedAt = DateTime.tryParse(json['deletedAt'] as String? ?? '');
    final chunksJson = json['chunks'];
    return VaultDocumentMetadata(
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      extension: json['extension'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      sizeBytes: _intFromJson(json['sizeBytes']),
      createdAt: (createdAt ?? fallbackDate).toUtc(),
      updatedAt: (updatedAt ?? createdAt ?? fallbackDate).toUtc(),
      deletedAt: deletedAt?.toUtc(),
      chunkSize: _intFromJson(json['chunkSize']),
      chunks: chunksJson is List
          ? chunksJson
                .whereType<Map>()
                .map(
                  (chunk) => VaultDocumentChunkMetadata.fromJson(
                    Map<String, dynamic>.from(chunk),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

int _intFromJson(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
