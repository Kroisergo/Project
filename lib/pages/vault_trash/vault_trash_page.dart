import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/vault_entry.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/vault_state.dart';
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

  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoLock = AutoLockController(ref: ref, onTimeout: _onLocked);
    _autoLock.restart();
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
    ).showSnackBar(const SnackBar(content: Text('Sessao bloqueada.')));
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

  Future<void> _restore(String id) async {
    await _autoLock.restart();
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

  Future<bool?> _confirmPermanentDelete(String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('Esta acao nao pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
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
              tooltip: 'Cancelar selecao',
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
        child: deletedEntries.isEmpty
            ? const Center(child: Text('O Lixo esta vazio.'))
            : Column(
                children: [
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
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  const _TrashEntryTile({
    required this.entry,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
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
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

enum _TrashAction { restore, delete }
