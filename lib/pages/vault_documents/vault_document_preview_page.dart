import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/design_tokens.dart';
import '../../services/documents/pdf_preview_renderer.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/vault_document_service.dart';
import '../../services/vault/vault_repository.dart';
import '../../services/vault/vault_state.dart';
import '../../widgets/app_surface.dart';
import '../unlock/unlock_page.dart';

class VaultDocumentPreviewPage extends ConsumerStatefulWidget {
  static const subPath = 'documents/:documentId/preview';
  static const routeName = 'vault-document-preview';

  const VaultDocumentPreviewPage({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<VaultDocumentPreviewPage> createState() =>
      _VaultDocumentPreviewPageState();
}

class _VaultDocumentPreviewPageState
    extends ConsumerState<VaultDocumentPreviewPage>
    with WidgetsBindingObserver {
  late final AutoLockController _autoLock;
  late Future<VaultDocumentPreview> _previewFuture;
  VaultDocumentPreview? _loadedPreview;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoLock = AutoLockController(ref: ref, onTimeout: _lockAndExit);
    unawaited(_autoLock.restart());
    _previewFuture = _loadPreview();
  }

  @override
  void dispose() {
    _deleteTemporaryPreviewFile();
    WidgetsBinding.instance.removeObserver(this);
    _autoLock.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_autoLock.handleLifecycle(state));
  }

  void _lockAndExit() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sessão bloqueada.')));
    context.go(UnlockPage.routePath);
  }

  Future<VaultDocumentPreview> _loadPreview() async {
    final preview = await ref
        .read(vaultProvider.notifier)
        .previewDocument(widget.documentId);
    _loadedPreview = preview;
    return preview;
  }

  void _deleteTemporaryPreviewFile() {
    final path = _loadedPreview?.temporaryFilePath;
    if (path == null || path.trim().isEmpty) return;
    unawaited(
      File(path).delete().catchError((_) {
        return File(path);
      }),
    );
  }

  Future<void> _export(VaultDocumentPreview preview) async {
    await _autoLock.refreshTimeout();
    if (_exporting) return;
    await _autoLock.runWithLifecycleLockSuspended(() async {
      final destinationPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar documento',
        fileName: preview.document.fileName,
      );
      if (destinationPath == null || destinationPath.trim().isEmpty) return;
      if (!mounted) return;
      setState(() => _exporting = true);
      try {
        await ref
            .read(vaultProvider.notifier)
            .exportDocument(preview.document.id, destinationPath);
        if (!mounted) return;
        _showSnack('Documento exportado com sucesso.');
      } on VaultAuthException catch (e) {
        if (!mounted) return;
        _showSnack(e.message);
      } catch (_) {
        if (!mounted) return;
        _showSnack('Não foi possível exportar o documento.');
      } finally {
        if (mounted) setState(() => _exporting = false);
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: const Text('Visualizar documento'),
        backgroundColor: tokens.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_autoLock.restart()),
        onPanDown: (_) => unawaited(_autoLock.restart()),
        child: FutureBuilder<VaultDocumentPreview>(
          future: _previewFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _PreviewNotice(
                title: 'Não foi possível pré-visualizar o documento.',
                message: 'Exporta o documento para o abrir fora do cofre.',
                onExport: null,
              );
            }
            final preview = snapshot.data!;
            return Stack(
              children: [
                _PreviewContent(
                  preview: preview,
                  onExport: () => _export(preview),
                ),
                if (_exporting) const LinearProgressIndicator(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.preview, required this.onExport});

  final VaultDocumentPreview preview;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    switch (preview.kind) {
      case VaultDocumentPreviewKind.text:
        return _TextPreview(
          fileName: preview.document.fileName,
          text: preview.text ?? '',
        );
      case VaultDocumentPreviewKind.image:
        final bytes = preview.bytes;
        if (bytes == null || bytes.isEmpty) {
          return _PreviewNotice(
            title: 'Não foi possível pré-visualizar a imagem.',
            message: 'Exporta o documento para o abrir fora do cofre.',
            onExport: onExport,
          );
        }
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
        );
      case VaultDocumentPreviewKind.pdf:
        final bytes = preview.bytes;
        final filePath = preview.temporaryFilePath;
        if ((bytes == null || bytes.isEmpty) &&
            (filePath == null || filePath.trim().isEmpty)) {
          return _PreviewNotice(
            title: 'Não foi possível pré-visualizar o PDF.',
            message: 'Exporta o documento para o abrir fora do cofre.',
            onExport: onExport,
          );
        }
        return _PdfPreview(
          bytes: bytes,
          filePath: filePath,
          onExport: onExport,
        );
      case VaultDocumentPreviewKind.docx:
        return _PreviewNotice(
          title: preview.document.fileName,
          message: 'Não foi possível pré-visualizar este documento Word.',
          onExport: onExport,
        );
      case VaultDocumentPreviewKind.unsupported:
      case VaultDocumentPreviewKind.tooLarge:
        return _PreviewNotice(
          title: preview.document.fileName,
          message:
              preview.message ??
              'Este tipo de documento ainda não tem pré-visualização.',
          onExport: onExport,
        );
    }
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.fileName, required this.text});

  final String fileName;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          fileName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        AppSurface(
          elevated: false,
          padding: const EdgeInsets.all(14),
          child: SelectableText(
            text,
            style: TextStyle(
              color: tokens.textPrimary,
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _PdfPreview extends ConsumerStatefulWidget {
  const _PdfPreview({
    required this.bytes,
    required this.filePath,
    required this.onExport,
  });

  final Uint8List? bytes;
  final String? filePath;
  final VoidCallback onExport;

  @override
  ConsumerState<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends ConsumerState<_PdfPreview> {
  late final Future<List<Uint8List>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _pagesFuture = ref
        .read(pdfPreviewRendererProvider)
        .renderPdf(bytes: widget.bytes, filePath: widget.filePath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Uint8List>>(
      future: _pagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final pages = snapshot.data ?? const <Uint8List>[];
        if (snapshot.hasError || pages.isEmpty) {
          return _PreviewNotice(
            title: 'Não foi possível pré-visualizar o PDF.',
            message: 'Exporta o documento para o abrir fora do cofre.',
            onExport: widget.onExport,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: pages.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Image.memory(pages[index], fit: BoxFit.fitWidth),
            );
          },
        );
      },
    );
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({
    required this.title,
    required this.message,
    required this.onExport,
  });

  final String title;
  final String message;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppSurface(
          elevated: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_off_outlined,
                color: tokens.textMuted,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.textSecondary, height: 1.35),
              ),
              if (onExport != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Exportar documento'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
