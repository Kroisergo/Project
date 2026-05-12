import 'package:flutter/material.dart';

class UnlockForm extends StatefulWidget {
  const UnlockForm({
    super.key,
    required this.onUnlock,
    this.enabled = true,
    this.middle,
    this.buttonLabel = 'Desbloquear',
    this.onLoadingChanged,
  });

  final Future<void> Function(String masterPassword) onUnlock;
  final bool enabled;
  final Widget? middle;
  final String buttonLabel;
  final ValueChanged<bool>? onLoadingChanged;

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
    _masterController.clear();
    _masterController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.enabled) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _loading = true);
    widget.onLoadingChanged?.call(true);
    await WidgetsBinding.instance.endOfFrame;
    final masterPassword = _masterController.text;
    try {
      await widget.onUnlock(masterPassword);
    } finally {
      _masterController.clear();
      widget.onLoadingChanged?.call(false);
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
            enabled: widget.enabled && !_loading,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Palavra-passe mestra',
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
          if (widget.middle == null)
            const SizedBox(height: 20)
          else ...[
            const SizedBox(height: 24),
            widget.middle!,
            const SizedBox(height: 88),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_loading || !widget.enabled) ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
