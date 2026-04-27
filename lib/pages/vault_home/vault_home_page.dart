import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/vault_sort_mode.dart';
import '../../services/security/password_health_service.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/vault_sort_controller.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/router_paths.dart';
import '../unlock/unlock_page.dart';

class VaultHomePage extends ConsumerStatefulWidget {
  static const routePath = '/vault';
  static const routeName = 'vault';

  const VaultHomePage({super.key});

  @override
  ConsumerState<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends ConsumerState<VaultHomePage>
    with WidgetsBindingObserver {
  late final AutoLockController _autoLock;
  final _searchController = TextEditingController();
  String _query = '';
  Set<String> _selectedTags = {};
  final Set<String> _selectedEntryIds = {};

  bool get _selectionMode => _selectedEntryIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoLock = AutoLockController(ref: ref, onTimeout: _lockAndExit);
    _autoLock.restart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoLock.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _autoLock.handleLifecycle(state);
  }

  void _lockAndExit() {
    ref.read(vaultProvider.notifier).clear();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sessão bloqueada.')));
    context.go(UnlockPage.routePath);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedEntryIds.contains(id)) {
        _selectedEntryIds.remove(id);
      } else {
        _selectedEntryIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedEntries() async {
    if (_selectedEntryIds.isEmpty) return;
    final selectedCount = _selectedEntryIds.length;
    await _autoLock.restart();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          selectedCount == 1
              ? 'Apagar entrada selecionada?'
              : 'Apagar $selectedCount entradas selecionadas?',
        ),
        content: const Text('As entradas serão movidas para o Lixo.'),
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
                child: const Text('Apagar'),
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
    if (confirmed != true || !mounted) return;
    await ref.read(vaultProvider.notifier).deleteEntries(_selectedEntryIds);
    if (!mounted) return;
    setState(_selectedEntryIds.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedCount == 1
              ? 'Entrada movida para o Lixo.'
              : 'Entradas movidas para o Lixo.',
        ),
      ),
    );
  }

  Future<void> _showHealthInfo() async {
    await _autoLock.restart();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alertas de palavras-passe'),
        content: const Text(
          'Existem palavras-passe que precisam de atenção. Para veres quais são e os detalhes, abre Configurações e depois Saúde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push(RouterPaths.vaultSettings);
            },
            child: const Text('Abrir configurações'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    final sortMode =
        ref.watch(vaultSortControllerProvider).valueOrNull ?? VaultSortMode.az;
    final entries = vault.data?.activeEntries ?? [];
    final showFilters = shouldShowVaultFilters(entries);
    final healthReport = PasswordHealthService.analyze(entries);
    final tags = <String>{};
    for (final entry in entries) {
      tags.addAll(entry.tags);
    }
    final sortedTags = tags.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final filtered = filterAndSortEntries(
      entries: entries,
      query: _query,
      selectedTags: _selectedTags,
      sortMode: sortMode,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selectedEntryIds.length} selecionada(s)'
              : 'Cofre',
        ),
        actions: [
          if (_selectionMode)
            IconButton(
              tooltip: 'Cancelar seleção',
              icon: const Icon(Icons.close),
              onPressed: () => setState(_selectedEntryIds.clear),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Apagar selecionadas',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelectedEntries,
            ),
          if (!_selectionMode && healthReport.hasImportantAlerts)
            IconButton(
              tooltip: 'Alertas de palavras-passe',
              icon: Icon(
                Icons.warning_amber_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _showHealthInfo,
            ),
          if (!_selectionMode && showFilters)
            PopupMenuButton<VaultSortMode>(
              tooltip: 'Ordenar',
              icon: const Icon(Icons.sort),
              initialValue: sortMode,
              onSelected: (mode) {
                _autoLock.restart();
                ref.read(vaultSortControllerProvider.notifier).setMode(mode);
              },
              itemBuilder: (context) => VaultSortMode.values
                  .map(
                    (mode) => PopupMenuItem<VaultSortMode>(
                      value: mode,
                      child: Text(mode.label),
                    ),
                  )
                  .toList(),
            ),
          if (!_selectionMode)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurações',
              onPressed: () async {
                await _autoLock.refreshTimeout();
                if (!context.mounted) return;
                context.push(RouterPaths.vaultSettings);
              },
            ),
          if (!_selectionMode)
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Bloquear',
              onPressed: () {
                _autoLock.cancel();
                _lockAndExit();
              },
            ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _autoLock.restart(),
        onPanDown: (_) => _autoLock.restart(),
        child: !showFilters
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nenhuma entrada no cofre.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        _autoLock.restart();
                        context.push(RouterPaths.vaultEntryNew);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Criar primeira entrada'),
                    ),
                  ],
                ),
              )
            : NotificationListener<UserScrollNotification>(
                onNotification: (_) {
                  _autoLock.restart();
                  return false;
                },
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          _autoLock.restart();
                          setState(() => _query = value.trim().toLowerCase());
                        },
                        decoration: const InputDecoration(
                          labelText: 'Procurar por título, utilizador ou tag',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    if (tags.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Todas'),
                              selected: _selectedTags.isEmpty,
                              onSelected: (value) {
                                _autoLock.restart();
                                setState(() => _selectedTags = {});
                              },
                            ),
                            const SizedBox(width: 8),
                            ...sortedTags.map(
                              (tag) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(tag),
                                  selected: _selectedTags.contains(tag),
                                  onSelected: (value) {
                                    _autoLock.restart();
                                    setState(() {
                                      if (value) {
                                        _selectedTags = {..._selectedTags, tag};
                                      } else {
                                        _selectedTags = {..._selectedTags}
                                          ..remove(tag);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhuma entrada corresponde ao filtro.',
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = filtered[index];
                                return ListTile(
                                  leading: _selectionMode
                                      ? Checkbox(
                                          value: _selectedEntryIds.contains(
                                            entry.id,
                                          ),
                                          onChanged: (_) =>
                                              _toggleSelection(entry.id),
                                        )
                                      : null,
                                  title: Text(entry.title),
                                  subtitle: Text(entry.username),
                                  trailing: Text(
                                    _formatDate(entry.updatedAt),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                  onTap: () {
                                    _autoLock.restart();
                                    if (_selectionMode) {
                                      _toggleSelection(entry.id);
                                    } else {
                                      context.push(
                                        RouterPaths.vaultEntryView(entry.id),
                                      );
                                    }
                                  },
                                  onLongPress: () {
                                    _autoLock.restart();
                                    _toggleSelection(entry.id);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              onPressed: () {
                _autoLock.restart();
                context.push(RouterPaths.vaultEntryNew);
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
