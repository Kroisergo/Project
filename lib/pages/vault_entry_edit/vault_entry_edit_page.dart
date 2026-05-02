import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../models/vault_entry.dart';
import '../../services/security/entry_password_generator.dart';
import '../../services/security/master_password_policy.dart';
import '../../services/security/password_feedback_service.dart';
import '../../services/security/password_health_service.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/vault_state.dart';
import '../../widgets/password_generator_options.dart';
import '../../widgets/password_policy_status.dart';
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
            content: Text('Sessão bloqueada. Reentra para gravar.'),
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
      appBar: AppBar(title: Text(isNew ? 'Nova entrada' : 'Editar entrada')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _autoLock.restart(),
        onPanDown: (_) => _autoLock.restart(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                    labelText: 'Utilizador/Email',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL / Website',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 8),
                _PopularSiteButtons(onSelected: _setSiteUrl),
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
                PasswordPolicyStatus(result: passwordPolicy),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recomendação: usa uma palavra-passe forte, mas podes guardar qualquer palavra-passe.',
                    style: Theme.of(context).textTheme.bodySmall,
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
                DropdownButtonFormField<VaultEntryCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
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
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (separadas por vírgula)',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isNew ? 'Criar' : 'Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PopularSiteButtons extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _PopularSiteButtons({required this.onSelected});

  static const _sites = [
    _PopularSite(
      label: 'Instagram',
      url: 'https://www.instagram.com/',
      icon: FontAwesomeIcons.instagram,
    ),
    _PopularSite(
      label: 'Facebook',
      url: 'https://www.facebook.com/',
      icon: FontAwesomeIcons.facebook,
    ),
    _PopularSite(
      label: 'Twitter',
      url: 'https://twitter.com/',
      icon: FontAwesomeIcons.twitter,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _sites
            .map(
              (site) => ActionChip(
                avatar: FaIcon(site.icon, size: 16),
                label: Text(site.label),
                onPressed: () => onSelected(site.url),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PopularSite {
  final String label;
  final String url;
  final IconData icon;

  const _PopularSite({
    required this.label,
    required this.url,
    required this.icon,
  });
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
