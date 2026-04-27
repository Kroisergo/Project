import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/vault_entry.dart';
import '../../services/security/trash_pin_service.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/trash_retention_policy.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/time_labels.dart';
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

    setState(() => _busy = true);
    try {
      await ref.read(vaultProvider.notifier).permanentlyDeleteEntries(ids);
      if (!mounted) return;
      setState(() => _selectedIds.removeAll(ids));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ids.length == 1
                ? 'Entrada removida definitivamente.'
                : 'Entradas removidas definitivamente.',
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
    final deletedEntries =
        (ref.watch(vaultProvider).data?.deletedEntries ?? []).toList()..sort(
          (a, b) => (b.deletedAt ?? b.updatedAt).compareTo(
            a.deletedAt ?? a.updatedAt,
          ),
        );
    final selectedCount = _selectedIds.length;

    return Scaffold(
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
            ? const Center(child: Text('O Lixo esta vazio.'))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _TrashRetentionNotice(retention: _retention),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  Expanded(
                    child: ListView.separated(
                      itemCount: deletedEntries.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = deletedEntries[index];
                        return _TrashEntryTile(
                          entry: entry,
                          selected: _selectedIds.contains(entry.id),
                          selectionMode: _selectionMode,
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
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDetails;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  const _TrashEntryTile({
    required this.entry,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onDetails,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onTap())
          : const Icon(Icons.delete_outline),
      title: Text(entry.title),
      subtitle: Text(
        'Eliminada: ${_formatDate(entry.deletedAt ?? entry.updatedAt)}',
      ),
      trailing: selectionMode
          ? null
          : PopupMenuButton<_TrashAction>(
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
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _TrashAction.details,
                  child: Text('Detalhes'),
                ),
                PopupMenuItem(
                  value: _TrashAction.restore,
                  child: Text('Restaurar'),
                ),
                PopupMenuItem(
                  value: _TrashAction.delete,
                  child: Text('Eliminar definitivamente'),
                ),
              ],
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  String _formatDate(DateTime date) {
    return formatDateTime(date);
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

  const _TrashRetentionNotice({required this.retention});

  @override
  Widget build(BuildContext context) {
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
