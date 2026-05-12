import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/design_tokens.dart';
import '../../models/app_design_mode.dart';
import '../../models/vault_document.dart';
import '../../services/security/trash_pin_service.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/trash_retention_policy.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/file_size_labels.dart';
import '../../utils/time_labels.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/sensitive_action_confirmation.dart';
import '../unlock/unlock_page.dart';

class VaultDocumentTrashPage extends ConsumerStatefulWidget {
  static const subPath = 'document-trash';
  static const routeName = 'vault-document-trash';

  const VaultDocumentTrashPage({super.key});

  @override
  ConsumerState<VaultDocumentTrashPage> createState() =>
      _VaultDocumentTrashPageState();
}

class _VaultDocumentTrashPageState extends ConsumerState<VaultDocumentTrashPage>
    with WidgetsBindingObserver {
  final Set<String> _selectedIds = {};
  late final AutoLockController _autoLock;
  bool _busy = false;
  bool _checkingAccess = true;
  TrashRetentionOption _retention = TrashRetentionPolicy.defaultOption;

  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoLock = AutoLockController(ref: ref, onTimeout: _onLocked);
    _autoLock.restart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareTrash();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoLock.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _autoLock.handleLifecycle(state);
  }

  void _onLocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sessão bloqueada.')));
    context.go(UnlockPage.routePath);
  }

  Future<void> _prepareTrash() async {
    if (!mounted) return;
    final retention = await ref
        .read(preferencesServiceProvider)
        .getDocumentTrashRetentionOption();
    if (!mounted) return;
    setState(() => _retention = retention);

    final allowed = await _verifyPinIfNeeded(TrashPinAction.enter);
    if (!allowed) {
      if (!mounted) return;
      context.pop();
      return;
    }

    if (!mounted) return;
    setState(() => _checkingAccess = false);
    await ref
        .read(vaultProvider.notifier)
        .purgeExpiredDocumentTrash(retention: retention);
  }

  Future<bool> _verifyPinIfNeeded(TrashPinAction action) async {
    final service = ref.read(trashPinServiceProvider);
    if (!await service.isEnabled(action)) return true;
    if (!mounted) return false;

    final valid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DocumentTrashPinPromptDialog(
        action: action,
        verifier: (pin) => service.verify(action, pin),
      ),
    );
    return valid ?? false;
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _restore(String id) async {
    await _autoLock.restart();
    if (!mounted) return;
    if (!await _verifyPinIfNeeded(TrashPinAction.restore)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(vaultProvider.notifier).restoreDocument(id);
      if (!mounted) return;
      setState(() => _selectedIds.remove(id));
      _showSnack('Documento restaurado.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePermanently(Set<String> ids) async {
    if (ids.isEmpty) return;
    await _autoLock.restart();
    if (!mounted) return;
    final confirmed = await _confirmPermanentDelete(
      ids.length == 1
          ? 'Eliminar definitivamente este documento?'
          : 'Eliminar definitivamente ${ids.length} documentos?',
    );
    if (confirmed != true || !mounted) return;
    if (!await _verifyPinIfNeeded(TrashPinAction.delete)) return;
    if (!mounted) return;
    final allowed = await confirmSensitiveAction(
      context: context,
      ref: ref,
      title: 'Confirmar eliminação definitiva',
      message:
          'Introduz a palavra-passe mestra para eliminar documentos definitivamente.',
    );
    if (!allowed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(vaultProvider.notifier).permanentlyDeleteDocuments(ids);
      if (!mounted) return;
      setState(() => _selectedIds.removeAll(ids));
      _showSnack(
        ids.length == 1
            ? 'Documento eliminado definitivamente.'
            : 'Documentos eliminados definitivamente.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emptyTrash() async {
    await _autoLock.restart();
    if (!mounted) return;
    final confirmed = await _confirmPermanentDelete(
      'Eliminar definitivamente todo o Lixo de Documentos?',
    );
    if (confirmed != true || !mounted) return;
    if (!await _verifyPinIfNeeded(TrashPinAction.delete)) return;
    if (!mounted) return;
    final allowed = await confirmSensitiveAction(
      context: context,
      ref: ref,
      title: 'Confirmar esvaziar Lixo de Documentos',
      message:
          'Introduz a palavra-passe mestra para esvaziar o Lixo de Documentos.',
    );
    if (!allowed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(vaultProvider.notifier).emptyDocumentTrash();
      if (!mounted) return;
      setState(_selectedIds.clear);
      _showSnack('Lixo de Documentos esvaziado.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showTrashDetails(VaultDocumentMetadata document) {
    final deletedAt = document.deletedAt ?? document.updatedAt;
    final permanentDeletionAt = TrashRetentionPolicy.permanentDeletionAt(
      deletedAt,
      option: _retention,
    );
    final remaining = TrashRetentionPolicy.remainingText(
      deletedAt,
      option: _retention,
    );

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalhes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nome: ${document.fileName}'),
            const SizedBox(height: 8),
            Text('Tamanho: ${formatFileSize(document.sizeBytes)}'),
            const SizedBox(height: 8),
            Text('Eliminado: ${formatDateTime(deletedAt)}'),
            const SizedBox(height: 8),
            Text(
              permanentDeletionAt == null
                  ? 'Eliminação permanente automática: nunca'
                  : 'Eliminação permanente prevista: ${formatDateTime(permanentDeletionAt)}',
            ),
            const SizedBox(height: 8),
            Text(
              permanentDeletionAt == null
                  ? 'Este documento fica no Lixo até ser eliminado manualmente.'
                  : remaining == 'expirado'
                  ? 'A retenção configurada terminou.'
                  : 'Faltam $remaining para eliminação permanente.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmPermanentDelete(String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Eliminar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
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
    final useModernCards = tokens.designMode == AppDesignMode.modern;
    final deletedDocuments =
        (ref.watch(vaultProvider).data?.deletedDocuments ??
                const <VaultDocumentMetadata>[])
            .toList()
          ..sort(
            (a, b) => (b.deletedAt ?? b.updatedAt).compareTo(
              a.deletedAt ?? a.updatedAt,
            ),
          );
    final selectedCount = _selectedIds.length;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '$selectedCount selecionado(s)'
              : 'Lixo de Documentos',
        ),
        backgroundColor: tokens.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_selectionMode)
            IconButton(
              tooltip: 'Cancelar seleção',
              icon: const Icon(Icons.close),
              onPressed: _busy ? null : () => setState(_selectedIds.clear),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Eliminar selecionados',
              icon: const Icon(Icons.delete_forever_outlined),
              onPressed: _busy
                  ? null
                  : () => _deletePermanently(Set<String>.from(_selectedIds)),
            ),
          if (!_selectionMode && deletedDocuments.isNotEmpty)
            IconButton(
              tooltip: 'Esvaziar Lixo de Documentos',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _busy ? null : _emptyTrash,
            ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _autoLock.restart(),
        onPanDown: (_) => _autoLock.restart(),
        child: _checkingAccess
            ? const Center(child: CircularProgressIndicator())
            : deletedDocuments.isEmpty
            ? const Center(child: Text('O Lixo de Documentos está vazio.'))
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.pagePadding,
                      12,
                      tokens.pagePadding,
                      useModernCards ? 12 : 8,
                    ),
                    child: _DocumentTrashRetentionNotice(
                      retention: _retention,
                      useModernCard: useModernCards,
                    ),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  Expanded(
                    child: ListView.separated(
                      padding: useModernCards
                          ? EdgeInsets.fromLTRB(
                              tokens.pagePadding,
                              0,
                              tokens.pagePadding,
                              tokens.pagePadding,
                            )
                          : EdgeInsets.zero,
                      itemCount: deletedDocuments.length,
                      separatorBuilder: (context, index) => useModernCards
                          ? const SizedBox(height: 12)
                          : const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final document = deletedDocuments[index];
                        return _DocumentTrashTile(
                          document: document,
                          selected: _selectedIds.contains(document.id),
                          selectionMode: _selectionMode,
                          useModernCard: useModernCards,
                          onTap: () {
                            _autoLock.restart();
                            if (_selectionMode) _toggleSelection(document.id);
                          },
                          onLongPress: () {
                            _autoLock.restart();
                            _toggleSelection(document.id);
                          },
                          onDetails: () => _showTrashDetails(document),
                          onRestore: _busy ? null : () => _restore(document.id),
                          onDelete: _busy
                              ? null
                              : () => _deletePermanently({document.id}),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DocumentTrashTile extends StatelessWidget {
  const _DocumentTrashTile({
    required this.document,
    required this.selected,
    required this.selectionMode,
    required this.useModernCard,
    required this.onTap,
    required this.onLongPress,
    required this.onDetails,
    required this.onRestore,
    required this.onDelete,
  });

  final VaultDocumentMetadata document;
  final bool selected;
  final bool selectionMode;
  final bool useModernCard;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDetails;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final tile = ListTile(
      minTileHeight: useModernCard ? 76 : null,
      contentPadding: EdgeInsets.symmetric(
        horizontal: useModernCard ? 14 : 16,
        vertical: useModernCard ? 6 : 0,
      ),
      leading: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onTap())
          : const Icon(Icons.description_outlined),
      title: Text(
        document.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: useModernCard
            ? Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              )
            : null,
      ),
      subtitle: Padding(
        padding: EdgeInsets.only(top: useModernCard ? 4 : 0),
        child: Text(
          '${formatFileSize(document.sizeBytes)}  |  Eliminado: ${formatDateTime(document.deletedAt ?? document.updatedAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: useModernCard
              ? Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.textMuted,
                  fontSize: 12,
                )
              : null,
        ),
      ),
      trailing: selectionMode
          ? null
          : _DocumentTrashActionMenu(
              useModernCard: useModernCard,
              onDetails: onDetails,
              onRestore: onRestore,
              onDelete: onDelete,
            ),
      onTap: onTap,
      onLongPress: onLongPress,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          useModernCard ? tokens.cardRadius : 0,
        ),
      ),
    );

    if (!useModernCard) return tile;

    return AppSurface(
      elevated: true,
      padding: EdgeInsets.zero,
      radius: tokens.cardRadius,
      borderColor: selected ? tokens.accent : null,
      backgroundColor: selected
          ? tokens.accent.withValues(alpha: tokens.isDark ? 0.12 : 0.08)
          : null,
      child: tile,
    );
  }
}

class _DocumentTrashActionMenu extends StatelessWidget {
  const _DocumentTrashActionMenu({
    required this.useModernCard,
    required this.onDetails,
    required this.onRestore,
    required this.onDelete,
  });

  final bool useModernCard;
  final VoidCallback? onDetails;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    return PopupMenuButton<_DocumentTrashAction>(
      tooltip: 'Ações',
      icon: useModernCard
          ? Icon(Icons.more_horiz_rounded, color: tokens.textMuted)
          : null,
      color: useModernCard ? tokens.surfaceRaised : null,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(useModernCard ? 16 : 4),
        side: useModernCard
            ? BorderSide(color: tokens.border)
            : BorderSide.none,
      ),
      onSelected: (action) {
        switch (action) {
          case _DocumentTrashAction.details:
            onDetails?.call();
            break;
          case _DocumentTrashAction.restore:
            onRestore?.call();
            break;
          case _DocumentTrashAction.delete:
            onDelete?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _DocumentTrashAction.details,
          child: _DocumentTrashMenuActionRow(
            icon: Icons.info_outline_rounded,
            label: 'Detalhes',
            color: tokens.accent,
            useModernCard: useModernCard,
          ),
        ),
        PopupMenuItem(
          value: _DocumentTrashAction.restore,
          child: _DocumentTrashMenuActionRow(
            icon: Icons.restore_rounded,
            label: 'Restaurar',
            color: tokens.success,
            useModernCard: useModernCard,
          ),
        ),
        PopupMenuItem(
          value: _DocumentTrashAction.delete,
          child: _DocumentTrashMenuActionRow(
            icon: Icons.delete_forever_outlined,
            label: 'Eliminar definitivamente',
            color: Theme.of(context).colorScheme.error,
            useModernCard: useModernCard,
          ),
        ),
      ],
    );
  }
}

class _DocumentTrashMenuActionRow extends StatelessWidget {
  const _DocumentTrashMenuActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.useModernCard,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool useModernCard;

  @override
  Widget build(BuildContext context) {
    if (!useModernCard) return Text(label);

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

enum _DocumentTrashAction { details, restore, delete }

class _DocumentTrashPinPromptDialog extends StatefulWidget {
  const _DocumentTrashPinPromptDialog({
    required this.action,
    required this.verifier,
  });

  final TrashPinAction action;
  final Future<bool> Function(String pin) verifier;

  @override
  State<_DocumentTrashPinPromptDialog> createState() =>
      _DocumentTrashPinPromptDialogState();
}

class _DocumentTrashPinPromptDialogState
    extends State<_DocumentTrashPinPromptDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'Introduz o PIN.');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final isValid = await widget.verifier(pin);
    if (!mounted) return;

    if (!isValid) {
      setState(() {
        _error = 'PIN incorreto.';
        _submitting = false;
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.action.promptTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'PIN', errorText: _error),
        onSubmitted: (_) async => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _DocumentTrashRetentionNotice extends StatelessWidget {
  const _DocumentTrashRetentionNotice({
    required this.retention,
    required this.useModernCard,
  });

  final TrashRetentionOption retention;
  final bool useModernCard;

  @override
  Widget build(BuildContext context) {
    if (useModernCard) {
      final tokens = EncryVaultTheme.of(context);
      return AppSurface(
        elevated: true,
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: tokens.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                TrashRetentionPolicy.documentNoticeText(retention),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.25),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(TrashRetentionPolicy.documentNoticeText(retention)),
            ),
          ],
        ),
      ),
    );
  }
}
