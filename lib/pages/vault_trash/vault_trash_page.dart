import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/design_tokens.dart';
import '../../models/app_design_mode.dart';
import '../../models/vault_entry.dart';
import '../../services/security/trash_pin_service.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/trash_retention_policy.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/time_labels.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/sensitive_action_confirmation.dart';
import '../../widgets/vault_category_icon.dart';
import '../unlock/unlock_page.dart';

class VaultTrashPage extends ConsumerStatefulWidget {
  static const subPath = 'trash';
  static const routeName = 'vault-trash';

  const VaultTrashPage({super.key});

  @override
  ConsumerState<VaultTrashPage> createState() => _VaultTrashPageState();
}

class _VaultTrashPageState extends ConsumerState<VaultTrashPage>
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

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _prepareTrash() async {
    if (!mounted) return;
    final retention = await ref
        .read(preferencesServiceProvider)
        .getTrashRetentionOption();
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
        .purgeExpiredTrash(retention: retention);
  }

  Future<bool> _verifyPinIfNeeded(TrashPinAction action) async {
    final service = ref.read(trashPinServiceProvider);
    if (!await service.isEnabled(action)) return true;
    if (!mounted) return false;

    final valid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TrashPinPromptDialog(
        action: action,
        verifier: (pin) => service.verify(action, pin),
      ),
    );
    return valid ?? false;
  }

  Future<void> _restore(String id) async {
    await _autoLock.restart();
    if (!mounted) return;
    if (!await _verifyPinIfNeeded(TrashPinAction.restore)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(vaultProvider.notifier).restoreEntry(id);
      if (!mounted) return;
      setState(() => _selectedIds.remove(id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entrada restaurada.')));
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
          ? 'Eliminar definitivamente esta entrada?'
          : 'Eliminar definitivamente ${ids.length} entradas?',
    );
    if (confirmed != true || !mounted) return;
    if (!await _verifyPinIfNeeded(TrashPinAction.delete)) return;
    if (!mounted) return;
    final allowed = await confirmSensitiveAction(
      context: context,
      ref: ref,
      title: 'Confirmar eliminação definitiva',
      message:
          'Introduz a palavra-passe mestra para eliminar entradas definitivamente.',
    );
    if (!allowed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(vaultProvider.notifier).permanentlyDeleteEntries(ids);
      if (!mounted) return;
      setState(() => _selectedIds.removeAll(ids));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ids.length == 1
                ? 'Entrada eliminada definitivamente.'
                : 'Entradas eliminadas definitivamente.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emptyTrash() async {
    await _autoLock.restart();
    if (!mounted) return;
    final confirmed = await _confirmPermanentDelete(
      'Eliminar definitivamente todo o Lixo?',
    );
    if (confirmed != true || !mounted) return;
    if (!await _verifyPinIfNeeded(TrashPinAction.delete)) return;
    if (!mounted) return;
    final allowed = await confirmSensitiveAction(
      context: context,
      ref: ref,
      title: 'Confirmar esvaziar Lixo',
      message: 'Introduz a palavra-passe mestra para esvaziar o Lixo.',
    );
    if (!allowed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(vaultProvider.notifier).emptyTrash();
      if (!mounted) return;
      setState(_selectedIds.clear);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lixo esvaziado.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showTrashDetails(VaultEntry entry) {
    final deletedAt = entry.deletedAt ?? entry.updatedAt;
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
            Text('Título: ${entry.title}'),
            const SizedBox(height: 8),
            Text('Eliminada: ${formatDateTime(deletedAt)}'),
            const SizedBox(height: 8),
            Text(
              permanentDeletionAt == null
                  ? 'Eliminação permanente automática: nunca'
                  : 'Eliminação permanente prevista: ${formatDateTime(permanentDeletionAt)}',
            ),
            const SizedBox(height: 8),
            Text(
              permanentDeletionAt == null
                  ? 'Esta entrada fica no Lixo até ser eliminada manualmente.'
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

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final useModernCards = usesModernTrashEntryCards(tokens.designMode);
    final deletedEntries =
        (ref.watch(vaultProvider).data?.deletedEntries ?? []).toList()..sort(
          (a, b) => (b.deletedAt ?? b.updatedAt).compareTo(
            a.deletedAt ?? a.updatedAt,
          ),
        );
    final selectedCount = _selectedIds.length;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(_selectionMode ? '$selectedCount selecionada(s)' : 'Lixo'),
        actions: [
          if (_selectionMode)
            IconButton(
              tooltip: 'Cancelar seleção',
              icon: const Icon(Icons.close),
              onPressed: _busy ? null : () => setState(_selectedIds.clear),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Eliminar selecionadas',
              icon: const Icon(Icons.delete_forever_outlined),
              onPressed: _busy
                  ? null
                  : () => _deletePermanently(Set<String>.from(_selectedIds)),
            ),
          if (!_selectionMode && deletedEntries.isNotEmpty)
            IconButton(
              tooltip: 'Esvaziar Lixo',
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
            : deletedEntries.isEmpty
            ? const Center(child: Text('O Lixo está vazio.'))
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.pagePadding,
                      12,
                      tokens.pagePadding,
                      useModernCards ? 12 : 8,
                    ),
                    child: _TrashRetentionNotice(
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
                      itemCount: deletedEntries.length,
                      separatorBuilder: (context, index) => useModernCards
                          ? const SizedBox(height: 12)
                          : const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = deletedEntries[index];
                        return _TrashEntryTile(
                          entry: entry,
                          selected: _selectedIds.contains(entry.id),
                          selectionMode: _selectionMode,
                          useModernCard: useModernCards,
                          onTap: () {
                            _autoLock.restart();
                            if (_selectionMode) _toggleSelection(entry.id);
                          },
                          onLongPress: () {
                            _autoLock.restart();
                            _toggleSelection(entry.id);
                          },
                          onDetails: () => _showTrashDetails(entry),
                          onRestore: _busy ? null : () => _restore(entry.id),
                          onDelete: _busy
                              ? null
                              : () => _deletePermanently({entry.id}),
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

class _TrashEntryTile extends StatelessWidget {
  final VaultEntry entry;
  final bool selected;
  final bool selectionMode;
  final bool useModernCard;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDetails;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  const _TrashEntryTile({
    required this.entry,
    required this.selected,
    required this.selectionMode,
    required this.useModernCard,
    required this.onTap,
    required this.onLongPress,
    required this.onDetails,
    required this.onRestore,
    required this.onDelete,
  });

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
          : useModernCard
          ? VaultCategoryIcon(category: entry.category, size: 42)
          : const Icon(Icons.delete_outline),
      title: Text(
        entry.title,
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
          'Eliminada: ${_formatDate(entry.deletedAt ?? entry.updatedAt)}',
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
          : _TrashActionMenu(
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

  String _formatDate(DateTime date) {
    return formatDateTime(date);
  }
}

class _TrashActionMenu extends StatelessWidget {
  const _TrashActionMenu({
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
    return PopupMenuButton<_TrashAction>(
      tooltip: 'Ações',
      icon: useModernCard
          ? Icon(Icons.more_horiz_rounded, color: tokens.textMuted)
          : null,
      color: useModernCard ? tokens.surfaceRaised : null,
      surfaceTintColor: Colors.transparent,
      elevation: useModernCard ? 10 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(useModernCard ? 16 : 4),
        side: useModernCard
            ? BorderSide(color: tokens.border)
            : BorderSide.none,
      ),
      onSelected: (action) {
        switch (action) {
          case _TrashAction.details:
            onDetails?.call();
            break;
          case _TrashAction.restore:
            onRestore?.call();
            break;
          case _TrashAction.delete:
            onDelete?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _TrashAction.details,
          child: _TrashMenuActionRow(
            icon: Icons.info_outline_rounded,
            label: 'Detalhes',
            color: tokens.accent,
            useModernCard: useModernCard,
          ),
        ),
        PopupMenuItem(
          value: _TrashAction.restore,
          child: _TrashMenuActionRow(
            icon: Icons.restore_rounded,
            label: 'Restaurar',
            color: tokens.success,
            useModernCard: useModernCard,
          ),
        ),
        PopupMenuItem(
          value: _TrashAction.delete,
          child: _TrashMenuActionRow(
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

class _TrashMenuActionRow extends StatelessWidget {
  const _TrashMenuActionRow({
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

enum _TrashAction { details, restore, delete }

class _TrashPinPromptDialog extends StatefulWidget {
  final TrashPinAction action;
  final Future<bool> Function(String pin) verifier;

  const _TrashPinPromptDialog({required this.action, required this.verifier});

  @override
  State<_TrashPinPromptDialog> createState() => _TrashPinPromptDialogState();
}

class _TrashPinPromptDialogState extends State<_TrashPinPromptDialog> {
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

class _TrashRetentionNotice extends StatelessWidget {
  final TrashRetentionOption retention;
  final bool useModernCard;

  const _TrashRetentionNotice({
    required this.retention,
    required this.useModernCard,
  });

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
                TrashRetentionPolicy.noticeText(retention),
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
            Expanded(child: Text(TrashRetentionPolicy.noticeText(retention))),
          ],
        ),
      ),
    );
  }
}

bool usesModernTrashEntryCards(AppDesignMode designMode) {
  return designMode == AppDesignMode.modern;
}
