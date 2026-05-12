import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/design_tokens.dart';
import '../../models/app_design_mode.dart';
import '../../models/tag_display_mode.dart';
import '../../models/vault_entry.dart';
import '../../models/vault_sort_mode.dart';
import '../../services/security/ignored_alerts_controller.dart';
import '../../services/security/password_health_service.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/tag_display_controller.dart';
import '../../services/vault/vault_sort_controller.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/router_paths.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/vault_category_icon.dart';
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
    required this.cardRadius,
    required this.chipRadius,
    required this.designMode,
  });

  factory _VaultHomeColors.from(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);

    return _VaultHomeColors(
      isDark: tokens.isDark,
      background: tokens.background,
      surface: tokens.surface,
      surfaceRaised: tokens.surfaceRaised,
      border: tokens.border,
      accent: tokens.accent,
      primaryText: tokens.textPrimary,
      secondaryText: tokens.textSecondary,
      mutedText: tokens.textMuted,
      favorite: tokens.favorite,
      onAccent: tokens.onAccent,
      cardShadow: tokens.cardShadow.isEmpty
          ? Colors.transparent
          : tokens.cardShadow.first.color,
      cardRadius: tokens.cardRadius,
      chipRadius: tokens.chipRadius,
      designMode: tokens.designMode,
    );
  }

  bool get isClassicDesign => designMode == AppDesignMode.classic;

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
  final double cardRadius;
  final double chipRadius;
  final AppDesignMode designMode;
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
              ? 'Eliminar entrada selecionada?'
              : 'Eliminar $selectedCount entradas selecionadas?',
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
      builder: (dialogContext) {
        final colors = _VaultHomeColors.from(dialogContext);
        final isModern = usesModernVaultFilterSurfaces(colors.designMode);
        return AlertDialog(
          backgroundColor: isModern ? colors.surface : null,
          surfaceTintColor: Colors.transparent,
          shape: isModern
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(colors.cardRadius),
                  side: BorderSide(color: colors.border),
                )
              : null,
          title: isModern
              ? Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.health_and_safety_outlined,
                        color: colors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Alertas de palavras-passe')),
                  ],
                )
              : const Text('Alertas de palavras-passe'),
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
        );
      },
    );
  }

  Future<void> _toggleFavorite(VaultEntry entry) async {
    await _autoLock.restart();
    await ref
        .read(vaultProvider.notifier)
        .setEntryFavorite(entry.id, !entry.isFavorite);
  }

  // REMOVIDO: Modal rápido antigo não utilizado pelo FAB +.
  // Seguro remover; funcionalidade atual usa RouterPaths.vaultEntryNew.
  Future<void> _openNewEntry() async {
    final parentContext = context;
    await _autoLock.restart();
    if (!parentContext.mounted) return;
    parentContext.push(RouterPaths.vaultEntryNew);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);
    final vault = ref.watch(vaultProvider);
    final sortMode =
        ref.watch(vaultSortControllerProvider).valueOrNull ?? VaultSortMode.az;
    final tagDisplaySettings =
        ref.watch(tagDisplayControllerProvider).valueOrNull ??
        const TagDisplaySettings();
    final ignoredAlertExpiries = ref.watch(
      ignoredEntryAlertsProvider.select((value) => value.valueOrNull),
    );
    final entries = vault.data?.activeEntries ?? [];
    final showFilters = shouldShowVaultFilters(entries);
    final healthReport = ignoredAlertExpiries == null
        ? null
        : PasswordHealthService.analyze(
            entries,
            ignoredAlertExpiries: ignoredAlertExpiries,
          );
    final tags = <String>{};
    for (final entry in entries) {
      tags.addAll(entry.tags);
    }
    final sortedTags = tags.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final visibleHomeTags = _visibleHomeTags(sortedTags, tagDisplaySettings);
    final visibleHomeTagSet = visibleHomeTags.toSet();
    final effectiveSelectedTags =
        tagDisplaySettings.mode == TagDisplayMode.hidden
        ? <String>{}
        : _selectedTags.where(visibleHomeTagSet.contains).toSet();
    final filtered = filterAndSortEntries(
      entries: entries,
      query: _query,
      selectedTags: effectiveSelectedTags,
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
              tooltip: 'Cancelar seleção',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(_selectedEntryIds.clear),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Eliminar selecionadas',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _deleteSelectedEntries,
            ),
          if (!_selectionMode && showFilters)
            PopupMenuButton<VaultSortMode>(
              tooltip: 'Ordenar',
              color: colors.surface,
              icon: const Icon(Icons.sort_rounded),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  colors.isClassicDesign ? 10 : 16,
                ),
                side: BorderSide(color: colors.border),
              ),
              initialValue: sortMode,
              onSelected: (mode) {
                _autoLock.restart();
                ref.read(vaultSortControllerProvider.notifier).setMode(mode);
              },
              itemBuilder: (context) => VaultSortMode.values
                  .map(
                    (mode) => PopupMenuItem<VaultSortMode>(
                      value: mode,
                      child: Row(
                        children: [
                          Icon(
                            _sortModeIcon(mode),
                            size: 18,
                            color: mode == sortMode
                                ? colors.accent
                                : colors.mutedText,
                          ),
                          const SizedBox(width: 10),
                          Text(mode.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (!_selectionMode)
            IconButton(
              icon: const Icon(Icons.folder_special_outlined),
              tooltip: 'Documentos sigilosos',
              onPressed: () async {
                await _autoLock.refreshTimeout();
                if (!context.mounted) return;
                context.push(RouterPaths.vaultDocuments);
              },
            ),
          if (!_selectionMode)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configurações',
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.background,
                    gradient: !colors.isClassicDesign
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors.isDark
                                ? const [
                                    Color(0xFF030812),
                                    Color(0xFF081223),
                                    Color(0xFF170D2D),
                                  ]
                                : [
                                    colors.background,
                                    colors.surfaceRaised,
                                    colors.background,
                                  ],
                          )
                        : null,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        _VaultSummaryCard(
                          totalCount: entries.length,
                          healthReport: healthReport,
                          onShowAlerts: healthReport?.hasImportantAlerts == true
                              ? _showHealthInfo
                              : null,
                        ),
                        _VaultDocumentsShortcut(
                          count: vault.data?.documents.length ?? 0,
                          onTap: () {
                            _autoLock.restart();
                            context.push(RouterPaths.vaultDocuments);
                          },
                        ),
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
                        if (visibleHomeTags.isNotEmpty)
                          _VaultTagStrip(
                            tags: visibleHomeTags,
                            selectedTags: effectiveSelectedTags,
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
                                  _selectedTags = {..._selectedTags}
                                    ..remove(tag);
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
                                  separatorBuilder: (_, index) => SizedBox(
                                    height: colors.isClassicDesign ? 14 : 16,
                                  ),
                                  itemBuilder: (context, index) {
                                    final entry = filtered[index];
                                    return _VaultFeedCard(
                                      entry: entry,
                                      selected: _selectedEntryIds.contains(
                                        entry.id,
                                      ),
                                      selectionMode: _selectionMode,
                                      formattedDate: _formatDate(
                                        entry.updatedAt,
                                      ),
                                      subtitle: _entrySubtitle(entry),
                                      onTap: () {
                                        _autoLock.restart();
                                        if (_selectionMode) {
                                          _toggleSelection(entry.id);
                                        } else {
                                          context.push(
                                            RouterPaths.vaultEntryView(
                                              entry.id,
                                            ),
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
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              tooltip: 'Nova entrada',
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              onPressed: _openNewEntry,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  colors.isClassicDesign ? 14 : 18,
                ),
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

class _VaultSummaryCard extends StatelessWidget {
  const _VaultSummaryCard({
    required this.totalCount,
    required this.healthReport,
    required this.onShowAlerts,
  });

  final int totalCount;
  final PasswordHealthReport? healthReport;
  final VoidCallback? onShowAlerts;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);
    final tokens = EncryVaultTheme.of(context);
    final isClassic = colors.isClassicDesign;
    final alertCount = healthReport == null
        ? 0
        : healthReport!.weak +
              healthReport!.reused +
              healthReport!.old +
              healthReport!.empty +
              healthReport!.oldTrash;
    final hasAlerts = alertCount > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, isClassic ? 12 : 10, 16, 10),
      child: AppSurface(
        elevated: !isClassic,
        minHeight: isClassic ? 70 : 78,
        radius: isClassic ? 12 : 18,
        padding: EdgeInsets.symmetric(
          horizontal: isClassic ? 18 : 20,
          vertical: isClassic ? 14 : 16,
        ),
        child: Row(
          children: [
            Text(
              totalCount.toString(),
              style: TextStyle(
                color: colors.primaryText,
                fontSize: isClassic ? 28 : 30,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isClassic ? 'entradas guardadas' : 'entradas ativas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isClassic
                          ? colors.primaryText
                          : colors.secondaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  if (isClassic && hasAlerts) ...[
                    const SizedBox(height: 5),
                    Text(
                      '$alertCount alertas importantes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isClassic && hasAlerts)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onShowAlerts,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.warning.withValues(
                      alpha: tokens.isDark ? 0.2 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tokens.warning.withValues(
                        alpha: tokens.isDark ? 0.64 : 0.42,
                      ),
                    ),
                  ),
                  child: Text(
                    '$alertCount alertas',
                    style: TextStyle(
                      color: colors.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VaultDocumentsShortcut extends StatelessWidget {
  const _VaultDocumentsShortcut({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);
    final tokens = EncryVaultTheme.of(context);
    final isClassic = colors.isClassicDesign;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AppSurface(
        elevated: !isClassic,
        radius: isClassic ? 12 : 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(isClassic ? 10 : 14),
                border: Border.all(color: tokens.border),
              ),
              child: Icon(
                Icons.folder_special_outlined,
                color: tokens.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documentos sigilosos',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    count == 1
                        ? '1 documento guardado'
                        : '$count documentos guardados',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: tokens.textMuted),
          ],
        ),
      ),
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
    final isClassic = colors.isClassicDesign;
    final isModern = usesModernVaultFilterSurfaces(colors.designMode);

    final field = TextField(
      controller: controller,
      cursorColor: colors.accent,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: colors.primaryText, fontSize: 14),
      decoration: InputDecoration(
        hintText: isClassic ? 'Pesquisar entradas' : 'Pesquisar no cofre',
        hintStyle: TextStyle(color: colors.mutedText),
        prefixIcon: isClassic
            ? null
            : Icon(Icons.search_rounded, color: colors.accent, size: 20),
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
        fillColor: isClassic
            ? colors.background
            : isModern
            ? Colors.transparent
            : colors.surface,
        constraints: BoxConstraints(minHeight: isModern ? 54 : 48),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: isModern
            ? InputBorder.none
            : _searchBorder(colors.border, isClassic ? 12 : 16),
        enabledBorder: isModern
            ? InputBorder.none
            : _searchBorder(colors.border, isClassic ? 12 : 16),
        focusedBorder: isModern
            ? InputBorder.none
            : _searchBorder(
                colors.accent.withValues(alpha: 0.72),
                isClassic ? 12 : 16,
              ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, isClassic ? 10 : 8, 16, 12),
      child: isModern
          ? AppSurface(
              elevated: true,
              padding: EdgeInsets.zero,
              radius: colors.cardRadius,
              borderColor: colors.accent.withValues(alpha: 0.22),
              child: field,
            )
          : field,
    );
  }

  OutlineInputBorder _searchBorder(Color color, double radius) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
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
    final isClassic = colors.isClassicDesign;
    final isModern = usesModernVaultFilterSurfaces(colors.designMode);

    final strip = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: isModern ? 12 : 16),
      child: Row(
        children: [
          _VaultChoiceChip(
            label: 'Todas',
            selected: selectedCategory == null,
            onSelected: (selected) {
              if (selected) onCategoryChanged(null);
            },
          ),
          const SizedBox(width: 8),
          _VaultFilterChip(
            label: 'Favoritos',
            selected: favoritesOnly,
            icon: isClassic ? null : Icons.star_rounded,
            iconColor: favoritesOnly ? colors.favorite : colors.mutedText,
            onSelected: onFavoritesChanged,
          ),
          const SizedBox(width: 8),
          ...VaultEntryCategory.values.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _VaultChoiceChip(
                label: category.label,
                selected: selectedCategory == category,
                icon: isClassic ? null : vaultEntryCategoryIcon(category),
                iconColor: vaultEntryCategoryColor(category, colors.isDark),
                onSelected: (selected) {
                  onCategoryChanged(selected ? category : null);
                },
              ),
            ),
          ),
        ],
      ),
    );

    if (!isModern) return strip;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppSurface(
        elevated: true,
        padding: const EdgeInsets.symmetric(vertical: 10),
        radius: colors.cardRadius,
        child: strip,
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
    final colors = _VaultHomeColors.from(context);
    final isModern = usesModernVaultFilterSurfaces(colors.designMode);
    final strip = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(
        isModern ? 12 : 16,
        10,
        isModern ? 12 : 16,
        0,
      ),
      child: Row(
        children: [
          _VaultChoiceChip(
            label: 'Todas as etiquetas',
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

    if (!isModern) return strip;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: AppSurface(
        elevated: true,
        padding: const EdgeInsets.only(bottom: 10),
        radius: colors.cardRadius,
        child: strip,
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
    final isClassic = colors.isClassicDesign;
    final entryLabel = visibleCount == 1 ? 'entrada' : 'entradas';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, isClassic ? 28 : 18, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isClassic
                  ? 'Recentes'
                  : '$visibleCount $entryLabel · ${sortLabel.replaceAll('-', '‑')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.secondaryText,
                fontSize: isClassic ? 14 : 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          if (isClassic)
            Flexible(
              child: Text(
                totalCount == visibleCount
                    ? '$visibleCount $entryLabel'
                    : '$visibleCount de $totalCount',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: colors.mutedText,
                  fontSize: 12.5,
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
    final isClassic = colors.isClassicDesign;
    final accent = vaultEntryCategoryColor(
      widget.entry.category,
      colors.isDark,
    );
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
        constraints: BoxConstraints(minHeight: isClassic ? 70 : 88),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(colors.cardRadius),
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
          borderRadius: BorderRadius.circular(colors.cardRadius),
          child: Stack(
            children: [
              if (isClassic)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: ColoredBox(color: accent.withValues(alpha: 0.8)),
                ),
              Material(
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
                    padding: EdgeInsets.fromLTRB(
                      isClassic ? 20 : 16,
                      isClassic ? 12 : 16,
                      isClassic ? 14 : 14,
                      isClassic ? 12 : 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                        if (!isClassic) ...[
                          VaultCategoryIcon(
                            category: widget.entry.category,
                            size: 48,
                            iconSize: 21,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: _EntryContent(
                            entry: widget.entry,
                            accent: accent,
                            formattedDate: widget.formattedDate,
                            subtitle: widget.subtitle,
                          ),
                        ),
                        if (isClassic)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              widget.entry.category.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: colors.secondaryText,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (!widget.selectionMode && isClassic)
                          IconButton(
                            tooltip: widget.entry.isFavorite
                                ? 'Remover dos favoritos'
                                : 'Adicionar aos favoritos',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            padding: EdgeInsets.zero,
                            iconSize: 18,
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
                        if (!widget.selectionMode && !isClassic)
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
            ],
          ),
        ),
      ),
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
    final isClassic = colors.isClassicDesign;
    final subtitleText = entry.username.trim().isNotEmpty
        ? entry.username
        : subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.primaryText,
            fontSize: isClassic ? 14.5 : 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            if (!isClassic) ...[
              Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: colors.mutedText,
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                subtitleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.secondaryText,
                  fontSize: isClassic ? 13 : 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        if (!isClassic) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              _EntryCategoryPill(label: entry.category.label),
              const Spacer(),
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
      ],
    );
  }
}

class _EntryCategoryPill extends StatelessWidget {
  const _EntryCategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _VaultHomeColors.from(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceRaised.withValues(alpha: colors.isDark ? 0.54 : 1),
        borderRadius: BorderRadius.circular(colors.chipRadius),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(colors.chipRadius),
      ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(colors.chipRadius),
      ),
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
                  borderRadius: BorderRadius.circular(colors.cardRadius),
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
                'Cria a primeira conta para começar a organizar o teu cofre.',
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

List<String> _visibleHomeTags(
  List<String> sortedTags,
  TagDisplaySettings settings,
) {
  switch (settings.mode) {
    case TagDisplayMode.all:
      return sortedTags;
    case TagDisplayMode.custom:
      return sortedTags.where(settings.isTagExposed).toList();
    case TagDisplayMode.hidden:
      return const [];
  }
}

bool usesModernVaultFilterSurfaces(AppDesignMode designMode) {
  return designMode == AppDesignMode.modern;
}

IconData _sortModeIcon(VaultSortMode mode) {
  switch (mode) {
    case VaultSortMode.az:
      return Icons.sort_by_alpha_rounded;
    case VaultSortMode.za:
      return Icons.sort_by_alpha_rounded;
    case VaultSortMode.newest:
      return Icons.fiber_new_rounded;
    case VaultSortMode.oldest:
      return Icons.history_rounded;
    case VaultSortMode.recentlyEdited:
      return Icons.edit_calendar_outlined;
    case VaultSortMode.recentlyOpened:
      return Icons.visibility_outlined;
    case VaultSortMode.mostUsed:
      return Icons.trending_up_rounded;
    case VaultSortMode.leastUsed:
      return Icons.trending_down_rounded;
    case VaultSortMode.category:
      return Icons.category_outlined;
  }
}
