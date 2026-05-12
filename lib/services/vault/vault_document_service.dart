import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../../models/vault_container_format.dart';
import '../../models/vault_data.dart';
import '../../models/vault_document.dart';
import '../../models/vault_header.dart';
import 'vault_document_limits.dart';
import 'vault_repository.dart';
import 'vault_state.dart';

enum VaultDocumentPreviewKind { text, image, pdf, docx, unsupported, tooLarge }

class VaultDocumentPreview {
  final VaultDocumentPreviewKind kind;
  final VaultDocumentMetadata document;
  final String? text;
  final Uint8List? bytes;
  final String? temporaryFilePath;
  final String? message;

  const VaultDocumentPreview({
    required this.kind,
    required this.document,
    this.text,
    this.bytes,
    this.temporaryFilePath,
    this.message,
  });
}

class VaultDocumentServiceResult {
  final VaultHeader header;
  final Uint8List headerBytes;
  final VaultData data;
  final VaultContainerFormat format;
  final String? fileName;
  final String? documentId;

  const VaultDocumentServiceResult({
    required this.header,
    required this.headerBytes,
    required this.data,
    required this.format,
    required this.fileName,
    this.documentId,
  });
}

class VaultDocumentService {
  VaultDocumentService({required this.repository, Uuid uuid = const Uuid()})
    : _uuid = uuid;

  final VaultRepository repository;
  final Uuid _uuid;

  Future<String> addFromFile({
    required VaultState current,
    required String sourcePath,
    void Function(VaultDocumentMetadata document)? onPendingDocument,
  }) async {
    final result = await addFromFileWithResult(
      current: current,
      sourcePath: sourcePath,
      onPendingDocument: onPendingDocument,
    );
    return result.documentId ?? '';
  }

  Future<VaultDocumentServiceResult> addFromFileWithResult({
    required VaultState current,
    required String sourcePath,
    void Function(VaultDocumentMetadata document)? onPendingDocument,
  }) async {
    _requireUnlocked(current);
    final source = File(sourcePath);
    final sourceFileName = p.basename(source.path);
    final documentId = _uuid.v4();
    final totalBytes = current.data!.documents.fold<int>(
      0,
      (sum, document) => sum + document.sizeBytes,
    );
    await VaultDocumentLimits.validateFile(
      file: source,
      currentTotalBytes: totalBytes,
    );
    final now = DateTime.now().toUtc();
    onPendingDocument?.call(
      VaultDocumentMetadata(
        id: documentId,
        fileName: sourceFileName,
        extension: _extensionFor(sourceFileName),
        mimeType: lookupMimeType(source.path) ?? 'application/octet-stream',
        sizeBytes: await source.length(),
        createdAt: now,
        updatedAt: now,
        chunkSize: VaultDocumentLimits.defaultChunkSize,
        chunks: const [],
      ),
    );
    final result = await repository.addDocument(
      currentHeader: current.header!,
      currentHeaderBytes: current.headerBytes,
      currentData: current.data!,
      key: current.key!,
      fileName: current.fileName,
      documentId: documentId,
      sourcePath: source.path,
      sourceFileName: sourceFileName,
      extension: _extensionFor(sourceFileName),
      mimeType: lookupMimeType(source.path) ?? 'application/octet-stream',
    );
    return VaultDocumentServiceResult(
      header: result.header,
      headerBytes: result.headerBytes,
      data: result.data,
      format: VaultContainerFormat.v3,
      fileName: current.fileName,
      documentId: result.documentId,
    );
  }

  Future<void> exportDocument({
    required VaultState current,
    required String documentId,
    required String destinationPath,
  }) async {
    _requireUnlocked(current);
    final document = current.data!.activeDocuments.singleWhere(
      (document) => document.id == documentId,
    );
    await repository.exportDocument(
      header: current.header!,
      key: current.key!,
      document: document,
      fileName: current.fileName,
      destinationPath: destinationPath,
    );
  }

  Future<VaultDocumentPreview> previewDocument({
    required VaultState current,
    required String documentId,
  }) async {
    _requireUnlocked(current);
    final document = current.data!.activeDocuments.singleWhere(
      (document) => document.id == documentId,
    );
    final previewKind = _previewKindFor(document);
    if (previewKind == VaultDocumentPreviewKind.unsupported) {
      return VaultDocumentPreview(
        kind: VaultDocumentPreviewKind.unsupported,
        document: document,
        message: 'Este tipo de documento ainda não tem pré-visualização.',
      );
    }
    if (previewKind == VaultDocumentPreviewKind.pdf) {
      final temporaryFile = File(
        p.join(
          Directory.systemTemp.path,
          'encryvault-pdf-preview-${_uuid.v4()}.pdf',
        ),
      );
      try {
        await repository.exportDocument(
          header: current.header!,
          key: current.key!,
          document: document,
          fileName: current.fileName,
          destinationPath: temporaryFile.path,
        );
        return VaultDocumentPreview(
          kind: VaultDocumentPreviewKind.pdf,
          document: document,
          temporaryFilePath: temporaryFile.path,
        );
      } catch (_) {
        if (await temporaryFile.exists()) {
          await temporaryFile.delete();
        }
        return VaultDocumentPreview(
          kind: VaultDocumentPreviewKind.unsupported,
          document: document,
          message: 'Não foi possível pré-visualizar o PDF.',
        );
      }
    }
    if (document.sizeBytes > VaultDocumentLimits.maxPreviewBytes) {
      return VaultDocumentPreview(
        kind: VaultDocumentPreviewKind.tooLarge,
        document: document,
        message:
            'Documento demasiado grande para pré-visualização. Exporta o documento para o abrir fora do cofre.',
      );
    }

    final bytes = await repository.readDocument(
      header: current.header!,
      key: current.key!,
      document: document,
      fileName: current.fileName,
      maxBytes: VaultDocumentLimits.maxPreviewBytes,
    );
    if (previewKind == VaultDocumentPreviewKind.text) {
      try {
        final text = utf8.decode(bytes, allowMalformed: false);
        bytes.fillRange(0, bytes.length, 0);
        return VaultDocumentPreview(
          kind: VaultDocumentPreviewKind.text,
          document: document,
          text: text,
        );
      } catch (_) {
        bytes.fillRange(0, bytes.length, 0);
        return VaultDocumentPreview(
          kind: VaultDocumentPreviewKind.unsupported,
          document: document,
          message: 'Não foi possível pré-visualizar este texto.',
        );
      }
    }
    if (previewKind == VaultDocumentPreviewKind.docx) {
      try {
        final text = _extractDocxText(bytes);
        bytes.fillRange(0, bytes.length, 0);
        return VaultDocumentPreview(
          kind: VaultDocumentPreviewKind.text,
          document: document,
          text: text,
        );
      } catch (_) {
        bytes.fillRange(0, bytes.length, 0);
        return VaultDocumentPreview(
          kind: VaultDocumentPreviewKind.unsupported,
          document: document,
          message: 'Não foi possível pré-visualizar este documento Word.',
        );
      }
    }
    return VaultDocumentPreview(
      kind: VaultDocumentPreviewKind.image,
      document: document,
      bytes: bytes,
    );
  }

  Future<void> deleteDocument({
    required VaultState current,
    required String documentId,
  }) async {
    await deleteDocumentWithResult(current: current, documentId: documentId);
  }

  Future<VaultDocumentServiceResult> deleteDocumentWithResult({
    required VaultState current,
    required String documentId,
  }) async {
    _requireUnlocked(current);
    final result = await repository.deleteDocument(
      header: current.header!,
      headerBytes: current.headerBytes,
      data: current.data!,
      key: current.key!,
      fileName: current.fileName,
      documentId: documentId,
    );
    return VaultDocumentServiceResult(
      header: result.header,
      headerBytes: result.headerBytes,
      data: result.data,
      format: VaultContainerFormat.v3,
      fileName: current.fileName,
      documentId: result.documentId,
    );
  }

  String _extensionFor(String fileName) {
    return p.extension(fileName).replaceFirst('.', '').toLowerCase();
  }

  VaultDocumentPreviewKind _previewKindFor(VaultDocumentMetadata document) {
    final extension = document.extension.toLowerCase();
    final mimeType = document.mimeType.toLowerCase();
    if (extension == 'pdf' || mimeType == 'application/pdf') {
      return VaultDocumentPreviewKind.pdf;
    }
    if (_docxExtensions.contains(extension) ||
        _docxMimeTypes.contains(mimeType)) {
      return VaultDocumentPreviewKind.docx;
    }
    if (_textExtensions.contains(extension) ||
        mimeType.startsWith('text/') ||
        _textMimeTypes.contains(mimeType)) {
      return VaultDocumentPreviewKind.text;
    }
    if (_imageExtensions.contains(extension) || mimeType.startsWith('image/')) {
      return VaultDocumentPreviewKind.image;
    }
    return VaultDocumentPreviewKind.unsupported;
  }

  String _extractDocxText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final documentXml = archive.files
        .where((file) => file.name == 'word/document.xml')
        .map((file) => utf8.decode(file.content))
        .firstOrNull;
    if (documentXml == null || documentXml.trim().isEmpty) {
      throw const FormatException('DOCX sem conteúdo de documento.');
    }

    final document = XmlDocument.parse(documentXml);
    final paragraphs = document
        .findAllElements('p', namespace: '*')
        .map((paragraph) {
          return paragraph
              .findAllElements('t', namespace: '*')
              .map((textNode) => textNode.innerText)
              .join();
        })
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (paragraphs.isNotEmpty) {
      return paragraphs.join('\n');
    }

    final text = document
        .findAllElements('t', namespace: '*')
        .map((textNode) => textNode.innerText)
        .join('\n')
        .trim();
    if (text.isEmpty) {
      throw const FormatException('DOCX sem texto legível.');
    }
    return text;
  }

  void _requireUnlocked(VaultState current) {
    if (!current.isUnlocked) {
      throw const VaultLoadException('Sessão bloqueada.');
    }
  }
}

const _textExtensions = {
  'txt',
  'csv',
  'json',
  'md',
  'markdown',
  'log',
  'xml',
  'yaml',
  'yml',
  'html',
  'css',
  'js',
  'ts',
  'dart',
};

const _textMimeTypes = {
  'application/json',
  'application/xml',
  'application/javascript',
  'application/x-yaml',
};

const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

const _docxExtensions = {'docx'};

const _docxMimeTypes = {
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
};

final vaultDocumentServiceProvider = Provider<VaultDocumentService>((ref) {
  return VaultDocumentService(repository: ref.read(vaultRepositoryProvider));
});
