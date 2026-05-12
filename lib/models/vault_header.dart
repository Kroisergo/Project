class VaultHeader {
  final String magic;
  final int formatVersion;
  final String cipherId;
  final String kdf;
  final int memLimit;
  final int opsLimit;
  final int parallelism;
  final String saltB64;
  final String? container;
  final String? subkeyKdf;
  final String? vaultIdB64;
  final int? defaultChunkSize;

  const VaultHeader({
    required this.magic,
    required this.formatVersion,
    required this.cipherId,
    required this.kdf,
    required this.memLimit,
    required this.opsLimit,
    required this.parallelism,
    required this.saltB64,
    this.container,
    this.subkeyKdf,
    this.vaultIdB64,
    this.defaultChunkSize,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'magic': magic,
      'formatVersion': formatVersion,
      if (container != null) 'container': container,
      'cipherId': cipherId,
      'kdf': kdf,
      if (subkeyKdf != null) 'subkeyKdf': subkeyKdf,
      'memLimit': memLimit,
      'opsLimit': opsLimit,
      'parallelism': parallelism,
      'salt': saltB64,
      if (vaultIdB64 != null) 'vaultId': vaultIdB64,
      if (defaultChunkSize != null) 'defaultChunkSize': defaultChunkSize,
    };
    return json;
  }

  factory VaultHeader.fromJson(Map<String, dynamic> json) {
    return VaultHeader(
      magic: json['magic'] as String,
      formatVersion: json['formatVersion'] as int,
      cipherId: json['cipherId'] as String,
      kdf: json['kdf'] as String,
      memLimit: json['memLimit'] as int,
      opsLimit: json['opsLimit'] as int,
      parallelism: json['parallelism'] as int,
      saltB64: json['salt'] as String,
      container: json['container'] as String?,
      subkeyKdf: json['subkeyKdf'] as String?,
      vaultIdB64: json['vaultId'] as String?,
      defaultChunkSize: json['defaultChunkSize'] as int?,
    );
  }

  VaultHeader copyWith({
    String? magic,
    int? formatVersion,
    String? cipherId,
    String? kdf,
    int? memLimit,
    int? opsLimit,
    int? parallelism,
    String? saltB64,
    String? container,
    String? subkeyKdf,
    String? vaultIdB64,
    int? defaultChunkSize,
  }) {
    return VaultHeader(
      magic: magic ?? this.magic,
      formatVersion: formatVersion ?? this.formatVersion,
      cipherId: cipherId ?? this.cipherId,
      kdf: kdf ?? this.kdf,
      memLimit: memLimit ?? this.memLimit,
      opsLimit: opsLimit ?? this.opsLimit,
      parallelism: parallelism ?? this.parallelism,
      saltB64: saltB64 ?? this.saltB64,
      container: container ?? this.container,
      subkeyKdf: subkeyKdf ?? this.subkeyKdf,
      vaultIdB64: vaultIdB64 ?? this.vaultIdB64,
      defaultChunkSize: defaultChunkSize ?? this.defaultChunkSize,
    );
  }
}
