import 'package:flutter/material.dart';

import '../services/security/entry_password_generator.dart';

class EntryPasswordGeneratorOptionsPanel extends StatelessWidget {
  final EntryPasswordGeneratorOptions options;
  final bool hasPassword;
  final bool busy;
  final ValueChanged<EntryPasswordGeneratorOptions> onChanged;
  final VoidCallback onGenerate;

  const EntryPasswordGeneratorOptionsPanel({
    super.key,
    required this.options,
    required this.hasPassword,
    required this.busy,
    required this.onChanged,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Gerador de palavra-passe'),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Row(
          children: [
            const Text('Comprimento'),
            const Spacer(),
            Text(options.length.toString()),
          ],
        ),
        Slider(
          min: EntryPasswordGenerator.minLength.toDouble(),
          max: 64,
          divisions: 64 - EntryPasswordGenerator.minLength,
          value: options.length.toDouble(),
          label: options.length.toString(),
          onChanged: busy
              ? null
              : (value) {
                  onChanged(options.copyWith(length: value.round()));
                },
        ),
        _GeneratorSwitch(
          title: 'Maiúsculas',
          value: options.includeUppercase,
          onChanged: busy
              ? null
              : (value) => onChanged(options.copyWith(includeUppercase: value)),
        ),
        _GeneratorSwitch(
          title: 'Minúsculas',
          value: options.includeLowercase,
          onChanged: busy
              ? null
              : (value) => onChanged(options.copyWith(includeLowercase: value)),
        ),
        _GeneratorSwitch(
          title: 'Números',
          value: options.includeNumbers,
          onChanged: busy
              ? null
              : (value) => onChanged(options.copyWith(includeNumbers: value)),
        ),
        _GeneratorSwitch(
          title: 'Símbolos',
          value: options.includeSymbols,
          onChanged: busy
              ? null
              : (value) => onChanged(options.copyWith(includeSymbols: value)),
        ),
        _GeneratorSwitch(
          title: 'Evitar caracteres ambíguos',
          subtitle: 'Evita O, 0, l, 1 e I',
          value: options.avoidAmbiguous,
          onChanged: busy
              ? null
              : (value) => onChanged(options.copyWith(avoidAmbiguous: value)),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: busy || !options.hasAnyGroup ? null : onGenerate,
            icon: const Icon(Icons.key),
            label: Text(hasPassword ? 'Regenerar' : 'Gerar'),
          ),
        ),
        if (!options.hasAnyGroup)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ativa pelo menos um tipo de caracteres.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class _GeneratorSwitch extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _GeneratorSwitch({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}
