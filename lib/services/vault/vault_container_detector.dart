import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../models/vault_container_format.dart';
import '../../models/vault_header.dart';
import '../../utils/constants.dart';
import '../storage/vault_file_service.dart';
import 'vault_repository.dart';

class VaultContainerInfo {
  final File file;
  final String fileName;
  final VaultContainerFormat format;
  final VaultHeader header;
  final Uint8List headerBytes;

  const VaultContainerInfo({
    required this.file,
    required this.fileName,
    required this.format,
    required this.header,
    required this.headerBytes,
  });
}

class VaultContainerDetector {
  VaultContainerDetector({required this.fileService});

  final VaultFileService fileService;

  Future<VaultContainerInfo> inspect({String? fileName}) async {
    final file = fileName == null || fileName.trim().isEmpty
        ? await fileService.defaultVaultFile()
        : await fileService.vaultFileForName(fileName);
    if (!await file.exists()) {
      throw const VaultLoadException('Cofre não encontrado.');
    }

    final raf = await file.open();
    try {
      final totalLen = await raf.length();
      if (totalLen < 4) {
        throw const VaultLoadException('Cabeçalho do cofre inválido.');
      }
      final headerLenBytes = await raf.read(4);
      if (headerLenBytes.length != 4) {
        throw const VaultLoadException('Cabeçalho do cofre inválido.');
      }
      final headerLen = ByteData.sublistView(
        Uint8List.fromList(headerLenBytes),
      ).getUint32(0, Endian.big);
      const maxHeaderLen = 1024 * 1024;
      if (headerLen == 0 ||
          headerLen > maxHeaderLen ||
          headerLen > totalLen - 4) {
        throw const VaultLoadException('Cabeçalho do cofre inválido.');
      }
      final headerBytes = Uint8List.fromList(await raf.read(headerLen));
      if (headerBytes.length != headerLen) {
        throw const VaultLoadException('Cabeçalho do cofre inválido.');
      }
      final decoded = jsonDecode(utf8.decode(headerBytes));
      if (decoded is! Map) {
        throw const VaultLoadException('Cabeçalho do cofre inválido.');
      }
      final header = VaultHeader.fromJson(Map<String, dynamic>.from(decoded));
      if (header.magic != VaultConstants.magic) {
        throw const VaultLoadException('Identificador do cofre inválido.');
      }
      if (header.formatVersion != VaultConstants.v3FormatVersion) {
        throw const VaultLoadException(
          'Cofre corrompido ou versão não suportada.',
        );
      }
      return VaultContainerInfo(
        file: file,
        fileName: p.basename(file.path),
        format: VaultContainerFormat.v3,
        header: header,
        headerBytes: headerBytes,
      );
    } on VaultLoadException {
      rethrow;
    } catch (_) {
      throw const VaultLoadException('Cabeçalho do cofre inválido.');
    } finally {
      await raf.close();
    }
  }
}
