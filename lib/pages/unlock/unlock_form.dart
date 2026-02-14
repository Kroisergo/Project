import 'package:flutter/material.dart';

class UnlockForm extends StatefulWidget {
  const UnlockForm({
    super.key,
    required this.onUnlock,
  });

  final Future<void> Function(String masterPassword) onUnlock;

  @override
  State<UnlockForm> createState() => _UnlockFormState();
}

class _UnlockFormState extends State<UnlockForm> {
  final _formKey = GlobalKey<FormState>();
  final _masterController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _masterController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.onUnlock(_masterController.text);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _masterController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password Mestra',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Obrigatório';
              return null;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Desbloquear'),
          ),
        ],
      ),
    );
  }
}
