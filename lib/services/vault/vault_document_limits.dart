import 'dart:io';

class VaultDocumentLimits {
  static const int defaultChunkSize = 2 * 1024 * 1024;
  static const int maxPreviewBytes = 10 * 1024 * 1024;
  static const int maxDocumentBytes = 100 * 1024 * 1024;
  static const int maxTotalDocumentBytes = 500 * 1024 * 1024;

  const VaultDocumentLimits._();

  static Future<void> validateFile({
    required File file,
    required int currentTotalBytes,
  }) async {
    if (!await file.exists()) {
      throw const VaultDocumentLimitException('Ficheiro inexistente.');
    }
    final size = await file.length();
    if (size <= 0) {
      throw const VaultDocumentLimitException('Ficheiro vazio.');
    }
    if (size > maxDocumentBytes) {
      throw const VaultDocumentLimitException('Ficheiro demasiado grande.');
    }
    if (currentTotalBytes + size > maxTotalDocumentBytes) {
      throw const VaultDocumentLimitException(
        'O cofre já atingiu o limite recomendado para documentos.',
      );
    }
  }
}

class VaultDocumentLimitException implements Exception {
  final String message;

  const VaultDocumentLimitException(this.message);

  @override
  String toString() => message;
}
