import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage/preferences_service.dart';
import '../services/vault/vault_repository.dart';
import '../services/vault/vault_state.dart';

Future<bool> confirmSensitiveAction({
  required BuildContext context,
  required WidgetRef ref,
  String title = 'Confirmar ação sensível',
  String message = 'Introduz a palavra-passe mestra para continuar.',
}) async {
  final prefs = ref.read(preferencesServiceProvider);
  final isRequired = await prefs.getRequireSensitiveActionConfirmation();
  if (!isRequired) return true;
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SensitiveActionConfirmationDialog(
      title: title,
      message: message,
      verifier: (password) async {
        final vault = ref.read(vaultProvider);
        if (!vault.isUnlocked) return false;
        try {
          final result = await ref
              .read(vaultRepositoryProvider)
              .loadAndDecrypt(
                masterPassword: password,
                fileName: vault.fileName,
              );
          result.key.dispose();
          return true;
        } on VaultAuthException {
          return false;
        } catch (_) {
          return false;
        }
      },
    ),
  );
  return confirmed ?? false;
}

class _SensitiveActionConfirmationDialog extends StatefulWidget {
  final String title;
  final String message;
  final Future<bool> Function(String password) verifier;

  const _SensitiveActionConfirmationDialog({
    required this.title,
    required this.message,
    required this.verifier,
  });

  @override
  State<_SensitiveActionConfirmationDialog> createState() =>
      _SensitiveActionConfirmationDialogState();
}

class _SensitiveActionConfirmationDialogState
    extends State<_SensitiveActionConfirmationDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text;
    if (password.isEmpty) {
      setState(() => _error = 'Introduz a palavra-passe mestra.');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final valid = await widget.verifier(password);
    if (!mounted) return;
    if (!valid) {
      setState(() {
        _error = 'Palavra-passe mestra incorreta.';
        _submitting = false;
      });
      return;
    }

    _controller.clear();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(widget.message)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Palavra-passe mestra',
              errorText: _error,
            ),
            onSubmitted: (_) async => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}
