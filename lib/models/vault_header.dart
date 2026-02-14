class VaultHeader {
  final String magic;
  final int formatVersion;
  final String cipherId;
  final String kdf;
  final int memLimit;
  final int opsLimit;
  final int parallelism;
  final String saltB64;
  final String nonceB64;

  const VaultHeader({
    required this.magic,
    required this.formatVersion,
    required this.cipherId,
    required this.kdf,
    required this.memLimit,
    required this.opsLimit,
    required this.parallelism,
    required this.saltB64,
    required this.nonceB64,
  });

  Map<String, dynamic> toJson() {
    return {
      'magic': magic,
      'formatVersion': formatVersion,
      'cipherId': cipherId,
      'kdf': kdf,
      'memLimit': memLimit,
      'opsLimit': opsLimit,
      'parallelism': parallelism,
      'salt': saltB64,
      'nonce': nonceB64,
    };
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
      nonceB64: json['nonce'] as String,
    );
  }
}
