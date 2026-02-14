import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/vault_entry.dart';
import '../../services/crypto/sodium_provider.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/vault_state.dart';
import '../vault_entry_view/vault_entry_view_page.dart';
import '../vault_home/vault_home_page.dart';
import '../unlock/unlock_page.dart';

class VaultEntryEditPage extends ConsumerStatefulWidget {
  static const subPath = 'entry/:entryId/edit';
  static const newSubPath = 'entry/new';
  static const routeName = 'vault-entry-edit';

  final String? entryId;

  const VaultEntryEditPage({super.key, this.entryId});

  @override
  ConsumerState<VaultEntryEditPage> createState() => _VaultEntryEditPageState();
}

class _VaultEntryEditPageState extends ConsumerState<VaultEntryEditPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  VaultEntry? _existing;
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
    _loadExisting();
  }

  void _loadExisting() {
    if (widget.entryId == null) return;
    final vault = ref.read(vaultProvider);
    final list = vault.data?.entries ?? [];
    for (final entry in list) {
      if (entry.id == widget.entryId) {
        _existing = entry;
        _titleController.text = entry.title;
        _userController.text = entry.username;
        _passController.text = entry.password;
        _notesController.text = entry.notes;
        _tagsController.text = entry.tags.join(', ');
        break;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoLock.cancel();
    _titleController.dispose();
    _userController.dispose();
    _passController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
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
      final sodium = await ref.read(sodiumProvider.future);
      final bytes = sodium.randombytes.buf(16);
      final generated = base64UrlEncode(bytes).replaceAll('=', '').substring(0, 22);
      if (!mounted) return;
      setState(() {
        _passController.text = generated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar password: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onLocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessão bloqueada.')),
    );
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
          notes: _notesController.text,
          tags: tags,
        );
      } else {
        entryId = _existing!.id;
        await notifier.updateEntry(
          id: _existing!.id,
          title: _titleController.text,
          username: _userController.text,
          password: _passController.text,
          notes: _notesController.text,
          tags: tags,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_existing == null ? 'Entrada criada' : 'Entrada atualizada')),
      );
      if (entryId.isNotEmpty) {
        context.go('${VaultHomePage.routePath}/${VaultEntryViewPage.subPath.replaceAll(':entryId', entryId)}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessão bloqueada. Reentra para gravar.')),
        );
        context.go(UnlockPage.routePath);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _existing == null;
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
                  decoration: const InputDecoration(labelText: 'Utilizador/Email'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        _autoLock.restart();
                        setState(() => _obscure = !_obscure);
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Obrigatório';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _generatePassword,
                    icon: const Icon(Icons.key),
                    label: const Text('Gerar password'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(labelText: 'Tags (separadas por vírgula)'),
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
