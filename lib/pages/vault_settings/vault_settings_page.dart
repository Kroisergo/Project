import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/vault_entry.dart';
import '../../services/security/password_health_service.dart';
import '../../services/security/trash_pin_service.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/storage/vault_file_service.dart';
import '../../services/theme/theme_mode_controller.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/trash_retention_policy.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/constants.dart';
import '../../utils/router_paths.dart';
import '../unlock/unlock_page.dart';

typedef _SettingsCategoryBuilder =
    List<Widget> Function(BuildContext context, VoidCallback refresh);

class VaultSettingsPage extends ConsumerStatefulWidget {
  static const subPath = 'settings';
  static const routeName = 'vault-settings';

  const VaultSettingsPage({super.key});

  @override
  ConsumerState<VaultSettingsPage> createState() => _VaultSettingsPageState();
}

class _VaultSettingsPageState extends ConsumerState<VaultSettingsPage>
    with WidgetsBindingObserver {
  final _vaultFileService = VaultFileService();
  final _prefs = PreferencesService();
  bool _busy = false;
  final _exportController = TextEditingController();
  final _importController = TextEditingController();
  String _vaultFileName = VaultConstants.defaultVaultName;
  int _autoLockMinutes = 2;
  ThemeMode _themeMode = ThemeMode.system;
  TrashRetentionOption _trashRetention = TrashRetentionPolicy.defaultOption;
  Map<TrashPinAction, bool> _trashPinEnabled = const {};
  late final AutoLockController _autoLock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoLock = AutoLockController(ref: ref, onTimeout: _onLocked);
    _autoLock.restart();
    _initPaths();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoLock.cancel();
    _exportController.dispose();
    _importController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _autoLock.handleLifecycle(state);
  }

  Future<void> _initPaths() async {
    final docs = await getApplicationDocumentsDirectory();
    final defaultExport = p.join(
      docs.path,
      'vault_export${VaultConstants.vaultExtension}',
    );
    final minutes = await _prefs.getAutoLockMinutes();
    final savedThemeMode = await _prefs.getThemeMode();
    final trashRetention = await _prefs.getTrashRetentionOption();
    final trashPinService = ref.read(trashPinServiceProvider);
    final trashPinEnabled = <TrashPinAction, bool>{};
    for (final action in TrashPinAction.values) {
      trashPinEnabled[action] = await trashPinService.isEnabled(action);
    }
    final savedName = await _prefs.getVaultFileName();
    final normalized = _vaultFileService.normalizeVaultName(savedName);
    if (!mounted) return;
    _vaultFileName = normalized;
    _exportController.text = defaultExport;
    _importController.text = defaultExport;
    setState(() {
      _autoLockMinutes = minutes;
      _themeMode = savedThemeMode;
      _trashRetention = trashRetention;
      _trashPinEnabled = trashPinEnabled;
    });
  }

  void _onLocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sessão bloqueada.')));
    context.go(UnlockPage.routePath);
  }

  Future<void> _exportVault({VoidCallback? onStateChanged}) async {
    await _autoLock.restart();
    if (!mounted) return;
    setState(() => _busy = true);
    onStateChanged?.call();
    try {
      final exportPath = _exportController.text.trim();
      if (exportPath.isEmpty) throw Exception('Indica o caminho de destino.');
      await _vaultFileService.exportVaultTo(
        exportPath,
        fileName: _vaultFileName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exportado para: $exportPath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        onStateChanged?.call();
      }
    }
  }

  Future<void> _importVault({VoidCallback? onStateChanged}) async {
    await _autoLock.restart();
    if (!mounted) return;
    setState(() => _busy = true);
    onStateChanged?.call();
    try {
      final importPath = _importController.text.trim();
      if (importPath.isEmpty) {
        throw Exception('Indica o caminho do ficheiro a importar.');
      }
      await _vaultFileService.importVaultFrom(
        importPath,
        targetFileName: _vaultFileName,
      );
      await _prefs.setVaultFileName(_vaultFileName);
      ref.read(vaultProvider.notifier).clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Importação concluída.')));
      context.go(UnlockPage.routePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao importar: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        onStateChanged?.call();
      }
    }
  }

  Future<void> _updateAutoLock(
    int minutes, {
    VoidCallback? onStateChanged,
  }) async {
    setState(() {
      _autoLockMinutes = minutes;
    });
    onStateChanged?.call();
    await _prefs.setAutoLockMinutes(minutes);
    await _autoLock.refreshTimeout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          minutes == PreferencesService.autoLockNever
              ? 'Auto-lock desativado.'
              : 'Auto-lock ajustado para $minutes minutos',
        ),
      ),
    );
  }

  Future<void> _updateThemeMode(
    ThemeMode mode, {
    VoidCallback? onStateChanged,
  }) async {
    setState(() {
      _themeMode = mode;
    });
    onStateChanged?.call();
    await ref.read(themeModeControllerProvider.notifier).setMode(mode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tema ajustado para ${_themeModeLabel(mode)}')),
    );
  }

  Future<void> _updateTrashRetention(
    TrashRetentionOption option, {
    VoidCallback? onStateChanged,
  }) async {
    setState(() {
      _trashRetention = option;
    });
    onStateChanged?.call();
    await _prefs.setTrashRetentionOption(option);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Retenção do Lixo ajustada para ${option.label}.'),
      ),
    );
  }

  Future<void> _updateTrashPin(
    TrashPinAction action,
    bool enabled, {
    VoidCallback? onStateChanged,
  }) async {
    await _autoLock.restart();
    if (!mounted) return;
    final service = ref.read(trashPinServiceProvider);

    if (enabled) {
      final pin = await showDialog<String>(
        context: context,
        builder: (context) => _TrashPinSetupDialog(action: action),
      );
      if (pin == null || pin.isEmpty) return;
      await service.setPin(action, pin);
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _TrashPinPromptDialog(
          title: 'Desativar ${action.settingsTitle.toLowerCase()}',
          verifier: (pin) => service.verify(action, pin),
        ),
      );
      if (confirmed != true) return;
      await service.disable(action);
    }

    if (!mounted) return;
    setState(() {
      _trashPinEnabled = {..._trashPinEnabled, action: enabled};
    });
    onStateChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? '${action.settingsTitle} ativado.'
              : '${action.settingsTitle} desativado.',
        ),
      ),
    );
  }

  Future<void> _changeTrashPin(
    TrashPinAction action, {
    VoidCallback? onStateChanged,
  }) async {
    await _autoLock.restart();
    if (!mounted) return;

    final service = ref.read(trashPinServiceProvider);
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _TrashPinChangeDialog(action: action, service: service),
    );
    if (changed != true) return;
    if (!mounted) return;

    onStateChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${action.settingsTitle} alterado.')),
    );
  }

  Future<void> _openCategory({
    required String title,
    required _SettingsCategoryBuilder builder,
  }) async {
    await _autoLock.restart();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            _SettingsCategoryPage(title: title, builder: builder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar Cofre')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _autoLock.restart(),
        onPanDown: (_) => _autoLock.restart(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsCategoryTile(
              title: 'Dados / Backup',
              subtitle: 'Exportar e importar cofre',
              icon: Icons.folder_outlined,
              onTap: () => _openCategory(
                title: 'Dados / Backup',
                builder: (context, refresh) => [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextFormField(
                      controller: _exportController,
                      decoration: const InputDecoration(
                        labelText: 'Destino exportação (.vltx)',
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('Exportar cofre'),
                    subtitle: const Text('Guarda uma cópia cifrada (.vltx)'),
                    onTap: _busy
                        ? null
                        : () async {
                            await _exportVault(onStateChanged: refresh);
                          },
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextFormField(
                      controller: _importController,
                      decoration: const InputDecoration(
                        labelText: 'Origem importação (.vltx)',
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.upload_outlined),
                    title: const Text('Importar cofre'),
                    subtitle: const Text(
                      'Substitui o cofre atual pelo ficheiro selecionado',
                    ),
                    onTap: _busy
                        ? null
                        : () async {
                            await _importVault(onStateChanged: refresh);
                          },
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCategoryTile(
              title: 'Saude',
              subtitle: 'Resumo de palavras-passe e alertas',
              icon: Icons.health_and_safety_outlined,
              onTap: () => _openCategory(
                title: 'Saude',
                builder: (context, refresh) => const [
                  _PasswordHealthDashboard(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCategoryTile(
              title: 'Lixo',
              subtitle: 'Gerir entradas eliminadas',
              icon: Icons.delete_outline,
              onTap: () => _openCategory(
                title: 'Lixo',
                builder: (context, refresh) => [
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Lixo'),
                    subtitle: const Text('Ver entradas eliminadas'),
                    onTap: _busy
                        ? null
                        : () {
                            _autoLock.restart();
                            context.push(RouterPaths.vaultTrash);
                          },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Retenção'),
                    subtitle: const Text(
                      'Define quando o Lixo elimina entradas automaticamente',
                    ),
                    trailing: DropdownButton<TrashRetentionOption>(
                      value: _trashRetention,
                      items: TrashRetentionOption.values
                          .map(
                            (option) => DropdownMenuItem(
                              value: option,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (option) async {
                              await _updateTrashRetention(
                                option ?? TrashRetentionPolicy.defaultOption,
                                onStateChanged: refresh,
                              );
                            },
                    ),
                  ),
                  const Divider(height: 1),
                  for (final action in TrashPinAction.values) ...[
                    SwitchListTile(
                      secondary: const Icon(Icons.pin_outlined),
                      title: Text(action.settingsTitle),
                      subtitle: const Text('Opcional. Por defeito, sem PIN.'),
                      value: _trashPinEnabled[action] ?? false,
                      onChanged: _busy
                          ? null
                          : (enabled) async {
                              await _updateTrashPin(
                                action,
                                enabled,
                                onStateChanged: refresh,
                              );
                            },
                    ),
                    if (_trashPinEnabled[action] ?? false)
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Alterar PIN'),
                        subtitle: Text(
                          'Atualiza o ${action.settingsTitle.toLowerCase()}',
                        ),
                        onTap: _busy
                            ? null
                            : () async {
                                await _changeTrashPin(
                                  action,
                                  onStateChanged: refresh,
                                );
                              },
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCategoryTile(
              title: 'Sessão',
              subtitle: 'Auto-lock e sessão',
              icon: Icons.lock_clock_outlined,
              onTap: () => _openCategory(
                title: 'Sessão',
                builder: (context, refresh) => [
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('Auto-lock'),
                    subtitle: const Text('Tempo de inatividade até bloquear'),
                    trailing: DropdownButton<int>(
                      value: _autoLockMinutes,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Nunca')),
                        DropdownMenuItem(value: 1, child: Text('1 min')),
                        DropdownMenuItem(value: 2, child: Text('2 min')),
                        DropdownMenuItem(value: 5, child: Text('5 min')),
                        DropdownMenuItem(value: 10, child: Text('10 min')),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) async {
                              await _updateAutoLock(
                                value ?? 2,
                                onStateChanged: refresh,
                              );
                            },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCategoryTile(
              title: 'Aparência',
              subtitle: 'Tema e aparência',
              icon: Icons.palette_outlined,
              onTap: () => _openCategory(
                title: 'Aparência',
                builder: (context, refresh) => [
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Tema'),
                    subtitle: const Text('Modo de aparência da aplicação'),
                    trailing: DropdownButton<ThemeMode>(
                      value: _themeMode,
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('Sistema'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Claro'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Escuro'),
                        ),
                      ],
                      onChanged: _busy
                          ? null
                          : (mode) async {
                              await _updateThemeMode(
                                mode ?? ThemeMode.system,
                                onStateChanged: refresh,
                              );
                            },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Sistema';
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Escuro';
    }
  }
}

class _SettingsCategoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsCategoryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title, style: Theme.of(context).textTheme.titleSmall),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _SettingsCategoryPage extends StatefulWidget {
  final String title;
  final _SettingsCategoryBuilder builder;

  const _SettingsCategoryPage({required this.title, required this.builder});

  @override
  State<_SettingsCategoryPage> createState() => _SettingsCategoryPageState();
}

class _SettingsCategoryPageState extends State<_SettingsCategoryPage> {
  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: widget.builder(context, _refresh)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrashPinSetupDialog extends StatefulWidget {
  final TrashPinAction action;

  const _TrashPinSetupDialog({required this.action});

  @override
  State<_TrashPinSetupDialog> createState() => _TrashPinSetupDialogState();
}

class _TrashPinSetupDialogState extends State<_TrashPinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.clear();
    _confirmController.clear();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (!RegExp(r'^\d{4,12}$').hasMatch(pin)) {
      setState(() => _error = 'Usa um PIN com 4 a 12 dígitos.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'Os PINs não coincidem.');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.action.settingsTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TrashPinWarning(),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Confirmar PIN'),
            onSubmitted: (_) => _submit(),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}

class _TrashPinChangeDialog extends StatefulWidget {
  final TrashPinAction action;
  final TrashPinService service;

  const _TrashPinChangeDialog({required this.action, required this.service});

  @override
  State<_TrashPinChangeDialog> createState() => _TrashPinChangeDialogState();
}

class _TrashPinChangeDialogState extends State<_TrashPinChangeDialog> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  String? _oldPinError;
  String? _newPinError;
  String? _confirmPinError;
  bool _submitting = false;

  @override
  void dispose() {
    _oldPinController.clear();
    _newPinController.clear();
    _confirmPinController.clear();
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final oldPin = _oldPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    setState(() {
      _oldPinError = null;
      _newPinError = null;
      _confirmPinError = null;
    });

    if (oldPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
      setState(() {
        if (oldPin.isEmpty) _oldPinError = 'Preenche o PIN antigo.';
        if (newPin.isEmpty) _newPinError = 'Preenche o PIN novo.';
        if (confirmPin.isEmpty) _confirmPinError = 'Confirma o PIN novo.';
      });
      return;
    }
    if (!RegExp(r'^\d{4,12}$').hasMatch(newPin)) {
      setState(() => _newPinError = 'Usa um PIN novo com 4 a 12 dígitos.');
      return;
    }
    if (newPin != confirmPin) {
      setState(
        () => _confirmPinError = 'O PIN novo e a confirmação não coincidem.',
      );
      return;
    }

    setState(() => _submitting = true);
    final changed = await widget.service.changePin(
      widget.action,
      oldPin: oldPin,
      newPin: newPin,
    );
    if (!mounted) return;

    if (!changed) {
      setState(() {
        _oldPinError = 'PIN antigo incorreto';
        _submitting = false;
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Alterar ${widget.action.settingsTitle.toLowerCase()}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TrashPinWarning(),
          const SizedBox(height: 12),
          TextField(
            controller: _oldPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'PIN antigo',
              errorText: _oldPinError,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'PIN novo',
              errorText: _newPinError,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Confirmar PIN novo',
              errorText: _confirmPinError,
            ),
            onSubmitted: (_) async => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
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
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _TrashPinWarning extends StatelessWidget {
  const _TrashPinWarning();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, color: colors.error),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Guarda este PIN em segurança. Se o perderes, poderá não ser possível recuperá-lo. O PIN é definido por ti e és responsável por o guardar em segurança.',
            ),
          ),
        ],
      ),
    );
  }
}

class _TrashPinPromptDialog extends StatefulWidget {
  final String title;
  final Future<bool> Function(String pin) verifier;

  const _TrashPinPromptDialog({required this.title, required this.verifier});

  @override
  State<_TrashPinPromptDialog> createState() => _TrashPinPromptDialogState();
}

class _TrashPinPromptDialogState extends State<_TrashPinPromptDialog> {
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
    final pin = _controller.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'Introduz o PIN.');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final isValid = await widget.verifier(pin);
    if (!mounted) return;

    if (!isValid) {
      setState(() {
        _error = 'PIN incorreto.';
        _submitting = false;
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'PIN', errorText: _error),
        onSubmitted: (_) async => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
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

class _PasswordHealthDashboard extends ConsumerWidget {
  const _PasswordHealthDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(vaultProvider).data?.activeEntries ?? [];
    final report = PasswordHealthService.analyze(entries);
    final weakEntries = entries
        .where(PasswordHealthService.isWeakEntry)
        .toList();
    final reusedEntries = entries
        .where((entry) => PasswordHealthService.isReusedEntry(entries, entry))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(report.summary),
        ),
        const Divider(height: 1),
        _HealthStatTile(label: 'Total de entradas', value: report.total),
        _HealthStatTile(
          label: 'Palavras-passe fracas',
          value: report.weak,
          onTap: weakEntries.isEmpty
              ? null
              : () => _openHealthDetails(
                  context,
                  title: 'Palavras-passe fracas',
                  entries: weakEntries,
                  allEntries: entries,
                ),
        ),
        _HealthStatTile(
          label: 'Palavras-passe reutilizadas',
          value: report.reused,
          onTap: reusedEntries.isEmpty
              ? null
              : () => _openHealthDetails(
                  context,
                  title: 'Palavras-passe reutilizadas',
                  entries: reusedEntries,
                  allEntries: entries,
                ),
        ),
        _HealthStatTile(
          label: 'Grupos com palavra-passe repetida',
          value: report.reusedGroups,
        ),
        _HealthStatTile(label: 'A mudar pela recomendacao', value: report.old),
        _HealthStatTile(label: 'Sem palavra-passe', value: report.empty),
        _HealthStatTile(
          label: 'Sem categoria/tag',
          value: report.uncategorized,
        ),
      ],
    );
  }

  void _openHealthDetails(
    BuildContext context, {
    required String title,
    required List<VaultEntry> entries,
    required List<VaultEntry> allEntries,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _PasswordHealthDetailsPage(
          title: title,
          entries: entries,
          allEntries: allEntries,
        ),
      ),
    );
  }
}

class _HealthStatTile extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;

  const _HealthStatTile({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (onTap != null) const SizedBox(width: 4),
          if (onTap != null) const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _PasswordHealthDetailsPage extends StatelessWidget {
  final String title;
  final List<VaultEntry> entries;
  final List<VaultEntry> allEntries;

  const _PasswordHealthDetailsPage({
    required this.title,
    required this.entries,
    required this.allEntries,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final alerts = PasswordHealthService.alertsForEntry(
            entries: allEntries,
            entry: entry,
          );
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.warning_amber_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(entry.title),
            subtitle: Text(
              [
                if (entry.username.isNotEmpty) entry.username,
                ...alerts,
              ].join('\n'),
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RouterPaths.vaultEntryView(entry.id)),
          );
        },
      ),
    );
  }
}
