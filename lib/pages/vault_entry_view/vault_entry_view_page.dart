import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/vault_entry.dart';
import '../../services/vault/vault_state.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../utils/router_paths.dart';
import '../vault_home/vault_home_page.dart';
import '../unlock/unlock_page.dart';

class VaultEntryViewPage extends ConsumerStatefulWidget {
  static const subPath = 'entry/:entryId';
  static const routeName = 'vault-entry-view';

  final String entryId;

  const VaultEntryViewPage({
    super.key,
    required this.entryId,
  });

  @override
  ConsumerState<VaultEntryViewPage> createState() => _VaultEntryViewPageState();
}

class _VaultEntryViewPageState extends ConsumerState<VaultEntryViewPage> with WidgetsBindingObserver {
  bool _obscure = true;
  Timer? _clipboardClear;
  int _clipboardToken = 0;
  late final AutoLockController _autoLock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoLock = AutoLockController(
      ref: ref,
      onTimeout: _onLocked,
    );
    _autoLock.restart();
  }

  VaultEntry? _findEntry(List<VaultEntry> list) {
    for (final e in list) {
      if (e.id == widget.entryId) {
        return e;
      }
    }
    return null;
  }

  Future<void> _copy(String label, String value) async {
    await _autoLock.restart();
    if (!mounted) return;
    _clipboardClear?.cancel();
    final token = ++_clipboardToken;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copiado (limpa em 30s)')));
    _clipboardClear = Timer(const Duration(seconds: 30), () async {
      if (token != _clipboardToken) return;
      final data = await Clipboard.getData('text/plain');
      if (data?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  Future<void> _confirmDelete(String id) async {
    await _autoLock.restart();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar entrada?'),
        content: const Text('Esta acao remove a entrada do cofre.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Apagar')),
        ],
      ),
    );
    if (result == true && mounted) {
      await ref.read(vaultProvider.notifier).deleteEntry(id);
      await _autoLock.restart();
      if (!mounted) return;
      context.go(VaultHomePage.routePath);
    }
  }

  void _onLocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessão bloqueada.')),
    );
    context.go(UnlockPage.routePath);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoLock.cancel();
    _clipboardClear?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _autoLock.handleLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    final entry = _findEntry(vault.data?.entries ?? []);

    final actions = entry == null
        ? <Widget>[]
        : [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                _autoLock.restart();
                context.push(RouterPaths.vaultEntryEdit(entry.id));
              },
            ),
            IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                _autoLock.restart();
                setState(() => _obscure = !_obscure);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(entry.id),
            ),
          ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrada'),
        actions: actions,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _autoLock.restart(),
        onPanDown: (_) => _autoLock.restart(),
        child: entry == null
            ? const Center(child: Text('Entrada nao encontrada.'))
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Atualizado: ${_formatDate(entry.updatedAt)}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      'Criado: ${_formatDate(entry.createdAt)}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 16),
                    _fieldRow('Utilizador', entry.username, onCopy: () => _copy('Utilizador', entry.username)),
                    const SizedBox(height: 12),
                    _fieldRow(
                      'Password',
                      _obscure ? '********' : entry.password,
                      onCopy: () => _copy('Password', entry.password),
                    ),
                    const SizedBox(height: 12),
                    _fieldRow('Notas', entry.notes, onCopy: () => _copy('Notas', entry.notes)),
                    const SizedBox(height: 16),
                    if (entry.tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: entry.tags.map((t) => Chip(label: Text(t))).toList(),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _fieldRow(String label, String value, {VoidCallback? onCopy}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: onCopy,
          ),
      ],
    );
  }
}
