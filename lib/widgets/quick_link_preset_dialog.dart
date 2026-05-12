import 'package:flutter/material.dart';

import '../models/quick_link_preset.dart';
import 'quick_link_icon.dart';

class QuickLinkPresetDialogResult {
  final QuickLinkPreset preset;
  final bool saveForFuture;

  const QuickLinkPresetDialogResult({
    required this.preset,
    required this.saveForFuture,
  });
}

class QuickLinkPresetDialog extends StatefulWidget {
  final QuickLinkPreset? initialPreset;
  final bool allowSaveForFuture;
  final String title;
  final String actionLabel;

  const QuickLinkPresetDialog({
    super.key,
    this.initialPreset,
    this.allowSaveForFuture = false,
    this.title = 'Adicionar link rápido',
    this.actionLabel = 'Guardar',
  });

  @override
  State<QuickLinkPresetDialog> createState() => _QuickLinkPresetDialogState();
}

class _QuickLinkPresetDialogState extends State<QuickLinkPresetDialog> {
  final _labelController = TextEditingController();
  final _urlController = TextEditingController();
  QuickLinkIcon _icon = QuickLinkIcon.other;
  bool _saveForFuture = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final preset = widget.initialPreset;
    if (preset != null) {
      _labelController.text = preset.label;
      _urlController.text = preset.url;
      _icon = preset.icon;
    }
  }

  @override
  void dispose() {
    _labelController.clear();
    _urlController.clear();
    _labelController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _labelController.text.trim();
    final url = normalizeQuickLinkUrl(_urlController.text);
    if (label.isEmpty || url.isEmpty) {
      setState(() => _error = 'Preenche o nome e o link.');
      return;
    }
    Navigator.of(context).pop(
      QuickLinkPresetDialogResult(
        preset: QuickLinkPreset(label: label, url: url, icon: _icon),
        saveForFuture: widget.allowSaveForFuture ? _saveForFuture : true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _labelController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Link',
                prefixIcon: Icon(Icons.link_outlined),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<QuickLinkIcon>(
              initialValue: _icon,
              decoration: const InputDecoration(labelText: 'Ícone'),
              items: QuickLinkIcon.values
                  .map(
                    (icon) => DropdownMenuItem(
                      value: icon,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(quickLinkIconData(icon), size: 18),
                          const SizedBox(width: 10),
                          Text(icon.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (icon) {
                if (icon == null) return;
                setState(() => _icon = icon);
              },
            ),
            if (widget.allowSaveForFuture)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _saveForFuture,
                onChanged: (value) {
                  setState(() => _saveForFuture = value ?? true);
                },
                title: const Text('Guardar para futuras entradas'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}
