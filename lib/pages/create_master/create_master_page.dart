import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/security/entry_password_generator.dart';
import '../../services/security/master_password_policy.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/storage/vault_file_service.dart';
import '../../services/vault/vault_service.dart';
import '../../widgets/password_generator_options.dart';
import '../../widgets/password_policy_status.dart';
import '../unlock/unlock_page.dart';
import '../welcome/welcome_page.dart';

class CreateMasterPage extends ConsumerStatefulWidget {
  static const routePath = '/create-master';
  static const routeName = 'create-master';

  const CreateMasterPage({super.key});

  @override
  ConsumerState<CreateMasterPage> createState() => _CreateMasterPageState();
}

class _CreateMasterPageState extends ConsumerState<CreateMasterPage> {
  final _formKey = GlobalKey<FormState>();
  final _masterController = TextEditingController();
  final _confirmController = TextEditingController();
  final _vaultNameController = TextEditingController();
  EntryPasswordGeneratorOptions _generatorOptions =
      const EntryPasswordGeneratorOptions(length: 24);
  bool _obscure = true;
  bool _loading = false;

  MasterPasswordPolicyResult get _masterPolicy =>
      MasterPasswordPolicy.evaluate(_masterController.text);

  void _generateMasterPassword() {
    try {
      final generated = EntryPasswordGenerator.generate(_generatorOptions);
      setState(() {
        _masterController.text = generated;
        _confirmController.text = generated;
        _obscure = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar palavra-passe: $e')),
      );
    }
  }

  @override
  void dispose() {
    _masterController.clear();
    _confirmController.clear();
    _vaultNameController.clear();
    _masterController.dispose();
    _confirmController.dispose();
    _vaultNameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _loading = true);
    try {
      final vaultService = ref.read(vaultServiceProvider);
      final fileService = VaultFileService();
      final prefs = ref.read(preferencesServiceProvider);
      final normalizedName = fileService.normalizeVaultName(
        _vaultNameController.text.trim().isEmpty
            ? null
            : _vaultNameController.text,
      );
      await vaultService.createVault(
        masterPassword: _masterController.text,
        fileName: normalizedName,
      );
      await prefs.setVaultFileName(normalizedName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cofre criado com sucesso.')),
      );
      _masterController.clear();
      _confirmController.clear();
      context.go(UnlockPage.routePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao criar cofre: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = _masterPolicy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar palavra-passe mestra'),
        leading: BackButton(onPressed: () => context.go(WelcomePage.routePath)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Define a tua palavra-passe mestra para cifrar todo o cofre.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vaultNameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do ficheiro (opcional)',
                  hintText: 'ex: EncryVault.vltx',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _masterController,
                obscureText: _obscure,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Palavra-passe mestra',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return 'Obrigatorio';
                  final result = MasterPasswordPolicy.evaluate(value);
                  if (!result.isValid) {
                    return result.firstMissingRequirement ??
                        'A palavra-passe mestra nao cumpre os requisitos.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              PasswordPolicyStatus(result: policy),
              const SizedBox(height: 8),
              EntryPasswordGeneratorOptionsPanel(
                options: _generatorOptions,
                hasPassword: _masterController.text.isNotEmpty,
                busy: _loading,
                onChanged: (options) {
                  setState(() => _generatorOptions = options);
                },
                onGenerate: _generateMasterPassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Confirmar palavra-passe',
                ),
                validator: (v) {
                  if (v != _masterController.text) {
                    return 'As palavras-passe nao coincidem';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading || !policy.isValid ? null : _create,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar Cofre'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
