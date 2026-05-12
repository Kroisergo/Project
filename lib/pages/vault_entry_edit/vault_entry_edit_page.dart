import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/design_tokens.dart';
import '../../models/app_design_mode.dart';
import '../../models/quick_link_preset.dart';
import '../../models/vault_entry.dart';
import '../../services/security/entry_password_generator.dart';
import '../../services/security/master_password_policy.dart';
import '../../services/security/password_feedback_service.dart';
import '../../services/security/password_health_service.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/vault_state.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/password_generator_options.dart';
import '../../widgets/password_policy_status.dart';
import '../../widgets/quick_link_icon.dart';
import '../../widgets/quick_link_preset_dialog.dart';
import '../../widgets/vault_category_icon.dart';
import '../unlock/unlock_page.dart';
import '../vault_entry_view/vault_entry_view_page.dart';
import '../vault_home/vault_home_page.dart';

class VaultEntryEditPage extends ConsumerStatefulWidget {
  static const subPath = 'entry/:entryId/edit';
  static const newSubPath = 'entry/new';
  static const routeName = 'vault-entry-edit';

  final String? entryId;

  const VaultEntryEditPage({super.key, this.entryId});

  @override
  ConsumerState<VaultEntryEditPage> createState() => _VaultEntryEditPageState();
}

class _VaultEntryEditPageState extends ConsumerState<VaultEntryEditPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();
  EntryPasswordGeneratorOptions _generatorOptions =
      const EntryPasswordGeneratorOptions();
  bool _obscure = true;
  bool _saving = false;
  VaultEntry? _existing;
  VaultEntryCategory _category = VaultEntryCategory.other;
  List<QuickLinkPreset> _customQuickLinks = const [];
  late final AutoLockController _autoLock;

  MasterPasswordPolicyResult get _passwordPolicy =>
      MasterPasswordPolicy.evaluate(_passController.text);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoLock = AutoLockController(ref: ref, onTimeout: _onLocked);
    _autoLock.restart();
    _loadExisting();
    _loadQuickLinks();
  }

  void _loadExisting() {
    if (widget.entryId == null) return;
    final vault = ref.read(vaultProvider);
    final list = vault.data?.activeEntries ?? [];
    for (final entry in list) {
      if (entry.id == widget.entryId) {
        _existing = entry;
        _titleController.text = entry.title;
        _userController.text = entry.username;
        _passController.text = entry.password;
        _urlController.text = entry.url;
        _notesController.text = entry.notes;
        _category = entry.category;
        _tagsController.text = entry.tags.join(', ');
        break;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoLock.cancel();
    _clearControllers();
    _titleController.dispose();
    _userController.dispose();
    _passController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _clearControllers() {
    _titleController.clear();
    _userController.clear();
    _passController.clear();
    _urlController.clear();
    _notesController.clear();
    _tagsController.clear();
  }

  Future<void> _setSiteUrl(String url) async {
    await _autoLock.restart();
    if (!mounted) return;
    setState(() => _urlController.text = url);
  }

  Future<void> _loadQuickLinks() async {
    final links = await ref
        .read(preferencesServiceProvider)
        .getCustomQuickLinks();
    if (!mounted) return;
    setState(() => _customQuickLinks = links);
  }

  Future<void> _addQuickLink() async {
    await _autoLock.restart();
    if (!mounted) return;
    final result = await showDialog<QuickLinkPresetDialogResult>(
      context: context,
      builder: (context) => const QuickLinkPresetDialog(
        allowSaveForFuture: true,
        title: 'Adicionar link rápido',
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _urlController.text = result.preset.url);
    if (!result.saveForFuture) return;
    final nextLinks = [
      ..._customQuickLinks.where(
        (link) =>
            link.normalizedUrl.toLowerCase() !=
            result.preset.normalizedUrl.toLowerCase(),
      ),
      result.preset,
    ];
    await ref.read(preferencesServiceProvider).setCustomQuickLinks(nextLinks);
    if (!mounted) return;
    setState(() => _customQuickLinks = nextLinks);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link rápido guardado para futuras entradas.'),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _autoLock.handleLifecycle(state);
  }

  Future<void> _generatePassword() async {
    await _autoLock.restart();
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final generated = EntryPasswordGenerator.generate(_generatorOptions);
      if (!mounted) return;
      setState(() {
        _passController.text = generated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar palavra-passe: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onLocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sessão bloqueada.')));
    context.go(UnlockPage.routePath);
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    await _autoLock.restart();
    if (!mounted) return;
    setState(() => _saving = true);
    final notifier = ref.read(vaultProvider.notifier);
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    try {
      String entryId;
      if (_existing == null) {
        entryId = await notifier.addEntry(
          title: _titleController.text,
          username: _userController.text,
          password: _passController.text,
          url: _urlController.text.trim(),
          notes: _notesController.text,
          category: _category,
          tags: tags,
        );
      } else {
        entryId = _existing!.id;
        await notifier.updateEntry(
          id: _existing!.id,
          title: _titleController.text,
          username: _userController.text,
          password: _passController.text,
          url: _urlController.text.trim(),
          notes: _notesController.text,
          category: _category,
          tags: tags,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _existing == null ? 'Entrada criada' : 'Entrada atualizada',
          ),
        ),
      );
      _clearControllers();
      if (entryId.isNotEmpty) {
        context.go(
          '${VaultHomePage.routePath}/${VaultEntryViewPage.subPath.replaceAll(':entryId', entryId)}',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão bloqueada. Volta a entrar para gravar.'),
          ),
        );
        context.go(UnlockPage.routePath);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final isClassic = tokens.designMode == AppDesignMode.classic;
    final useModernCategoryCards = usesModernEntryCategoryCards(
      tokens.designMode,
    );
    final isNew = _existing == null;
    final passwordPolicy = _passwordPolicy;
    final entries = ref.watch(vaultProvider).data?.activeEntries ?? [];
    final reuseCount = PasswordHealthService.reuseCountForPassword(
      entries,
      _passController.text,
      excludeEntryId: _existing?.id,
    );
    final passwordFeedback = PasswordFeedbackService.messages(
      password: _passController.text,
      isReused: reuseCount > 0,
    );
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: Text(isNew ? 'Nova entrada' : 'Editar entrada')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _autoLock.restart(),
        onPanDown: (_) => _autoLock.restart(),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Obrigatório';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _userController,
                  decoration: const InputDecoration(
                    labelText: 'Utilizador/correio eletrónico',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL / site',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 8),
                _QuickLinkButtons(
                  links: effectiveQuickLinkPresets(_customQuickLinks),
                  onSelected: _setSiteUrl,
                  onAdd: _addQuickLink,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passController,
                  obscureText: _obscure,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Palavra-passe',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        _autoLock.restart();
                        setState(() => _obscure = !_obscure);
                      },
                    ),
                  ),
                  validator: (v) {
                    final value = v ?? '';
                    if (value.isEmpty) return 'Obrigatório';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppSurface(
                  elevated: !isClassic,
                  minHeight: 76,
                  radius: isClassic ? 10 : tokens.cardRadius,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  leadingAccentColor: isClassic ? tokens.accentMuted : null,
                  leadingAccentWidth: isClassic ? 3 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PasswordPolicyStatus(result: passwordPolicy),
                      const SizedBox(height: 8),
                      Text(
                        'Recomendação: usa uma palavra-passe forte, mas podes guardar qualquer palavra-passe.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _PasswordFeedbackMessages(messages: passwordFeedback),
                const SizedBox(height: 8),
                EntryPasswordGeneratorOptionsPanel(
                  options: _generatorOptions,
                  hasPassword: _passController.text.isNotEmpty,
                  busy: _saving,
                  onChanged: (options) {
                    setState(() => _generatorOptions = options);
                  },
                  onGenerate: _generatePassword,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (useModernCategoryCards) {
                      return _ModernEntryCategorySection(
                        selectedCategory: _category,
                        tagsController: _tagsController,
                        onCategoryChanged: (category) {
                          _autoLock.restart();
                          setState(() => _category = category);
                        },
                      );
                    }

                    final categoryField =
                        DropdownButtonFormField<VaultEntryCategory>(
                          initialValue: _category,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                          ),
                          items: VaultEntryCategory.values
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category.label),
                                ),
                              )
                              .toList(),
                          onChanged: (category) {
                            _autoLock.restart();
                            if (category == null) return;
                            setState(() => _category = category);
                          },
                        );
                    final tagsField = TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(labelText: 'Etiquetas'),
                    );

                    if (constraints.maxWidth < 380) {
                      return Column(
                        children: [
                          categoryField,
                          const SizedBox(height: 12),
                          tagsField,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: categoryField),
                        const SizedBox(width: 12),
                        Expanded(child: tagsField),
                      ],
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Separadas por vírgula.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isNew ? 'Criar' : 'Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernEntryCategorySection extends StatelessWidget {
  const _ModernEntryCategorySection({
    required this.selectedCategory,
    required this.tagsController,
    required this.onCategoryChanged,
  });

  final VaultEntryCategory selectedCategory;
  final TextEditingController tagsController;
  final ValueChanged<VaultEntryCategory> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSurface(
          elevated: true,
          radius: tokens.cardRadius,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categoria',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 360;
                  final itemWidth = twoColumns
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final category in VaultEntryCategory.values)
                        SizedBox(
                          width: itemWidth,
                          child: _ModernEntryCategoryOption(
                            category: category,
                            selected: selectedCategory == category,
                            onTap: () => onCategoryChanged(category),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: tagsController,
          decoration: const InputDecoration(labelText: 'Etiquetas'),
        ),
      ],
    );
  }
}

class _ModernEntryCategoryOption extends StatelessWidget {
  const _ModernEntryCategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final VaultEntryCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final accent = vaultEntryCategoryColor(category, tokens.isDark);

    return Material(
      color: selected
          ? accent.withValues(alpha: tokens.isDark ? 0.18 : 0.1)
          : tokens.surfaceRaised.withValues(alpha: tokens.isDark ? 0.5 : 1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.7) : tokens.border,
            ),
          ),
          child: Row(
            children: [
              VaultCategoryIcon(category: category, size: 34, iconSize: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

bool usesModernEntryCategoryCards(AppDesignMode designMode) {
  return designMode == AppDesignMode.modern;
}

class _QuickLinkButtons extends StatelessWidget {
  final List<QuickLinkPreset> links;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;

  const _QuickLinkButtons({
    required this.links,
    required this.onSelected,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final modern = tokens.designMode == AppDesignMode.modern;
    final previewLinks = previewQuickLinkPresets(links);
    final remainingLinks = remainingQuickLinkPresets(links);
    final chips = [
      for (final link in previewLinks)
        ActionChip(
          avatar: Icon(quickLinkIconData(link.icon), size: 16),
          label: Text(link.label),
          onPressed: () => onSelected(link.url),
        ),
      if (remainingLinks.isNotEmpty)
        ActionChip(
          avatar: const Icon(Icons.more_horiz_rounded, size: 16),
          label: const Text('Mais'),
          onPressed: () => _openMoreLinks(context, remainingLinks),
        )
      else
        ActionChip(
          avatar: const Icon(Icons.add_link_outlined, size: 16),
          label: const Text('Adicionar'),
          onPressed: onAdd,
        ),
    ];

    if (!modern) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
      );
    }

    return AppSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      radius: tokens.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Links rápidos',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  Future<void> _openMoreLinks(
    BuildContext context,
    List<QuickLinkPreset> remainingLinks,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final tokens = EncryVaultTheme.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(
              tokens.pagePadding,
              4,
              tokens.pagePadding,
              tokens.pagePadding,
            ),
            children: [
              Text(
                'Mais links',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final link in remainingLinks)
                ListTile(
                  leading: QuickLinkIconBadge(icon: link.icon),
                  title: Text(link.label),
                  subtitle: Text(link.url),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onSelected(link.url);
                  },
                ),
              const Divider(height: 18),
              ListTile(
                leading: const Icon(Icons.add_link_outlined),
                title: const Text('Adicionar link personalizado'),
                subtitle: const Text('Usar agora e, se quiseres, guardar.'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onAdd();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PasswordFeedbackMessages extends StatelessWidget {
  final List<String> messages;

  const _PasswordFeedbackMessages({required this.messages});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages
            .map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
