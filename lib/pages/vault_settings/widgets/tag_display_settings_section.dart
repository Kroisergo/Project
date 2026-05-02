import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/tag_display_mode.dart';
import '../../../models/vault_entry.dart';
import '../../../services/vault/tag_display_controller.dart';
import '../../../services/vault/vault_state.dart';

class TagDisplaySettingsSection extends ConsumerWidget {
  const TagDisplaySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(tagDisplayControllerProvider).valueOrNull ??
        const TagDisplaySettings();
    final entries = ref.watch(vaultProvider).data?.activeEntries ?? [];
    final tags = _availableTags(entries);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visual das etiquetas',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<TagDisplayMode>(
            initialValue: settings.mode,
            decoration: const InputDecoration(labelText: 'Modo'),
            items: TagDisplayMode.values
                .map(
                  (mode) =>
                      DropdownMenuItem(value: mode, child: Text(mode.label)),
                )
                .toList(),
            onChanged: (mode) {
              if (mode == null) return;
              ref.read(tagDisplayControllerProvider.notifier).setMode(mode);
            },
          ),
          const SizedBox(height: 6),
          Text(
            settings.mode.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (settings.mode == TagDisplayMode.custom) ...[
            const SizedBox(height: 12),
            if (tags.isEmpty)
              Text(
                'Ainda não existem etiquetas para expor.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    FilterChip(
                      label: Text(tag),
                      selected: settings.isTagExposed(tag),
                      onSelected: (selected) {
                        ref
                            .read(tagDisplayControllerProvider.notifier)
                            .setTagExposed(tag, selected);
                      },
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  static List<String> _availableTags(List<VaultEntry> entries) {
    final tags = <String>{};
    for (final entry in entries) {
      tags.addAll(entry.tags);
    }
    return tags.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }
}
