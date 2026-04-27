import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/constants.dart';

class VaultFileService {
  VaultFileService({Directory? baseDir}) : _baseDir = baseDir;

  final Directory? _baseDir;

  Future<Directory> _vaultDirectory() async {
    final base = _baseDir;
    if (base != null) return base;
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }

  Future<File> defaultVaultFile() async {
    final dir = await _vaultDirectory();
    return File(p.join(dir.path, VaultConstants.defaultVaultName));
  }

  Future<File> vaultFileForName(String? name) async {
    final dir = await _vaultDirectory();
    final fileName = normalizeVaultName(name);
    return File(p.join(dir.path, fileName));
  }

  Future<bool> hasExistingVault({String? preferredName}) async {
    final preferred = preferredName == null || preferredName.trim().isEmpty ? null : preferredName;
    if (preferred != null) {
      final preferredFile = await vaultFileForName(preferred);
      return await preferredFile.exists();
    }
    final defaultFile = await defaultVaultFile();
    return await defaultFile.exists();
  }

  Future<File> writeVault({
    required File target,
    required Uint8List headerBytes,
    required Uint8List cipherBytes,
  }) async {
    final headerLen = ByteData(4)..setUint32(0, headerBytes.length, Endian.big);
    final tmp = File('${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    final raf = await tmp.open(mode: FileMode.write);
    await raf.writeFrom(headerLen.buffer.asUint8List());
    await raf.writeFrom(headerBytes);
    await raf.writeFrom(cipherBytes);
    await raf.flush();
    await raf.close();

    File? backup;
    try {
      if (await target.exists()) {
        backup = File('${target.path}.bak');
        if (await backup.exists()) {
          await backup.delete();
        }
        await target.rename(backup.path);
      }
      await tmp.rename(target.path);
      if (backup != null && await backup.exists()) {
        await backup.delete();
      }
    } catch (e) {
      if (backup != null && await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    } finally {
      if (await tmp.exists()) {
        await tmp.delete();
      }
    }
    return target;
  }

  Future<void> exportVaultTo(String destinationPath, {String? fileName}) async {
    final source = await vaultFileForName(fileName);
    if (!await source.exists()) {
      throw Exception('Nenhum cofre para exportar.');
    }
    final destFile = File(destinationPath);
    await destFile.parent.create(recursive: true);
    await destFile.writeAsBytes(await source.readAsBytes(), flush: true);
  }

  Future<void> importVaultFrom(String sourcePath, {String? targetFileName}) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw Exception('Ficheiro inexistente.');
    }
    await _validateVaultFileStructure(source);
    final target = await vaultFileForName(targetFileName);
    await target.writeAsBytes(await source.readAsBytes(), flush: true);
  }

  Future<void> _validateVaultFileStructure(File source) async {
    final raf = await source.open();
    try {
      final totalLen = await raf.length();
      if (totalLen < 4) {
        throw Exception('Ficheiro de cofre inválido ou corrompido.');
      }
      final headerLenBytes = await raf.read(4);
      if (headerLenBytes.length != 4) {
        throw Exception('Ficheiro de cofre inválido ou corrompido.');
      }
      final headerLen = ByteData.sublistView(
        Uint8List.fromList(headerLenBytes),
      ).getUint32(0, Endian.big);
      const maxHeaderLen = 1024 * 1024;
      if (headerLen == 0 ||
          headerLen > maxHeaderLen ||
          headerLen > totalLen - 4) {
        throw Exception('Ficheiro de cofre inválido ou corrompido.');
      }
      final headerBytes = Uint8List.fromList(await raf.read(headerLen));
      if (headerBytes.lengthInBytes != headerLen) {
        throw Exception('Ficheiro de cofre inválido ou corrompido.');
      }
      final decoded = jsonDecode(utf8.decode(headerBytes));
      if (decoded is! Map ||
          decoded['magic'] != VaultConstants.magic ||
          decoded['formatVersion'] != VaultConstants.formatVersion ||
          decoded['cipherId'] != VaultConstants.cipherId ||
          decoded['kdf'] != VaultConstants.kdfId) {
        throw Exception('Ficheiro de cofre inválido ou corrompido.');
      }
    } catch (_) {
      throw Exception('Ficheiro de cofre inválido ou corrompido.');
    } finally {
      await raf.close();
    }
  }

  String normalizeVaultName(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) {
      return VaultConstants.defaultVaultName;
    }
    final trimmed = rawName.trim();
    final withoutTrailing = trimmed.replaceAll(RegExp(r'[. ]+$'), '');
    final sanitized = withoutTrailing.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final baseName = p.basenameWithoutExtension(sanitized);
    const reserved = {
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9',
    };
    if (sanitized.isEmpty ||
        sanitized == '.' ||
        sanitized == '..' ||
        reserved.contains(sanitized.toUpperCase()) ||
        reserved.contains(baseName.toUpperCase())) {
      return VaultConstants.defaultVaultName;
    }
    if (p.extension(sanitized).toLowerCase() == VaultConstants.vaultExtension) {
      return sanitized;
    }
    return '$sanitized${VaultConstants.vaultExtension}';
  }
}
