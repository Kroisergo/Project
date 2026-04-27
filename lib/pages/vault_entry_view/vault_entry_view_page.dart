import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/vault_entry.dart';
import '../../services/security/password_entry_recommendation.dart';
import '../../services/security/password_health_service.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/router_paths.dart';
import '../../utils/time_labels.dart';
import '../unlock/unlock_page.dart';
import '../vault_home/vault_home_page.dart';

class VaultEntryViewPage extends ConsumerStatefulWidget {
  static const subPath = 'entry/:entryId';
  static const routeName = 'vault-entry-view';

  final String entryId;

  const VaultEntryViewPage({super.key, required this.entryId});

  @override
  ConsumerState<VaultEntryViewPage> createState() => _VaultEntryViewPageState();
}

class _VaultEntryViewPageState extends ConsumerState<VaultEntryViewPage>
    with WidgetsBindingObserver {
  bool _obscure = true;
  Timer? _clipboardClear;
  int _clipboardToken = 0;
  String? _lastCopiedValue;
  late final AutoLockController _autoLock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoLock = AutoLockController(ref: ref, onTimeout: _onLocked);
    _autoLock.restart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(vaultProvider.notifier).markEntryOpened(widget.entryId),
      );
    });
  }

  VaultEntry? _findEntry(List<VaultEntry> list) {
    for (final entry in list) {
      if (entry.id == widget.entryId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _copy(String label, String value) async {
    await _autoLock.restart();
    if (!mounted) return;
    _clipboardClear?.cancel();
    final token = ++_clipboardToken;
    _lastCopiedValue = value;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copiado (limpa em 30s)')));
    _clipboardClear = Timer(const Duration(seconds: 30), () async {
      if (token != _clipboardToken) return;
      final data = await Clipboard.getData('text/plain');
      if (data?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
      if (_lastCopiedValue == value) {
        _lastCopiedValue = null;
      }
    });
  }

  Future<void> _clearClipboardIfCurrent() async {
    final value = _lastCopiedValue;
    if (value == null) return;
    final data = await Clipboard.getData('text/plain');
    if (data?.text == value) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
    _lastCopiedValue = null;
  }

  Future<void> _confirmDelete(String id) async {
    await _autoLock.restart();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar entrada?'),
        content: const Text('A entrada será movida para o Lixo.'),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Apagar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      await ref.read(vaultProvider.notifier).deleteEntry(id);
      await _autoLock.restart();
      if (!mounted) return;
      context.go(VaultHomePage.routePath);
    }
  }

  void _onLocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sessão bloqueada.')));
    context.go(UnlockPage.routePath);
  }

  Future<void> _showDetails(
    VaultEntry entry,
    PasswordEntryRecommendation? recommendation,
  ) async {
    await _autoLock.restart();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EntryDetailsSheet(
        entry: entry,
        recommendation: recommendation,
        onCopy: _copy,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoLock.cancel();
    _clipboardClear?.cancel();
    unawaited(_clearClipboardIfCurrent());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _autoLock.handleLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    final activeEntries = vault.data?.activeEntries ?? [];
    final entry = _findEntry(activeEntries);
    final recommendation = entry == null
        ? null
        : PasswordEntryRecommendationService.evaluate(
            password: entry.password,
            passwordUpdatedAt: entry.passwordUpdatedAt,
          );
    final alerts = entry == null
        ? const <String>[]
        : PasswordHealthService.alertsForEntry(
            entries: activeEntries,
            entry: entry,
          );

    final actions = entry == null
        ? <Widget>[]
        : [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                _autoLock.restart();
                context.push(RouterPaths.vaultEntryEdit(entry.id));
              },
            ),
            IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                _autoLock.restart();
                setState(() => _obscure = !_obscure);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(entry.id),
            ),
          ];

    return Scaffold(
      appBar: AppBar(title: const Text('Entrada'), actions: actions),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _autoLock.restart(),
        onPanDown: (_) => _autoLock.restart(),
        child: entry == null
            ? const Center(child: Text('Entrada não encontrada.'))
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        if (alerts.isNotEmpty)
                          _EntryAlertButton(alerts: alerts),
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          tooltip: 'Detalhes',
                          onPressed: () => _showDetails(entry, recommendation),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _fieldRow(
                      'Utilizador',
                      entry.username,
                      onCopy: () => _copy('Utilizador', entry.username),
                    ),
                    const SizedBox(height: 12),
                    _fieldRow(
                      'Palavra-passe',
                      _obscure ? '********' : entry.password,
                      onCopy: () => _copy('Palavra-passe', entry.password),
                    ),
                    const SizedBox(height: 12),
                    _fieldRow(
                      'Notas',
                      entry.notes,
                      onCopy: () => _copy('Notas', entry.notes),
                    ),
                    const SizedBox(height: 16),
                    if (entry.tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: entry.tags
                            .map((tag) => Chip(label: Text(tag)))
                            .toList(),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _fieldRow(String label, String value, {VoidCallback? onCopy}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(icon: const Icon(Icons.copy), onPressed: onCopy),
      ],
    );
  }
}

class _EntryAlertButton extends StatelessWidget {
  final List<String> alerts;

  const _EntryAlertButton({required this.alerts});

  Future<void> _showAlerts(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alertas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: alerts
              .map(
                (alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(alert)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ver alertas',
      icon: Icon(
        Icons.warning_amber_outlined,
        color: Theme.of(context).colorScheme.error,
      ),
      onPressed: () => _showAlerts(context),
    );
  }
}

class _EntryDetailsSheet extends StatelessWidget {
  final VaultEntry entry;
  final PasswordEntryRecommendation? recommendation;
  final Future<void> Function(String label, String value) onCopy;

  const _EntryDetailsSheet({
    required this.entry,
    required this.recommendation,
    required this.onCopy,
  });

  Future<void> _showHistory(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PasswordHistorySheet(
        history: entry.passwordHistory.reversed.toList(),
        onCopy: onCopy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detalhes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _detailLine(context, 'Criado', formatDateTime(entry.createdAt)),
              _detailLine(
                context,
                'Atualizado',
                formatDateTime(entry.updatedAt),
              ),
              _detailLine(
                context,
                'Última abertura',
                formatDateTime(entry.lastOpenedAt),
              ),
              _detailLine(
                context,
                'Palavra-passe alterada',
                formatRelativePast(entry.passwordUpdatedAt),
              ),
              if (recommendation != null) ...[
                _detailLine(
                  context,
                  'Recomendação',
                  recommendation!.recommendationText,
                ),
                _detailLine(
                  context,
                  'Força atual',
                  recommendation!.strengthLabel,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showHistory(context),
                  icon: const Icon(Icons.history),
                  label: const Text('Ver histórico de palavra-passes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLine(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _PasswordHistorySheet extends StatefulWidget {
  final List<VaultPasswordHistoryItem> history;
  final Future<void> Function(String label, String value) onCopy;

  const _PasswordHistorySheet({required this.history, required this.onCopy});

  @override
  State<_PasswordHistorySheet> createState() => _PasswordHistorySheetState();
}

class _PasswordHistorySheetState extends State<_PasswordHistorySheet> {
  bool _showPasswords = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Histórico de palavra-passes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showPasswords = !_showPasswords;
                    });
                  },
                  icon: Icon(
                    _showPasswords ? Icons.visibility_off : Icons.visibility,
                  ),
                  label: Text(_showPasswords ? 'Ocultar' : 'Mostrar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: widget.history.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('Sem histórico de palavra-passes.'),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.history.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = widget.history[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            index == 0
                                ? 'Palavra-passe atual'
                                : 'Palavra-passe anterior $index',
                          ),
                          subtitle: Text(
                            '${_showPasswords ? item.password : '********'}\nAlterada em ${formatDateTime(item.changedAt)}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () => widget.onCopy(
                              index == 0
                                  ? 'Palavra-passe atual'
                                  : 'Palavra-passe anterior',
                              item.password,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
