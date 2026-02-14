import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/vault/auto_lock_controller.dart';
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

class _VaultHomePageState extends ConsumerState<VaultHomePage> with WidgetsBindingObserver {
  late final AutoLockController _autoLock;
  final _searchController = TextEditingController();
  String _query = '';
  Set<String> _selectedTags = {};

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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessão bloqueada.')),
    );
    context.go(UnlockPage.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    final entries = vault.data?.entries ?? [];
    final tags = <String>{};
    for (final e in entries) {
      tags.addAll(e.tags);
    }
    final filtered = entries.where((e) {
      final matchesQuery = _query.isEmpty ||
          e.title.toLowerCase().contains(_query) ||
          e.username.toLowerCase().contains(_query) ||
          e.tags.any((t) => t.toLowerCase().contains(_query));
      final matchesTag = _selectedTags.isEmpty || e.tags.any((t) => _selectedTags.contains(t));
      return matchesQuery && matchesTag;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cofre'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await _autoLock.refreshTimeout();
              if (!context.mounted) return;
              context.push(RouterPaths.vaultSettings);
            },
          ),
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
        child: entries.isEmpty
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
                        onChanged: (v) {
                          _autoLock.restart();
                          setState(() => _query = v.trim().toLowerCase());
                        },
                        decoration: const InputDecoration(
                          labelText: 'Procurar por titulo, utilizador ou tag',
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
                              onSelected: (v) {
                                _autoLock.restart();
                                setState(() => _selectedTags = {});
                              },
                            ),
                            const SizedBox(width: 8),
                            ...tags.map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(t),
                                  selected: _selectedTags.contains(t),
                                  onSelected: (v) {
                                    _autoLock.restart();
                                    setState(() {
                                      if (v) {
                                        _selectedTags = {..._selectedTags, t};
                                      } else {
                                        _selectedTags = {..._selectedTags}..remove(t);
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
                          ? const Center(child: Text('Nenhuma entrada corresponde ao filtro.'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, separatorIndex) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = filtered[index];
                                return ListTile(
                                  title: Text(entry.title),
                                  subtitle: Text(entry.username),
                                  trailing: Text(
                                    _formatDate(entry.updatedAt),
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                  onTap: () {
                                    _autoLock.restart();
                                    context.push(RouterPaths.vaultEntryView(entry.id));
                                  },
                                  onLongPress: () {
                                    _autoLock.restart();
                                    context.push(RouterPaths.vaultEntryEdit(entry.id));
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
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
