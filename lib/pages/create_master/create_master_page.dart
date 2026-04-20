import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/security/master_password_policy.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/storage/vault_file_service.dart';
import '../../services/vault/vault_service.dart';
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
  bool _obscure = true;
  bool _loading = false;

  MasterPasswordPolicyResult get _masterPolicy =>
      MasterPasswordPolicy.evaluate(_masterController.text);

  @override
  void dispose() {
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
        title: const Text('Criar Password Mestra'),
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
                'Define a tua password mestra para cifrar todo o cofre.',
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
                  labelText: 'Password Mestra',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return 'Obrigatório';
                  final result = MasterPasswordPolicy.evaluate(value);
                  if (!result.isValid) {
                    return result.firstMissingRequirement ??
                        'A password mestra não cumpre os requisitos.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PasswordPolicyStatus(result: policy),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Confirmar Password',
                ),
                validator: (v) {
                  if (v != _masterController.text) {
                    return 'Passwords não coincidem';
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

class _PasswordPolicyStatus extends StatelessWidget {
  const _PasswordPolicyStatus({required this.result});

  final MasterPasswordPolicyResult result;

  @override
  Widget build(BuildContext context) {
    final strength = result.strength;
    final color =
        strength?.statusColor ?? Theme.of(context).colorScheme.outline;
    final value = strength?.widthPerc ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: value,
            color: color,
            backgroundColor: color.withAlpha(40),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Força: ${_strengthLabel(strength?.name)}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        ...result.requirements.map(_RequirementRow.new),
      ],
    );
  }

  String _strengthLabel(String? name) {
    return switch (name) {
      'alreadyExposed' => 'Exposta',
      'weak' => 'Fraca',
      'medium' => 'Média',
      'strong' => 'Forte',
      'secure' => 'Segura',
      _ => 'Por avaliar',
    };
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow(this.requirement);

  final PasswordRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final color = requirement.met
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            requirement.met
                ? Icons.check_circle_outline
                : Icons.cancel_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(requirement.label)),
        ],
      ),
    );
  }
}
