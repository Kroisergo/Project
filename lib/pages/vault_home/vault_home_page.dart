import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/vault_entry.dart';
import '../../models/vault_sort_mode.dart';
import '../../services/security/password_health_service.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/vault_sort_controller.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/router_paths.dart';
import '../unlock/unlock_page.dart';

class _VaultHomeColors {
  const _VaultHomeColors({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.accent,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.favorite,
    required this.onAccent,
    required this.cardShadow,
    required this.subtleOverlay,
  });

  factory _VaultHomeColors.from(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF8AB4F8) : scheme.primary;

    return _VaultHomeColors(
      isDark: isDark,
      background: isDark
          ? const Color(0xFF121212)
          : theme.scaffoldBackgroundColor,
      surface: isDark ? const Color(0xFF181818) : Colors.white,
      surfaceRaised: isDark ? const Color(0xFF202124) : const Color(0xFFF1F5F9),
      border: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
      accent: accent,
      primaryText: isDark ? const Color(0xFFF1F3F4) : scheme.onSurface,
      secondaryText: isDark ? const Color(0xFFB8BDC4) : const Color(0xFF475467),
      mutedText: isDark ? const Color(0xFF7F858D) : const Color(0xFF667085),
      favorite: isDark ? const Color(0xFFFFC857) : const Color(0xFFB7791F),
      onAccent: isDark ? const Color(0xFF121212) : scheme.onPrimary,
      cardShadow: isDark
          ? Colors.transparent
          : const Color(0xFF101828).withValues(alpha: 0.06),
      subtleOverlay: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
    );
  }

  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color accent;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedText;
  final Color favorite;
  final Color onAccent;
  final Color cardShadow;
  final Color subtleOverlay;
}

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
  VaultEntryCategory? _selectedCategory;
  bool _favoritesOnly = false;
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
    ).showSnackBar(const SnackBar(content: Text('Sessao bloqueada.')));
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

  void _clearFilters() {
    _autoLock.restart();
    setState(() {
      _query = '';
      _selectedTags = {};
      _selectedCategory = null;
      _favoritesOnly = false;
      _searchController.clear();
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
        content: const Text('As entradas serao movidas para o Lixo.'),
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
          'Existem palavras-passe que precisam de atencao. Para veres quais sao e os detalhes, abre Configuracoes e depois Saude.',
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
            child: const Text('Abrir configuracoes'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(VaultEntry entry) async {
    await _autoLock.restart();
    await ref
        .read(vaultProvider.notifier)
        .setEntryFavorite(entry.id, !entry.isFavorite);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);
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
      selectedCategory: _selectedCategory,
      favoritesOnly: _favoritesOnly,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.primaryText,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        titleSpacing: 20,
        centerTitle: false,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: _selectionMode
              ? Text(
                  '${_selectedEntryIds.length} selecionada(s)',
                  key: const ValueKey('selection-title'),
                )
              : const _VaultAppBarTitle(key: ValueKey('vault-title')),
        ),
        actions: [
          if (_selectionMode)
            IconButton(
              tooltip: 'Cancelar selecao',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(_selectedEntryIds.clear),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Apagar selecionadas',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _deleteSelectedEntries,
            ),
          if (!_selectionMode && healthReport.hasImportantAlerts)
            IconButton(
              tooltip: 'Alertas de palavras-passe',
              icon: Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _showHealthInfo,
            ),
          if (!_selectionMode && showFilters)
            PopupMenuButton<VaultSortMode>(
              tooltip: 'Ordenar',
              color: colors.surface,
              icon: const Icon(Icons.sort_rounded),
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
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configuracoes',
              onPressed: () async {
                await _autoLock.refreshTimeout();
                if (!context.mounted) return;
                context.push(RouterPaths.vaultSettings);
              },
            ),
          if (!_selectionMode)
            IconButton(
              icon: const Icon(Icons.lock_outline_rounded),
              tooltip: 'Bloquear',
              onPressed: () {
                _autoLock.cancel();
                _lockAndExit();
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _autoLock.restart(),
        onPanDown: (_) => _autoLock.restart(),
        child: !showFilters
            ? _VaultEmptyState(
                onCreate: () {
                  _autoLock.restart();
                  context.push(RouterPaths.vaultEntryNew);
                },
              )
            : NotificationListener<UserScrollNotification>(
                onNotification: (_) {
                  _autoLock.restart();
                  return false;
                },
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      _VaultSearchBar(
                        controller: _searchController,
                        hasQuery: _query.isNotEmpty,
                        onChanged: (value) {
                          _autoLock.restart();
                          setState(() => _query = value.trim().toLowerCase());
                        },
                        onClear: _clearFilters,
                      ),
                      _VaultCategoryStrip(
                        favoritesOnly: _favoritesOnly,
                        selectedCategory: _selectedCategory,
                        onFavoritesChanged: (value) {
                          _autoLock.restart();
                          setState(() => _favoritesOnly = value);
                        },
                        onCategoryChanged: (category) {
                          _autoLock.restart();
                          setState(() => _selectedCategory = category);
                        },
                      ),
                      if (sortedTags.isNotEmpty)
                        _VaultTagStrip(
                          tags: sortedTags,
                          selectedTags: _selectedTags,
                          onClearTags: () {
                            _autoLock.restart();
                            setState(() => _selectedTags = {});
                          },
                          onTagChanged: (tag, selected) {
                            _autoLock.restart();
                            setState(() {
                              if (selected) {
                                _selectedTags = {..._selectedTags, tag};
                              } else {
                                _selectedTags = {..._selectedTags}..remove(tag);
                              }
                            });
                          },
                        ),
                      _VaultFeedHeader(
                        visibleCount: filtered.length,
                        totalCount: entries.length,
                        sortLabel: sortMode.label,
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? _VaultNoResultsState(onClear: _clearFilters)
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  96,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final entry = filtered[index];
                                  return _VaultFeedCard(
                                    entry: entry,
                                    selected: _selectedEntryIds.contains(
                                      entry.id,
                                    ),
                                    selectionMode: _selectionMode,
                                    formattedDate: _formatDate(entry.updatedAt),
                                    subtitle: _entrySubtitle(entry),
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
                                    onToggleFavorite: () =>
                                        _toggleFavorite(entry),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.small(
              tooltip: 'Nova entrada',
              backgroundColor: colors.surface,
              foregroundColor: colors.accent,
              onPressed: () {
                _autoLock.restart();
                context.push(RouterPaths.vaultEntryNew);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _entrySubtitle(VaultEntry entry) {
    final parts = [
      if (entry.username.trim().isNotEmpty) entry.username,
      entry.category.label,
    ];
    return parts.join('  |  ');
  }
}

class _VaultAppBarTitle extends StatelessWidget {
  const _VaultAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'EncryVault',
          style: TextStyle(
            color: colors.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Cofre pessoal',
          style: TextStyle(
            color: colors.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _VaultSearchBar extends StatelessWidget {
  const _VaultSearchBar({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: controller,
        cursorColor: colors.accent,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: colors.primaryText, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Procurar contas, utilizadores, URLs ou tags',
          hintStyle: TextStyle(color: colors.mutedText),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colors.mutedText,
            size: 20,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  tooltip: 'Limpar pesquisa',
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.mutedText,
                    size: 18,
                  ),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: colors.surfaceRaised,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: _searchBorder(colors.border),
          enabledBorder: _searchBorder(colors.border),
          focusedBorder: _searchBorder(colors.accent.withValues(alpha: 0.72)),
        ),
      ),
    );
  }

  OutlineInputBorder _searchBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );
  }
}

class _VaultCategoryStrip extends StatelessWidget {
  const _VaultCategoryStrip({
    required this.favoritesOnly,
    required this.selectedCategory,
    required this.onFavoritesChanged,
    required this.onCategoryChanged,
  });

  final bool favoritesOnly;
  final VaultEntryCategory? selectedCategory;
  final ValueChanged<bool> onFavoritesChanged;
  final ValueChanged<VaultEntryCategory?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _VaultFilterChip(
            label: 'Favoritos',
            selected: favoritesOnly,
            icon: Icons.star_rounded,
            iconColor: favoritesOnly ? colors.favorite : colors.mutedText,
            onSelected: onFavoritesChanged,
          ),
          const SizedBox(width: 8),
          _VaultChoiceChip(
            label: 'Todas',
            selected: selectedCategory == null,
            onSelected: (selected) {
              if (selected) onCategoryChanged(null);
            },
          ),
          const SizedBox(width: 8),
          ...VaultEntryCategory.values.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _VaultChoiceChip(
                label: category.label,
                selected: selectedCategory == category,
                icon: _categoryIcon(category),
                iconColor: _categoryColor(category, colors),
                onSelected: (selected) {
                  onCategoryChanged(selected ? category : null);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultTagStrip extends StatelessWidget {
  const _VaultTagStrip({
    required this.tags,
    required this.selectedTags,
    required this.onClearTags,
    required this.onTagChanged,
  });

  final List<String> tags;
  final Set<String> selectedTags;
  final VoidCallback onClearTags;
  final void Function(String tag, bool selected) onTagChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _VaultChoiceChip(
            label: 'Todas tags',
            selected: selectedTags.isEmpty,
            onSelected: (selected) {
              if (selected) onClearTags();
            },
          ),
          const SizedBox(width: 8),
          ...tags.map(
            (tag) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _VaultChoiceChip(
                label: tag,
                selected: selectedTags.contains(tag),
                onSelected: (selected) => onTagChanged(tag, selected),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultFeedHeader extends StatelessWidget {
  const _VaultFeedHeader({
    required this.visibleCount,
    required this.totalCount,
    required this.sortLabel,
  });

  final int visibleCount;
  final int totalCount;
  final String sortLabel;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);
    final entryLabel = visibleCount == 1 ? 'entrada' : 'entradas';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$visibleCount $entryLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          Icon(Icons.tune_rounded, color: colors.mutedText, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              totalCount == visibleCount
                  ? sortLabel
                  : '$visibleCount de $totalCount | $sortLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultFeedCard extends StatefulWidget {
  const _VaultFeedCard({
    required this.entry,
    required this.selected,
    required this.selectionMode,
    required this.formattedDate,
    required this.subtitle,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleFavorite,
  });

  final VaultEntry entry;
  final bool selected;
  final bool selectionMode;
  final String formattedDate;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleFavorite;

  @override
  State<_VaultFeedCard> createState() => _VaultFeedCardState();
}

class _VaultFeedCardState extends State<_VaultFeedCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);
    final accent = _categoryColor(widget.entry.category, colors);
    final borderColor = widget.selected
        ? accent.withValues(alpha: 0.7)
        : colors.border;
    final backgroundColor = widget.selected
        ? accent.withValues(alpha: 0.12)
        : colors.surface;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
          boxShadow: [
            if (!colors.isDark)
              BoxShadow(
                color: colors.cardShadow,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: accent.withValues(alpha: 0.08),
              highlightColor: accent.withValues(alpha: 0.05),
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.selectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Transform.scale(
                          scale: 0.9,
                          child: Checkbox(
                            value: widget.selected,
                            onChanged: (_) => widget.onTap(),
                            activeColor: accent,
                            checkColor: colors.onAccent,
                            side: BorderSide(color: colors.mutedText),
                          ),
                        ),
                      ),
                    _EntryAvatar(
                      category: widget.entry.category,
                      accent: accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _EntryContent(
                        entry: widget.entry,
                        accent: accent,
                        formattedDate: widget.formattedDate,
                        subtitle: widget.subtitle,
                      ),
                    ),
                    if (!widget.selectionMode)
                      IconButton(
                        tooltip: widget.entry.isFavorite
                            ? 'Remover dos favoritos'
                            : 'Adicionar aos favoritos',
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        color: widget.entry.isFavorite
                            ? colors.favorite
                            : colors.mutedText,
                        icon: Icon(
                          widget.entry.isFavorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                        ),
                        onPressed: widget.onToggleFavorite,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryAvatar extends StatelessWidget {
  const _EntryAvatar({required this.category, required this.accent});

  final VaultEntryCategory category;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Icon(_categoryIcon(category), color: accent, size: 18),
    );
  }
}

class _EntryContent extends StatelessWidget {
  const _EntryContent({
    required this.entry,
    required this.accent,
    required this.formattedDate,
    required this.subtitle,
  });

  final VaultEntry entry;
  final Color accent;
  final String formattedDate;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);
    final visibleTags = entry.tags.take(3).toList();
    final extraTags = entry.tags.length - visibleTags.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.primaryText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 14,
              color: colors.mutedText,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        if (visibleTags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...visibleTags.map((tag) => _EntryTag(label: tag)),
              if (extraTags > 0) _EntryTag(label: '+$extraTags'),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              color: accent.withValues(alpha: 0.72),
              size: 13,
            ),
            const SizedBox(width: 5),
            Text(
              'Atualizado $formattedDate',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EntryTag extends StatelessWidget {
  const _EntryTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.subtleOverlay,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.secondaryText,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _VaultFilterChip extends StatelessWidget {
  const _VaultFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.iconColor,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      avatar: icon == null
          ? null
          : Icon(icon, size: 16, color: iconColor ?? colors.mutedText),
      labelStyle: TextStyle(
        color: selected ? colors.primaryText : colors.secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      backgroundColor: colors.surface,
      selectedColor: colors.accent.withValues(
        alpha: colors.isDark ? 0.16 : 0.1,
      ),
      side: BorderSide(
        color: selected
            ? colors.accent.withValues(alpha: colors.isDark ? 0.55 : 0.38)
            : colors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _VaultChoiceChip extends StatelessWidget {
  const _VaultChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.iconColor,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? colors.mutedText),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? colors.primaryText : colors.secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      backgroundColor: colors.surface,
      selectedColor: colors.accent.withValues(
        alpha: colors.isDark ? 0.16 : 0.1,
      ),
      side: BorderSide(
        color: selected
            ? colors.accent.withValues(alpha: colors.isDark ? 0.55 : 0.38)
            : colors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _VaultEmptyState extends StatelessWidget {
  const _VaultEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: colors.accent,
                  size: 26,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Nenhuma entrada no cofre',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cria a primeira conta para comecar a organizar o teu cofre.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.secondaryText,
                  fontSize: 13,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Criar primeira entrada'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultNoResultsState extends StatelessWidget {
  const _VaultNoResultsState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              color: colors.mutedText,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma entrada corresponde ao filtro.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.secondaryText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onClear, child: const Text('Limpar filtros')),
          ],
        ),
      ),
    );
  }
}

IconData _categoryIcon(VaultEntryCategory category) {
  switch (category) {
    case VaultEntryCategory.social:
      return Icons.alternate_email_rounded;
    case VaultEntryCategory.email:
      return Icons.mail_outline_rounded;
    case VaultEntryCategory.bank:
      return Icons.account_balance_outlined;
    case VaultEntryCategory.games:
      return Icons.sports_esports_outlined;
    case VaultEntryCategory.work:
      return Icons.work_outline_rounded;
    case VaultEntryCategory.other:
      return Icons.lock_outline_rounded;
  }
}

Color _categoryColor(VaultEntryCategory category, _VaultHomeColors colors) {
  switch (category) {
    case VaultEntryCategory.social:
      return colors.isDark ? const Color(0xFF8BD3DD) : const Color(0xFF047481);
    case VaultEntryCategory.email:
      return colors.isDark ? const Color(0xFFB9A7FF) : const Color(0xFF6D5BD0);
    case VaultEntryCategory.bank:
      return colors.isDark ? const Color(0xFF8EE6A7) : const Color(0xFF16803C);
    case VaultEntryCategory.games:
      return colors.isDark ? const Color(0xFFFFC857) : const Color(0xFFB7791F);
    case VaultEntryCategory.work:
      return colors.isDark ? const Color(0xFF7DB7FF) : const Color(0xFF1C64D1);
    case VaultEntryCategory.other:
      return colors.isDark ? const Color(0xFFC9CED6) : const Color(0xFF667085);
  }
}
