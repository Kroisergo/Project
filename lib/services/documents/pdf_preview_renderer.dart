import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PdfPreviewRenderer {
  PdfPreviewRenderer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('encryvault/pdf_preview');

  final MethodChannel _channel;

  Future<List<Uint8List>> renderPdf({
    Uint8List? bytes,
    String? filePath,
    int maxPages = 12,
    int targetWidth = 1200,
  }) async {
    if ((bytes == null || bytes.isEmpty) &&
        (filePath == null || filePath.trim().isEmpty)) {
      throw ArgumentError('PDF bytes or filePath must be provided.');
    }
    final args = <String, Object?>{
      'maxPages': maxPages,
      'targetWidth': targetWidth,
    };
    if (bytes != null && bytes.isNotEmpty) {
      args['bytes'] = bytes;
    }
    if (filePath != null && filePath.trim().isNotEmpty) {
      args['filePath'] = filePath;
      args['deleteAfterRender'] = true;
    }
    final pages = await _channel.invokeMethod<List<dynamic>>('renderPdf', args);
    return (pages ?? const <dynamic>[]).whereType<Uint8List>().toList(
      growable: false,
    );
  }
}

final pdfPreviewRendererProvider = Provider<PdfPreviewRenderer>((ref) {
  return PdfPreviewRenderer();
});
