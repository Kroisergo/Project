import 'dart:convert';
import 'dart:typed_data';

class VaultFooterV3 {
  static const int length = 64;
  static const int aadLength = 56;
  static const int version = 1;
  static final Uint8List magic = Uint8List.fromList(utf8.encode('EVF3'));

  final int manifestOffset;
  final int manifestEncryptedSize;
  final int manifestPlainSize;
  final Uint8List manifestNonce;
  final int flags;

  const VaultFooterV3({
    required this.manifestOffset,
    required this.manifestEncryptedSize,
    required this.manifestPlainSize,
    required this.manifestNonce,
    this.flags = 0,
  });

  Uint8List toBytes() {
    if (manifestNonce.length != 24) {
      throw const FormatException('Nonce do manifest inválido.');
    }
    final bytes = Uint8List(length);
    bytes.setRange(0, 4, magic);
    final data = ByteData.sublistView(bytes);
    data.setUint16(4, version, Endian.big);
    data.setUint16(6, flags, Endian.big);
    data.setUint64(8, manifestOffset, Endian.big);
    data.setUint64(16, manifestEncryptedSize, Endian.big);
    data.setUint64(24, manifestPlainSize, Endian.big);
    bytes.setRange(32, 56, manifestNonce);
    return bytes;
  }

  Uint8List aadBytes() {
    return Uint8List.sublistView(toBytes(), 0, aadLength);
  }

  factory VaultFooterV3.fromBytes(Uint8List bytes) {
    if (bytes.length != length) {
      throw const FormatException('Footer v3 inválido.');
    }
    for (var i = 0; i < magic.length; i += 1) {
      if (bytes[i] != magic[i]) {
        throw const FormatException('Footer v3 inválido.');
      }
    }
    final data = ByteData.sublistView(bytes);
    if (data.getUint16(4, Endian.big) != version) {
      throw const FormatException('Versão do footer v3 inválida.');
    }
    for (var i = aadLength; i < length; i += 1) {
      if (bytes[i] != 0) {
        throw const FormatException('Footer v3 inválido.');
      }
    }
    return VaultFooterV3(
      flags: data.getUint16(6, Endian.big),
      manifestOffset: data.getUint64(8, Endian.big),
      manifestEncryptedSize: data.getUint64(16, Endian.big),
      manifestPlainSize: data.getUint64(24, Endian.big),
      manifestNonce: Uint8List.fromList(bytes.sublist(32, 56)),
    );
  }
}
