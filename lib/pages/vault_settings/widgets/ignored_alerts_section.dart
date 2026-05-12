import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/vault_entry.dart';
import '../../../services/security/ignored_alerts_controller.dart';
import '../../../services/security/password_health_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/time_labels.dart';

class IgnoredAlertsSection extends ConsumerWidget {
  final List<VaultEntry> entries;
  final Map<String, int> ignoredAlertExpiries;

  const IgnoredAlertsSection({
    super.key,
    required this.entries,
    required this.ignoredAlertExpiries,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _items();

    if (items.isEmpty) {
      return const ListTile(
        dense: true,
        leading: Icon(Icons.notifications_off_outlined),
        title: Text('Avisos ignorados'),
        subtitle: Text('Sem avisos ignorados ativos.'),
      );
    }

    return ExpansionTile(
      leading: const Icon(Icons.notifications_paused_outlined),
      title: const Text('Avisos ignorados'),
      subtitle: Text('${items.length} ativo(s)'),
      children: [
        for (final item in items)
          ListTile(
            dense: true,
            title: Text(item.entry.title),
            subtitle: Text('${item.alert.message}\n${item.expiryLabel}'),
            isThreeLine: true,
            trailing: PopupMenuButton<_IgnoredAlertAction>(
              tooltip: 'Gerir aviso ignorado',
              onSelected: (action) async {
                switch (action) {
                  case _IgnoredAlertAction.changeDuration:
                    await _changeDuration(context, ref, item);
                    break;
                  case _IgnoredAlertAction.remove:
                    await ref
                        .read(ignoredEntryAlertsProvider.notifier)
                        .remove(item.alert.ignoreKey);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Aviso reativado.')),
                    );
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _IgnoredAlertAction.changeDuration,
                  child: Text('Alterar duração'),
                ),
                PopupMenuItem(
                  value: _IgnoredAlertAction.remove,
                  child: Text('Reativar aviso'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<_IgnoredAlertItem> _items() {
    final cleaned = IgnoredAlertExpiries.removeExpired(ignoredAlertExpiries);
    final activeEntries = entries.where((entry) => !entry.isDeleted).toList();
    final items = <_IgnoredAlertItem>[];
    for (final entry in activeEntries) {
      final alerts = PasswordHealthService.typedAlertsForEntry(
        entries: activeEntries,
        entry: entry,
      );
      for (final alert in alerts) {
        final expiry = cleaned[alert.ignoreKey];
        if (expiry == null) continue;
        items.add(
          _IgnoredAlertItem(entry: entry, alert: alert, expiry: expiry),
        );
      }
    }
    items.sort((a, b) => a.sortValue.compareTo(b.sortValue));
    return items;
  }

  Future<void> _changeDuration(
    BuildContext context,
    WidgetRef ref,
    _IgnoredAlertItem item,
  ) async {
    final duration = await showDialog<IgnoredAlertDurationOption>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Alterar duração'),
        children: [
          for (final option in IgnoredAlertDurationOption.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(option),
              child: Text(option.label),
            ),
        ],
      ),
    );
    if (duration == null || !context.mounted) return;
    await ref
        .read(ignoredEntryAlertsProvider.notifier)
        .ignore(item.alert.ignoreKey, duration);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(duration.confirmationMessage)));
  }
}

class _IgnoredAlertItem {
  final VaultEntry entry;
  final PasswordHealthEntryAlert alert;
  final int expiry;

  const _IgnoredAlertItem({
    required this.entry,
    required this.alert,
    required this.expiry,
  });

  bool get hasExpiry => expiry != VaultConstants.ignoredAlertNoExpiryValue;

  DateTime? get expiresAt => hasExpiry
      ? DateTime.fromMillisecondsSinceEpoch(expiry, isUtc: true)
      : null;

  int get sortValue => hasExpiry ? expiry : 9223372036854775807;

  String get expiryLabel {
    final expiresAt = this.expiresAt;
    if (expiresAt == null) return 'Até ativar novamente';
    return 'Ignorado até ${formatDateTime(expiresAt)}';
  }
}

enum _IgnoredAlertAction { changeDuration, remove }
