import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../config/theme/design_tokens.dart';
import '../../models/app_design_mode.dart';
import '../../models/quick_link_preset.dart';
import '../../models/vault_entry.dart';
import '../../services/security/ignored_alerts_controller.dart';
import '../../services/security/master_password_policy.dart';
import '../../services/security/password_health_service.dart';
import '../../services/security/screen_protection_controller.dart';
import '../../services/security/trash_pin_service.dart';
import '../../services/storage/preferences_service.dart';
import '../../services/storage/vault_file_service.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/trash_retention_policy.dart';
import '../../services/vault/vault_repository.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/constants.dart';
import '../../utils/router_paths.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/password_policy_status.dart';
import '../../widgets/quick_link_icon.dart';
import '../../widgets/quick_link_preset_dialog.dart';
import '../../widgets/sensitive_action_confirmation.dart';
import '../../widgets/vault_category_icon.dart';
import '../terms/terms_page.dart';
import '../unlock/unlock_page.dart';
import 'widgets/appearance_settings_section.dart';
import 'widgets/ignored_alerts_section.dart';
import 'widgets/tag_display_settings_section.dart';

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
  final _exportController = TextEditingController();
  final _importController = TextEditingController();
  final _backupController = TextEditingController();

  bool _busy = false;
  String _vaultFileName = VaultConstants.defaultVaultName;
  int _autoLockMinutes = 2;
  TrashRetentionOption _trashRetention = TrashRetentionPolicy.defaultOption;
  TrashRetentionOption _documentTrashRetention =
      TrashRetentionPolicy.defaultOption;
  bool _requireSensitiveActionConfirmation = false;
  bool _savePasswordHistory = true;
  bool _protectScreenshots = true;
  bool _visualProtection = true;
  bool _protectScreenRecording = true;
  Map<TrashPinAction, bool> _trashPinEnabled = const {};
  List<QuickLinkPreset> _customQuickLinks = const [];
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
    _backupController.dispose();
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
    final trashRetention = await _prefs.getTrashRetentionOption();
    final documentTrashRetention = await _prefs
        .getDocumentTrashRetentionOption();
    final requireSensitiveActionConfirmation = await _prefs
        .getRequireSensitiveActionConfirmation();
    final savePasswordHistory = await _prefs.getSavePasswordHistory();
    final protectScreenshots = await _prefs.getProtectScreenshots();
    final visualProtection = await _prefs.getVisualProtection();
    final protectScreenRecording = await _prefs.getProtectScreenRecording();
    final customQuickLinks = await _prefs.getCustomQuickLinks();
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
    _backupController.text = defaultExport;
    setState(() {
      _autoLockMinutes = minutes;
      _trashRetention = trashRetention;
      _documentTrashRetention = documentTrashRetention;
      _requireSensitiveActionConfirmation = requireSensitiveActionConfirmation;
      _savePasswordHistory = savePasswordHistory;
      _protectScreenshots = protectScreenshots;
      _visualProtection = visualProtection;
      _protectScreenRecording = protectScreenRecording;
      _trashPinEnabled = trashPinEnabled;
      _customQuickLinks = customQuickLinks;
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
    try {
      final exportPath = _exportController.text.trim();
      if (exportPath.isEmpty) throw Exception('Indica o caminho de destino.');
      final allowed = await confirmSensitiveAction(
        context: context,
        ref: ref,
        title: 'Confirmar exportação',
        message:
            'Introduz a palavra-passe mestra para exportar uma cópia cifrada do cofre.',
      );
      if (!allowed || !mounted) return;
      setState(() => _busy = true);
      onStateChanged?.call();
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

  Future<void> _exportEmergencyVault({VoidCallback? onStateChanged}) async {
    await _autoLock.restart();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _EmergencyExportDialog(),
    );
    if (confirmed != true) return;
    await _exportVault(onStateChanged: onStateChanged);
  }

  Future<void> _importVault({VoidCallback? onStateChanged}) async {
    await _autoLock.restart();
    if (!mounted) return;
    try {
      final importPath = _importController.text.trim();
      if (importPath.isEmpty) {
        throw Exception('Indica o caminho do ficheiro a importar.');
      }
      final allowed = await confirmSensitiveAction(
        context: context,
        ref: ref,
        title: 'Confirmar importação',
        message:
            'Introduz a palavra-passe mestra para substituir o cofre atual pelo ficheiro selecionado.',
      );
      if (!allowed || !mounted) return;
      setState(() => _busy = true);
      onStateChanged?.call();
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

  Future<void> _verifyBackup({VoidCallback? onStateChanged}) async {
    await _autoLock.restart();
    if (!mounted) return;
    setState(() => _busy = true);
    onStateChanged?.call();
    try {
      final result = await _vaultFileService.validateVaultFileStructure(
        _backupController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        onStateChanged?.call();
      }
    }
  }

  Future<void> _changeMasterPassword({VoidCallback? onStateChanged}) async {
    await _autoLock.restart();
    if (!mounted) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ChangeMasterPasswordDialog(),
    );
    if (changed != true) return;
    onStateChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Palavra-passe mestra alterada com sucesso.'),
      ),
    );
  }

  Future<void> _updateAutoLock(
    int minutes, {
    VoidCallback? onStateChanged,
  }) async {
    setState(() => _autoLockMinutes = minutes);
    onStateChanged?.call();
    await _prefs.setAutoLockMinutes(minutes);
    await _autoLock.refreshTimeout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          minutes == PreferencesService.autoLockNever
              ? 'Bloqueio automático desativado.'
              : 'Bloqueio automático ajustado para $minutes minutos.',
        ),
      ),
    );
  }

  Future<void> _updateTrashRetention(
    TrashRetentionOption option, {
    VoidCallback? onStateChanged,
  }) async {
    setState(() => _trashRetention = option);
    onStateChanged?.call();
    await _prefs.setTrashRetentionOption(option);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Retenção do Lixo ajustada para ${option.label}.'),
      ),
    );
  }

  Future<void> _updateDocumentTrashRetention(
    TrashRetentionOption option, {
    VoidCallback? onStateChanged,
  }) async {
    setState(() => _documentTrashRetention = option);
    onStateChanged?.call();
    await _prefs.setDocumentTrashRetentionOption(option);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Retenção do Lixo de Documentos ajustada para ${option.label}.',
        ),
      ),
    );
  }

  Future<void> _updateRequireSensitiveActionConfirmation(
    bool value, {
    VoidCallback? onStateChanged,
  }) async {
    setState(() => _requireSensitiveActionConfirmation = value);
    onStateChanged?.call();
    await _prefs.setRequireSensitiveActionConfirmation(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Confirmação adicional ativada.'
              : 'Confirmação adicional desativada.',
        ),
      ),
    );
  }

  Future<void> _updateSavePasswordHistory(
    bool value, {
    VoidCallback? onStateChanged,
  }) async {
    setState(() => _savePasswordHistory = value);
    onStateChanged?.call();
    await _prefs.setSavePasswordHistory(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Histórico de palavras-passe ativado.'
              : 'Histórico de palavras-passe desativado.',
        ),
      ),
    );
  }

  Future<bool> _confirmDisableProtection({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Manter ativa'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _updateProtectScreenshots(
    bool value, {
    VoidCallback? onStateChanged,
  }) async {
    await _autoLock.restart();
    if (!mounted) return;
    if (!value) {
      final confirmed = await _confirmDisableProtection(
        title: 'Desativar proteção contra capturas?',
        message:
            'Sem esta proteção, o sistema pode permitir capturas do ecrã com dados sensíveis visíveis.',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _protectScreenshots = value);
    onStateChanged?.call();
    await _prefs.setProtectScreenshots(value);
    await ref.read(screenProtectionControllerProvider).syncProtectionSettings();
  }

  Future<void> _updateVisualProtection(
    bool value, {
    VoidCallback? onStateChanged,
  }) async {
    await _autoLock.restart();
    if (!mounted) return;
    if (!value) {
      final confirmed = await _confirmDisableProtection(
        title: 'Desativar proteção visual?',
        message:
            'Sem esta proteção, a aplicação não cobre o conteúdo quando passa para segundo plano.',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _visualProtection = value);
    onStateChanged?.call();
    await _prefs.setVisualProtection(value);
  }

  Future<void> _updateProtectScreenRecording(
    bool value, {
    VoidCallback? onStateChanged,
  }) async {
    await _autoLock.restart();
    if (!mounted) return;
    if (!value) {
      final confirmed = await _confirmDisableProtection(
        title: 'Desativar proteção contra gravação?',
        message:
            'Sem esta proteção, o sistema pode permitir gravação de ecrã com dados sensíveis visíveis.',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _protectScreenRecording = value);
    onStateChanged?.call();
    await _prefs.setProtectScreenRecording(value);
    await ref.read(screenProtectionControllerProvider).syncProtectionSettings();
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
      if (!mounted) return;
      final allowed = await confirmSensitiveAction(
        context: context,
        ref: ref,
        title: 'Confirmar desativação do PIN',
        message:
            'Introduz a palavra-passe mestra para desativar esta proteção do Lixo.',
      );
      if (!allowed) return;
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

  Future<void> _editQuickLink({
    QuickLinkPreset? existing,
    VoidCallback? onStateChanged,
  }) async {
    await _autoLock.restart();
    if (!mounted) return;
    final result = await showDialog<QuickLinkPresetDialogResult>(
      context: context,
      builder: (context) => QuickLinkPresetDialog(
        initialPreset: existing,
        title: existing == null
            ? 'Adicionar link rápido'
            : 'Editar link rápido',
        actionLabel: existing == null ? 'Adicionar' : 'Guardar',
      ),
    );
    if (result == null || !mounted) return;
    final existingUrl = existing?.normalizedUrl.toLowerCase();
    final newUrl = result.preset.normalizedUrl.toLowerCase();
    final nextLinks = [
      ..._customQuickLinks.where((link) {
        final linkUrl = link.normalizedUrl.toLowerCase();
        return linkUrl != existingUrl && linkUrl != newUrl;
      }),
      result.preset,
    ];
    await _prefs.setCustomQuickLinks(nextLinks);
    if (!mounted) return;
    setState(() => _customQuickLinks = nextLinks);
    onStateChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? 'Link rápido adicionado.'
              : 'Link rápido atualizado.',
        ),
      ),
    );
  }

  Future<void> _deleteQuickLink(
    QuickLinkPreset link, {
    VoidCallback? onStateChanged,
  }) async {
    await _autoLock.restart();
    final targetUrl = link.normalizedUrl.toLowerCase();
    final nextLinks = _customQuickLinks
        .where((current) => current.normalizedUrl.toLowerCase() != targetUrl)
        .toList();
    await _prefs.setCustomQuickLinks(nextLinks);
    if (!mounted) return;
    setState(() => _customQuickLinks = nextLinks);
    onStateChanged?.call();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link rápido removido.')));
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
    final tokens = EncryVaultTheme.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: const Text('Configurar cofre')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _autoLock.restart(),
        onPanDown: (_) => _autoLock.restart(),
        child: ListView(
          padding: EdgeInsets.all(tokens.pagePadding),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configurações do cofre',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gere segurança, aparência e dados locais num só lugar.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
            _SettingsCategoryTile(
              title: 'Segurança',
              subtitle: 'Palavra-passe mestra e proteções sensíveis',
              icon: Icons.security_outlined,
              onTap: () => _openCategory(
                title: 'Segurança',
                builder: (context, refresh) => [
                  ListTile(
                    leading: const Icon(Icons.password_outlined),
                    title: const Text('Alterar palavra-passe mestra'),
                    subtitle: const Text(
                      'Re-cifra o cofre com nova palavra-passe',
                    ),
                    onTap: _busy
                        ? null
                        : () async {
                            await _changeMasterPassword(
                              onStateChanged: refresh,
                            );
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.verified_user_outlined),
                    title: const Text('Pedir confirmação para ações sensíveis'),
                    subtitle: const Text(
                      'Quando ativo, exportar, importar, eliminar definitivamente ou alterar proteções exige confirmação adicional.',
                    ),
                    value: _requireSensitiveActionConfirmation,
                    onChanged: _busy
                        ? null
                        : (value) async {
                            await _updateRequireSensitiveActionConfirmation(
                              value,
                              onStateChanged: refresh,
                            );
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.history_outlined),
                    title: const Text('Guardar histórico de palavras-passe'),
                    subtitle: const Text(
                      'Quando ativo, as palavras-passe antigas ficam guardadas cifradas dentro do cofre.',
                    ),
                    value: _savePasswordHistory,
                    onChanged: _busy
                        ? null
                        : (value) async {
                            await _updateSavePasswordHistory(
                              value,
                              onStateChanged: refresh,
                            );
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.screenshot_monitor_outlined),
                    title: const Text('Proteção contra capturas de ecrã'),
                    subtitle: const Text(
                      'Bloqueia capturas de ecrã quando suportado pelo sistema.',
                    ),
                    value: _protectScreenshots,
                    onChanged: _busy
                        ? null
                        : (value) async {
                            await _updateProtectScreenshots(
                              value,
                              onStateChanged: refresh,
                            );
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.visibility_off_outlined),
                    title: const Text('Proteção visual'),
                    subtitle: const Text(
                      'Cobre a aplicação quando passa para segundo plano.',
                    ),
                    value: _visualProtection,
                    onChanged: _busy
                        ? null
                        : (value) async {
                            await _updateVisualProtection(
                              value,
                              onStateChanged: refresh,
                            );
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.videocam_off_outlined),
                    title: const Text('Proteção contra gravação de ecrã'),
                    subtitle: const Text(
                      'Bloqueia a gravação do ecrã quando suportado pelo sistema.',
                    ),
                    value: _protectScreenRecording,
                    onChanged: _busy
                        ? null
                        : (value) async {
                            await _updateProtectScreenRecording(
                              value,
                              onStateChanged: refresh,
                            );
                          },
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
              title: 'Cofre',
              subtitle: 'Informação do cofre local',
              icon: Icons.inventory_2_outlined,
              onTap: () => _openCategory(
                title: 'Cofre',
                builder: (context, refresh) => [
                  ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: const Text('Ficheiro ativo'),
                    subtitle: Text(_vaultFileName),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCategoryTile(
              title: 'Lixo',
              subtitle: 'Entradas, documentos e retenção',
              icon: Icons.delete_outline,
              onTap: () => _openCategory(
                title: 'Lixo',
                builder: (context, refresh) => [
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Lixo de Entradas'),
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
                    leading: const Icon(Icons.folder_delete_outlined),
                    title: const Text('Lixo de Documentos'),
                    subtitle: const Text('Ver documentos eliminados'),
                    onTap: _busy
                        ? null
                        : () {
                            _autoLock.restart();
                            context.push(RouterPaths.vaultDocumentTrash);
                          },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Retenção de entradas'),
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
                  ListTile(
                    leading: const Icon(Icons.event_busy_outlined),
                    title: const Text('Retenção de documentos'),
                    subtitle: const Text(
                      'Define quando o Lixo elimina documentos automaticamente',
                    ),
                    trailing: DropdownButton<TrashRetentionOption>(
                      value: _documentTrashRetention,
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
                              await _updateDocumentTrashRetention(
                                option ?? TrashRetentionPolicy.defaultOption,
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
              title: 'Dados',
              subtitle: 'Exportar, importar e verificar cópias de segurança',
              icon: Icons.folder_outlined,
              onTap: () => _openCategory(
                title: 'Dados',
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
                  ListTile(
                    leading: const Icon(Icons.warning_amber_outlined),
                    title: const Text('Exportação de emergência'),
                    subtitle: const Text(
                      'Exportação cifrada com aviso reforçado',
                    ),
                    onTap: _busy
                        ? null
                        : () async {
                            await _exportEmergencyVault(
                              onStateChanged: refresh,
                            );
                          },
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextFormField(
                      controller: _backupController,
                      decoration: const InputDecoration(
                        labelText: 'Cópia de segurança a verificar (.vltx)',
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.verified_outlined),
                    title: const Text('Verificar cópia de segurança'),
                    subtitle: const Text('Valida a estrutura sem importar'),
                    onTap: _busy
                        ? null
                        : () async {
                            await _verifyBackup(onStateChanged: refresh);
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
              title: 'Links rápidos',
              subtitle: 'Links e ícones disponíveis ao criar entradas',
              icon: Icons.add_link_outlined,
              onTap: () => _openCategory(
                title: 'Links rápidos',
                builder: (context, refresh) => [
                  _QuickLinksSettingsSection(
                    customLinks: _customQuickLinks,
                    onAdd: () => _editQuickLink(onStateChanged: refresh),
                    onEdit: (link) =>
                        _editQuickLink(existing: link, onStateChanged: refresh),
                    onDelete: (link) =>
                        _deleteQuickLink(link, onStateChanged: refresh),
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
                  AppearanceSettingsSection(
                    enabled: !_busy,
                    onStateChanged: refresh,
                  ),
                  const Divider(height: 1),
                  const TagDisplaySettingsSection(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCategoryTile(
              title: 'Sessão',
              subtitle: 'Bloqueio automático e sessão',
              icon: Icons.lock_clock_outlined,
              onTap: () => _openCategory(
                title: 'Sessão',
                builder: (context, refresh) => [
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('Bloqueio automático'),
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
              title: 'Auditoria / Saúde',
              subtitle: 'Resumo de palavras-passe e alertas',
              icon: Icons.health_and_safety_outlined,
              onTap: () => _openCategory(
                title: 'Auditoria / Saúde',
                builder: (context, refresh) => [
                  _PasswordHealthDashboard(trashRetention: _trashRetention),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCategoryTile(
              title: 'Termos de utilização',
              subtitle: 'Rever os termos aceites',
              icon: Icons.description_outlined,
              onTap: () => _openCategory(
                title: 'Termos de utilização',
                builder: (context, refresh) => const [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: TermsContent(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCategoryTile(
              title: 'Sobre EncryVault',
              subtitle: 'Marca, identidade e direitos',
              icon: Icons.info_outline,
              onTap: () => _openCategory(
                title: 'Sobre EncryVault',
                builder: (context, refresh) => const [
                  _AboutEncryVaultSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    final tokens = EncryVaultTheme.of(context);
    final isClassic = tokens.designMode == AppDesignMode.classic;
    return AppSurface(
      padding: EdgeInsets.zero,
      elevated: !isClassic,
      minHeight: isClassic ? 70 : 88,
      radius: isClassic ? 10 : tokens.cardRadius,
      leadingAccentColor: isClassic ? tokens.accentMuted : null,
      leadingAccentWidth: isClassic ? 3 : 0,
      child: ListTile(
        minTileHeight: isClassic ? 70 : 82,
        contentPadding: EdgeInsets.only(left: isClassic ? 20 : 16, right: 10),
        leading: isClassic ? null : Icon(icon, color: tokens.accent),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontSize: isClassic ? 14.5 : 15),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
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
    final tokens = EncryVaultTheme.of(context);
    final categoryChildren = widget.builder(context, _refresh);
    final isModernHealth =
        tokens.designMode == AppDesignMode.modern &&
        widget.title == 'Auditoria / Saúde';
    final isModernQuickLinks =
        widget.title == 'Links rápidos' &&
        usesModernQuickLinksSettingsCards(tokens.designMode);
    final useModernCards =
        tokens.designMode == AppDesignMode.modern &&
        usesModernSettingsCategoryCards(widget.title);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: EdgeInsets.all(tokens.pagePadding),
        children: isModernHealth || isModernQuickLinks
            ? categoryChildren
            : useModernCards
            ? _modernSettingsCategoryCards(categoryChildren, tokens)
            : [
                AppSurface(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: categoryChildren),
                ),
              ],
      ),
    );
  }

  List<Widget> _modernSettingsCategoryCards(
    List<Widget> children,
    EncryVaultTheme tokens,
  ) {
    final cards = <Widget>[];
    var group = <Widget>[];

    void flushGroup() {
      if (group.isEmpty) return;
      cards.add(
        AppSurface(
          elevated: true,
          padding: EdgeInsets.zero,
          radius: tokens.cardRadius,
          child: Column(mainAxisSize: MainAxisSize.min, children: group),
        ),
      );
      cards.add(const SizedBox(height: 12));
      group = <Widget>[];
    }

    for (final child in children) {
      if (child is Divider) {
        flushGroup();
      } else {
        group.add(child);
      }
    }
    flushGroup();
    if (cards.isNotEmpty) {
      cards.removeLast();
    }
    return cards;
  }
}

class _AboutEncryVaultSection extends StatelessWidget {
  const _AboutEncryVaultSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EncryVault', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'EncryVault é uma aplicação de cofre digital offline para gestão local de palavras-passe e dados sensíveis.',
          ),
          const SizedBox(height: 16),
          Text(
            'Marca e direitos',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'O nome EncryVault, a identidade visual da aplicação, os elementos de marca e a apresentação do produto pertencem aos respetivos autores do projeto. A utilização da marca deve respeitar a identidade da aplicação e não deve sugerir associação, certificação ou autorização sem permissão.',
          ),
          const SizedBox(height: 16),
          Text(
            'Responsabilidade',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'A aplicação é fornecida como ferramenta local de segurança. A proteção final dos dados depende também da palavra-passe mestra, do dispositivo, das cópias de segurança e da forma como o utilizador gere os seus ficheiros.',
          ),
        ],
      ),
    );
  }
}

class _QuickLinksSettingsSection extends StatelessWidget {
  final List<QuickLinkPreset> customLinks;
  final VoidCallback onAdd;
  final ValueChanged<QuickLinkPreset> onEdit;
  final ValueChanged<QuickLinkPreset> onDelete;

  const _QuickLinksSettingsSection({
    required this.customLinks,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    if (usesModernQuickLinksSettingsCards(tokens.designMode)) {
      return _ModernQuickLinksSettingsSection(
        customLinks: customLinks,
        onAdd: onAdd,
        onEdit: onEdit,
        onDelete: onDelete,
      );
    }
    return _ClassicQuickLinksSettingsSection(
      customLinks: customLinks,
      onAdd: onAdd,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _ModernQuickLinksSettingsSection extends StatelessWidget {
  final List<QuickLinkPreset> customLinks;
  final VoidCallback onAdd;
  final ValueChanged<QuickLinkPreset> onEdit;
  final ValueChanged<QuickLinkPreset> onDelete;

  const _ModernQuickLinksSettingsSection({
    required this.customLinks,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSurface(
          elevated: true,
          radius: tokens.cardRadius,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  QuickLinkIconBadge(icon: QuickLinkIcon.key),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Links predefinidos',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${defaultQuickLinkPresets.length} serviços disponíveis ao criar entradas.',
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final link in defaultQuickLinkPresets)
                    Chip(
                      avatar: Icon(quickLinkIconData(link.icon), size: 16),
                      label: Text(link.label),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppSurface(
          elevated: true,
          radius: tokens.cardRadius,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Links personalizados',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_link_outlined, size: 18),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (customLinks.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.surfaceRaised.withValues(
                      alpha: tokens.isDark ? 0.45 : 0.85,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Text(
                    'Ainda não adicionaste links personalizados.',
                    style: textTheme.bodyMedium,
                  ),
                )
              else
                for (final link in customLinks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tokens.surfaceRaised.withValues(
                          alpha: tokens.isDark ? 0.45 : 0.85,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tokens.border),
                      ),
                      child: ListTile(
                        leading: QuickLinkIconBadge(icon: link.icon),
                        title: Text(link.label),
                        subtitle: Text(link.url),
                        trailing: _QuickLinkMenu(
                          onEdit: () => onEdit(link),
                          onDelete: () => onDelete(link),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClassicQuickLinksSettingsSection extends StatelessWidget {
  final List<QuickLinkPreset> customLinks;
  final VoidCallback onAdd;
  final ValueChanged<QuickLinkPreset> onEdit;
  final ValueChanged<QuickLinkPreset> onDelete;

  const _ClassicQuickLinksSettingsSection({
    required this.customLinks,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Links predefinidos',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${defaultQuickLinkPresets.length} serviços aparecem automaticamente na criação de entradas.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            defaultQuickLinkPresets.map((link) => link.label).join(', '),
            style: textTheme.bodyMedium,
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Links personalizados',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_link_outlined),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (customLinks.isEmpty)
            Text(
              'Ainda não adicionaste links personalizados.',
              style: textTheme.bodyMedium,
            )
          else
            for (final link in customLinks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(quickLinkIconData(link.icon)),
                title: Text(link.label),
                subtitle: Text(link.url),
                trailing: _QuickLinkMenu(
                  onEdit: () => onEdit(link),
                  onDelete: () => onDelete(link),
                ),
              ),
        ],
      ),
    );
  }
}

class _QuickLinkMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuickLinkMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    if (usesModernQuickLinkMenu(tokens.designMode)) {
      return IconButton(
        tooltip: 'Opções',
        icon: const Icon(Icons.more_horiz_rounded),
        onPressed: () => _showModernActions(context),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Opções',
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('Editar')),
        PopupMenuItem(value: 'delete', child: Text('Remover')),
      ],
    );
  }

  Future<void> _showModernActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final tokens = EncryVaultTheme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.pagePadding,
              0,
              tokens.pagePadding,
              tokens.pagePadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Opções do link',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                AppSurface(
                  elevated: true,
                  radius: tokens.cardRadius,
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: QuickLinkIconBadge(icon: QuickLinkIcon.code),
                        title: const Text('Editar'),
                        subtitle: const Text('Alterar nome, link ou ícone'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onEdit();
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              sheetContext,
                            ).colorScheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: Theme.of(sheetContext).colorScheme.error,
                            size: 18,
                          ),
                        ),
                        title: const Text('Remover'),
                        subtitle: const Text('Apagar dos links personalizados'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onDelete();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

bool usesModernSettingsCategoryCards(String title) {
  return title == 'Segurança' ||
      title == 'Dados' ||
      title == 'Aparência' ||
      title == 'Lixo' ||
      title == 'Links rápidos' ||
      title == 'Termos de utilização' ||
      title == 'Sobre EncryVault';
}

bool usesModernQuickLinksSettingsCards(AppDesignMode designMode) {
  return designMode == AppDesignMode.modern;
}

bool usesModernQuickLinkMenu(AppDesignMode designMode) {
  return designMode == AppDesignMode.modern;
}

bool usesModernPasswordHealthDetailsCards(AppDesignMode designMode) {
  return designMode == AppDesignMode.modern;
}

class _EmergencyExportDialog extends StatefulWidget {
  const _EmergencyExportDialog();

  @override
  State<_EmergencyExportDialog> createState() => _EmergencyExportDialogState();
}

class _EmergencyExportDialogState extends State<_EmergencyExportDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exportação de emergência'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Esta exportação cria uma cópia cifrada do cofre (.vltx). Guarda o ficheiro apenas num local seguro. Sem a palavra-passe mestra correta, não será possível recuperar os dados.',
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _accepted,
            onChanged: (value) => setState(() => _accepted = value ?? false),
            title: const Text(
              'Compreendo que sou responsável por guardar o ficheiro e a palavra-passe mestra.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _accepted ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Exportar'),
        ),
      ],
    );
  }
}

class _ChangeMasterPasswordDialog extends ConsumerStatefulWidget {
  const _ChangeMasterPasswordDialog();

  @override
  ConsumerState<_ChangeMasterPasswordDialog> createState() =>
      _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState
    extends ConsumerState<_ChangeMasterPasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _currentError;
  String? _newError;
  String? _confirmError;
  String? _generalError;
  bool _submitting = false;

  MasterPasswordPolicyResult get _newPolicy =>
      MasterPasswordPolicy.evaluate(_newController.text);

  @override
  void dispose() {
    _currentController.clear();
    _newController.clear();
    _confirmController.clear();
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = _currentController.text;
    final newPassword = _newController.text;
    final confirmPassword = _confirmController.text;
    final policy = MasterPasswordPolicy.evaluate(newPassword);

    setState(() {
      _currentError = null;
      _newError = null;
      _confirmError = null;
      _generalError = null;
    });

    var hasError = false;
    if (currentPassword.isEmpty) {
      _currentError = 'Introduz a palavra-passe mestra atual.';
      hasError = true;
    }
    if (!policy.isValid) {
      _newError = 'A nova palavra-passe mestra não cumpre os requisitos.';
      hasError = true;
    }
    if (newPassword != confirmPassword) {
      _confirmError = 'A confirmação não coincide.';
      hasError = true;
    }
    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(vaultProvider.notifier)
          .changeMasterPassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      if (!mounted) return;
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      Navigator.of(context).pop(true);
    } on VaultAuthException {
      if (!mounted) return;
      setState(() {
        _currentError = 'Palavra-passe mestra atual incorreta.';
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = 'Não foi possível alterar a palavra-passe: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = _newPolicy;
    return AlertDialog(
      title: const Text('Alterar palavra-passe mestra'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MasterPasswordWarning(),
            const SizedBox(height: 12),
            TextField(
              controller: _currentController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Palavra-passe mestra atual',
                errorText: _currentError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newController,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Nova palavra-passe mestra',
                errorText: _newError,
              ),
            ),
            const SizedBox(height: 12),
            PasswordPolicyStatus(result: policy),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirmar nova palavra-passe mestra',
                errorText: _confirmError,
              ),
              onSubmitted: (_) async => _submit(),
            ),
            if (_generalError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _generalError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
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
              : const Text('Alterar'),
        ),
      ],
    );
  }
}

class _MasterPasswordWarning extends StatelessWidget {
  const _MasterPasswordWarning();

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
              'Se esqueceres a nova palavra-passe mestra, não será possível recuperar o cofre.',
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
        _oldPinError = 'PIN antigo incorreto.';
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
  final TrashRetentionOption trashRetention;

  const _PasswordHealthDashboard({required this.trashRetention});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(vaultProvider).data?.entries ?? [];
    final ignoredAlertExpiries = ref.watch(
      ignoredEntryAlertsProvider.select((value) => value.valueOrNull),
    );
    if (ignoredAlertExpiries == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    final report = PasswordHealthService.analyze(
      entries,
      trashRetention: trashRetention,
      ignoredAlertExpiries: ignoredAlertExpiries,
    );
    final tokens = EncryVaultTheme.of(context);
    if (tokens.designMode == AppDesignMode.modern) {
      return _ModernPasswordHealthDashboard(
        report: report,
        entries: entries,
        trashRetention: trashRetention,
        ignoredAlertExpiries: ignoredAlertExpiries,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(report.summary),
        ),
        IgnoredAlertsSection(
          entries: entries,
          ignoredAlertExpiries: ignoredAlertExpiries,
        ),
        const Divider(height: 1),
        _HealthStatTile(label: 'Total de entradas ativas', value: report.total),
        _HealthIssueTile(
          label: 'Palavras-passe fracas',
          value: report.weak,
          issue: PasswordHealthIssue.weak,
          entries: entries,
          trashRetention: trashRetention,
          ignoredAlertExpiries: ignoredAlertExpiries,
        ),
        _HealthIssueTile(
          label: 'Palavras-passe reutilizadas',
          value: report.reused,
          issue: PasswordHealthIssue.reused,
          entries: entries,
          trashRetention: trashRetention,
          ignoredAlertExpiries: ignoredAlertExpiries,
        ),
        _HealthStatTile(
          label: 'Grupos com palavra-passe repetida',
          value: report.reusedGroups,
        ),
        _HealthIssueTile(
          label: 'Palavras-passe antigas',
          value: report.old,
          issue: PasswordHealthIssue.old,
          entries: entries,
          trashRetention: trashRetention,
          ignoredAlertExpiries: ignoredAlertExpiries,
        ),
        _HealthIssueTile(
          label: 'Sem palavra-passe',
          value: report.empty,
          issue: PasswordHealthIssue.empty,
          entries: entries,
          trashRetention: trashRetention,
          ignoredAlertExpiries: ignoredAlertExpiries,
        ),
        _HealthIssueTile(
          label: 'Sem categoria/etiqueta',
          value: report.uncategorized,
          issue: PasswordHealthIssue.uncategorized,
          entries: entries,
          trashRetention: trashRetention,
          ignoredAlertExpiries: ignoredAlertExpiries,
        ),
        _HealthIssueTile(
          label: 'Nunca abertas',
          value: report.neverOpened,
          issue: PasswordHealthIssue.neverOpened,
          entries: entries,
          trashRetention: trashRetention,
          ignoredAlertExpiries: ignoredAlertExpiries,
        ),
        _HealthIssueTile(
          label: 'Pouco usadas',
          value: report.rarelyUsed,
          issue: PasswordHealthIssue.rarelyUsed,
          entries: entries,
          trashRetention: trashRetention,
          ignoredAlertExpiries: ignoredAlertExpiries,
        ),
        _HealthIssueTile(
          label: 'Histórico grande',
          value: report.largeHistory,
          issue: PasswordHealthIssue.largeHistory,
          entries: entries,
          trashRetention: trashRetention,
          ignoredAlertExpiries: ignoredAlertExpiries,
        ),
        _HealthIssueTile(
          label: 'No Lixo há muito tempo',
          value: report.oldTrash,
          issue: PasswordHealthIssue.oldTrash,
          entries: entries,
          trashRetention: trashRetention,
          ignoredAlertExpiries: ignoredAlertExpiries,
        ),
      ],
    );
  }
}

class _ModernPasswordHealthDashboard extends StatelessWidget {
  const _ModernPasswordHealthDashboard({
    required this.report,
    required this.entries,
    required this.trashRetention,
    required this.ignoredAlertExpiries,
  });

  final PasswordHealthReport report;
  final List<VaultEntry> entries;
  final TrashRetentionOption trashRetention;
  final Map<String, int> ignoredAlertExpiries;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final items = _modernHealthItems(report);
    _ModernHealthItem? firstActionable;
    for (final item in items) {
      if (item.issue != null && item.value > 0) {
        firstActionable = item;
        break;
      }
    }
    final actionItem = firstActionable;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.background,
        gradient: tokens.usesSoftGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tokens.isDark
                    ? const [
                        Color(0xFF030812),
                        Color(0xFF081223),
                        Color(0xFF170D2D),
                      ]
                    : [
                        tokens.background,
                        tokens.surfaceRaised,
                        tokens.background,
                      ],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alertas de palavras-passe',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _ModernHealthScoreCard(report: report),
          const SizedBox(height: 20),
          for (final item in items) ...[
            _ModernHealthIssueCard(
              item: item,
              onTap: item.issue == null || item.value == 0
                  ? null
                  : () => _openHealthIssueDetails(context, item.issue!),
            ),
            const SizedBox(height: 14),
          ],
          AppSurface(
            elevated: true,
            radius: 14,
            padding: EdgeInsets.zero,
            child: IgnoredAlertsSection(
              entries: entries,
              ignoredAlertExpiries: ignoredAlertExpiries,
            ),
          ),
          const SizedBox(height: 44),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.buttonRadius),
              gradient: actionItem == null
                  ? null
                  : LinearGradient(colors: [tokens.accent, tokens.accentMuted]),
            ),
            child: SizedBox(
              width: double.infinity,
              height: tokens.buttonHeight,
              child: ElevatedButton(
                onPressed: actionItem == null
                    ? null
                    : () => _openHealthIssueDetails(context, actionItem.issue!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionItem == null
                      ? Theme.of(context).disabledColor.withValues(alpha: 0.14)
                      : Colors.transparent,
                  foregroundColor: tokens.onAccent,
                  disabledForegroundColor: tokens.textMuted,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.buttonRadius),
                  ),
                ),
                child: const Text('Ver recomendações'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openHealthIssueDetails(
    BuildContext context,
    PasswordHealthIssue issue,
  ) {
    final affectedEntries = PasswordHealthService.entriesForIssue(
      entries,
      issue,
      trashRetention: trashRetention,
      ignoredAlertExpiries: ignoredAlertExpiries,
    );
    if (affectedEntries.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _PasswordHealthDetailsPage(
          title: _healthIssueTitle(issue),
          issue: issue,
          entries: affectedEntries,
          allEntries: entries,
        ),
      ),
    );
  }
}

class _ModernHealthScoreCard extends StatelessWidget {
  const _ModernHealthScoreCard({required this.report});

  final PasswordHealthReport report;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final attentionCount = _attentionCount(report);
    final score = _healthScore(report);

    return AppSurface(
      elevated: true,
      minHeight: 98,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          Text(
            score.toString(),
            style: TextStyle(
              color: tokens.warning,
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'saúde do cofre',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  attentionCount == 1
                      ? '1 ponto precisa de atenção'
                      : '$attentionCount pontos precisam de atenção',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernHealthIssueCard extends StatelessWidget {
  const _ModernHealthIssueCard({required this.item, required this.onTap});

  final _ModernHealthItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);

    return AppSurface(
      elevated: true,
      minHeight: 60,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: item.color.withValues(alpha: 0.55)),
            ),
            child: Icon(
              Icons.priority_high_rounded,
              color: item.color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: tokens.textMuted,
              size: 20,
            ),
        ],
      ),
    );
  }
}

class _ModernHealthItem {
  const _ModernHealthItem({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    this.issue,
  });

  final String label;
  final String subtitle;
  final int value;
  final Color color;
  final PasswordHealthIssue? issue;
}

List<_ModernHealthItem> _modernHealthItems(PasswordHealthReport report) {
  return [
    _ModernHealthItem(
      label: 'Palavras-passe fracas',
      subtitle: _entryCountLabel(report.weak),
      value: report.weak,
      color: const Color(0xFFFF6B6B),
      issue: PasswordHealthIssue.weak,
    ),
    _ModernHealthItem(
      label: 'Palavras-passe reutilizadas',
      subtitle: _groupCountLabel(report.reusedGroups),
      value: report.reused,
      color: const Color(0xFFFFC857),
      issue: PasswordHealthIssue.reused,
    ),
    _ModernHealthItem(
      label: 'Palavras-passe antigas',
      subtitle: _entryCountLabel(report.old),
      value: report.old,
      color: const Color(0xFF8B5CF6),
      issue: PasswordHealthIssue.old,
    ),
    _ModernHealthItem(
      label: 'Sem palavra-passe',
      subtitle: _entryCountLabel(report.empty),
      value: report.empty,
      color: const Color(0xFFFF6B6B),
      issue: PasswordHealthIssue.empty,
    ),
    _ModernHealthItem(
      label: 'Sem categoria/etiqueta',
      subtitle: _entryCountLabel(report.uncategorized),
      value: report.uncategorized,
      color: const Color(0xFF7DB7FF),
      issue: PasswordHealthIssue.uncategorized,
    ),
    _ModernHealthItem(
      label: 'Nunca abertas',
      subtitle: _entryCountLabel(report.neverOpened),
      value: report.neverOpened,
      color: const Color(0xFF3B82F6),
      issue: PasswordHealthIssue.neverOpened,
    ),
    _ModernHealthItem(
      label: 'Pouco usadas',
      subtitle: _entryCountLabel(report.rarelyUsed),
      value: report.rarelyUsed,
      color: const Color(0xFF32D5FF),
      issue: PasswordHealthIssue.rarelyUsed,
    ),
    _ModernHealthItem(
      label: 'Histórico grande',
      subtitle: _entryCountLabel(report.largeHistory),
      value: report.largeHistory,
      color: const Color(0xFF8B5CF6),
      issue: PasswordHealthIssue.largeHistory,
    ),
    _ModernHealthItem(
      label: 'No Lixo há muito tempo',
      subtitle: _entryCountLabel(report.oldTrash),
      value: report.oldTrash,
      color: const Color(0xFFFFC857),
      issue: PasswordHealthIssue.oldTrash,
    ),
  ];
}

String _entryCountLabel(int count) {
  return '$count ${count == 1 ? 'entrada' : 'entradas'}';
}

String _groupCountLabel(int count) {
  return '$count ${count == 1 ? 'grupo' : 'grupos'}';
}

int _attentionCount(PasswordHealthReport report) {
  return PasswordHealthService.vaultHealthAttentionPoints(report);
}

int _healthScore(PasswordHealthReport report) {
  return PasswordHealthService.vaultHealthScore(report);
}

String _healthIssueTitle(PasswordHealthIssue issue) {
  switch (issue) {
    case PasswordHealthIssue.weak:
      return 'Palavras-passe fracas';
    case PasswordHealthIssue.reused:
      return 'Palavras-passe reutilizadas';
    case PasswordHealthIssue.old:
      return 'Palavras-passe antigas';
    case PasswordHealthIssue.empty:
      return 'Sem palavra-passe';
    case PasswordHealthIssue.uncategorized:
      return 'Sem categoria/etiqueta';
    case PasswordHealthIssue.neverOpened:
      return 'Nunca abertas';
    case PasswordHealthIssue.rarelyUsed:
      return 'Pouco usadas';
    case PasswordHealthIssue.largeHistory:
      return 'Histórico grande';
    case PasswordHealthIssue.oldTrash:
      return 'No Lixo há muito tempo';
  }
}

class _HealthIssueTile extends StatelessWidget {
  final String label;
  final int value;
  final PasswordHealthIssue issue;
  final List<VaultEntry> entries;
  final TrashRetentionOption trashRetention;
  final Map<String, int> ignoredAlertExpiries;

  const _HealthIssueTile({
    required this.label,
    required this.value,
    required this.issue,
    required this.entries,
    required this.trashRetention,
    required this.ignoredAlertExpiries,
  });

  @override
  Widget build(BuildContext context) {
    final affectedEntries = PasswordHealthService.entriesForIssue(
      entries,
      issue,
      trashRetention: trashRetention,
      ignoredAlertExpiries: ignoredAlertExpiries,
    );
    return _HealthStatTile(
      label: label,
      value: value,
      onTap: affectedEntries.isEmpty
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => _PasswordHealthDetailsPage(
                    title: label,
                    issue: issue,
                    entries: affectedEntries,
                    allEntries: entries,
                  ),
                ),
              );
            },
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
  final PasswordHealthIssue issue;
  final List<VaultEntry> entries;
  final List<VaultEntry> allEntries;

  const _PasswordHealthDetailsPage({
    required this.title,
    required this.issue,
    required this.entries,
    required this.allEntries,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final useModernCards = usesModernPasswordHealthDetailsCards(
      tokens.designMode,
    );
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: EdgeInsets.all(tokens.pagePadding),
        itemCount: entries.length,
        separatorBuilder: (context, index) => useModernCards
            ? const SizedBox(height: 12)
            : const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final reason = PasswordHealthService.reasonForIssue(
            issue: issue,
            entries: allEntries,
            entry: entry,
          );
          final tile = ListTile(
            contentPadding: EdgeInsets.zero,
            leading: useModernCards
                ? VaultCategoryIcon(category: entry.category, size: 42)
                : Icon(
                    Icons.warning_amber_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
            title: Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: useModernCards
                  ? Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    )
                  : null,
            ),
            subtitle: Text(
              [
                if (entry.username.isNotEmpty) entry.username,
                reason,
              ].join('\n'),
              style: useModernCards
                  ? Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                      height: 1.25,
                    )
                  : null,
            ),
            isThreeLine: entry.username.isNotEmpty,
            trailing: entry.isDeleted ? null : const Icon(Icons.chevron_right),
            onTap: entry.isDeleted
                ? null
                : () => context.push(RouterPaths.vaultEntryView(entry.id)),
          );
          if (!useModernCards) return tile;
          return AppSurface(
            elevated: true,
            padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
            radius: tokens.cardRadius,
            child: tile,
          );
        },
      ),
    );
  }
}
