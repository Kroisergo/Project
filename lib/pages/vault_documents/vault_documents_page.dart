import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/design_tokens.dart';
import '../../models/app_design_mode.dart';
import '../../models/vault_document.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/vault_document_limits.dart';
import '../../services/vault/vault_repository.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/file_size_labels.dart';
import '../../widgets/app_surface.dart';
import '../unlock/unlock_page.dart';
import 'widgets/vault_document_card.dart';

class VaultDocumentsPage extends ConsumerStatefulWidget {
  static const subPath = 'documents';
  static const routeName = 'vault-documents';

  const VaultDocumentsPage({super.key});

  @override
  ConsumerState<VaultDocumentsPage> createState() => _VaultDocumentsPageState();
}

class _VaultDocumentsPageState extends ConsumerState<VaultDocumentsPage>
    with WidgetsBindingObserver {
  late final AutoLockController _autoLock;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoLock = AutoLockController(ref: ref, onTimeout: _lockAndExit);
    unawaited(_autoLock.restart());
  }

  @override
  void dispose() {
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

  Future<void> _addDocument() async {
    await _autoLock.refreshTimeout();
    if (!mounted) return;
    final state = ref.read(vaultProvider);
    if (!state.isUnlocked || _busy) return;

    await _autoLock.runWithLifecycleLockSuspended(() async {
      final picked = await FilePicker.platform.pickFiles(withData: false);
      final path = picked?.files.single.path;
      if (path == null || path.trim().isEmpty) return;
      if (!mounted) return;
      if (!ref.read(vaultProvider).isUnlocked) return;

      setState(() => _busy = true);
      try {
        final documentId = await ref
            .read(vaultProvider.notifier)
            .addDocumentFromFile(path);
        if (documentId.isEmpty) return;
        if (!mounted) return;
        _showSnack('Documento adicionado ao cofre cifrado.');
      } on VaultDocumentLimitException catch (e) {
        if (!mounted) return;
        _showSnack(e.message);
      } catch (_) {
        if (!mounted) return;
        _showSnack('Não foi possível adicionar o documento.');
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
      }
    });
  }

  Future<void> _exportDocument(VaultDocumentMetadata document) async {
    await _autoLock.refreshTimeout();
    if (_busy) return;
    await _autoLock.runWithLifecycleLockSuspended(() async {
      final destinationPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar documento',
        fileName: document.fileName,
      );
      if (destinationPath == null || destinationPath.trim().isEmpty) return;
      if (!mounted) return;
      if (!ref.read(vaultProvider).isUnlocked) return;

      setState(() => _busy = true);
      try {
        await ref
            .read(vaultProvider.notifier)
            .exportDocument(document.id, destinationPath);
        if (!mounted) return;
        _showSnack('Documento exportado com sucesso.');
      } on VaultAuthException catch (e) {
        if (!mounted) return;
        _showSnack(e.message);
      } catch (_) {
        if (!mounted) return;
        _showSnack('Não foi possível exportar o documento.');
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
      }
    });
  }

  Future<void> _deleteDocument(VaultDocumentMetadata document) async {
    await _autoLock.refreshTimeout();
    if (!mounted) return;
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar documento?'),
        content: Text(
          'O documento "${document.fileName}" será removido do cofre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar documento'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!ref.read(vaultProvider).isUnlocked) return;

    await _autoLock.runWithLifecycleLockSuspended(() async {
      setState(() => _busy = true);
      try {
        await ref.read(vaultProvider.notifier).deleteDocument(document.id);
        if (!mounted) return;
        _showSnack('Documento eliminado.');
      } catch (_) {
        if (!mounted) return;
        _showSnack('Não foi possível eliminar o documento.');
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
      }
    });
  }

  Future<void> _showDetails(VaultDocumentMetadata document) {
    unawaited(_autoLock.restart());
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final tokens = EncryVaultTheme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalhes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _DetailRow(label: 'Nome', value: document.fileName),
                _DetailRow(
                  label: 'Tipo',
                  value: document.extension.isEmpty
                      ? document.mimeType
                      : '.${document.extension}',
                ),
                _DetailRow(
                  label: 'Tamanho',
                  value: formatFileSize(document.sizeBytes),
                ),
                _DetailRow(
                  label: 'Adicionado',
                  value: _formatDate(document.createdAt),
                ),
                _DetailRow(
                  label: 'Atualizado',
                  value: _formatDate(document.updatedAt),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final state = ref.watch(vaultProvider);
    final documents = state.data?.documents ?? const <VaultDocumentMetadata>[];
    final isClassic = tokens.designMode == AppDesignMode.classic;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: const Text('Documentos sigilosos'),
        backgroundColor: tokens.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Adicionar documento',
            onPressed: _busy ? null : _addDocument,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_autoLock.restart()),
        onPanDown: (_) => unawaited(_autoLock.restart()),
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  AppSurface(
                    elevated: !isClassic,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.enhanced_encryption_outlined,
                          color: tokens.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Este documento ficará guardado dentro do cofre cifrado. Evita adicionar ficheiros demasiado grandes.',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (documents.isEmpty)
                    _EmptyDocumentsCard(onAdd: _busy ? null : _addDocument)
                  else
                    ...documents.map(
                      (document) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: VaultDocumentCard(
                          document: document,
                          onExport: () => _exportDocument(document),
                          onDelete: () => _deleteDocument(document),
                          onDetails: () => _showDetails(document),
                        ),
                      ),
                    ),
                ],
              ),
              if (_busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: tokens.background.withValues(alpha: 0.62),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addDocument,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar documento'),
      ),
    );
  }
}

class _EmptyDocumentsCard extends StatelessWidget {
  const _EmptyDocumentsCard({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    return AppSurface(
      elevated: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.folder_off_outlined, color: tokens.textMuted, size: 36),
          const SizedBox(height: 12),
          Text(
            'Sem documentos sigilosos',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adiciona documentos quando precisares de guardar ficheiros sensíveis no cofre.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar documento'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(color: tokens.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
