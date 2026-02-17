import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../services/storage/preferences_service.dart';
import '../../services/storage/vault_file_service.dart';
import '../../services/theme/theme_mode_controller.dart';
import '../../services/vault/auto_lock_controller.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/constants.dart';
import '../unlock/unlock_page.dart';

class VaultSettingsPage extends ConsumerStatefulWidget {
  static const subPath = 'settings';
  static const routeName = 'vault-settings';

  const VaultSettingsPage({super.key});

  @override
  ConsumerState<VaultSettingsPage> createState() => _VaultSettingsPageState();
}

class _VaultSettingsPageState extends ConsumerState<VaultSettingsPage> with WidgetsBindingObserver {
  final _vaultFileService = VaultFileService();
  final _prefs = PreferencesService();
  bool _busy = false;
  final _exportController = TextEditingController();
  final _importController = TextEditingController();
  String _vaultFileName = VaultConstants.defaultVaultName;
  int _autoLockMinutes = 2;
  ThemeMode _themeMode = ThemeMode.system;
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
    final defaultExport = p.join(docs.path, 'vault_export${VaultConstants.vaultExtension}');
    final minutes = await _prefs.getAutoLockMinutes();
    final savedThemeMode = await _prefs.getThemeMode();
    final savedName = await _prefs.getVaultFileName();
    final normalized = _vaultFileService.normalizeVaultName(savedName);
    if (!mounted) return;
    _vaultFileName = normalized;
    _exportController.text = defaultExport;
    _importController.text = defaultExport;
    setState(() {
      _autoLockMinutes = minutes;
      _themeMode = savedThemeMode;
    });
  }

  void _onLocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessão bloqueada.')),
    );
    context.go(UnlockPage.routePath);
  }

  Future<void> _exportVault() async {
    await _autoLock.restart();
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final exportPath = _exportController.text.trim();
      if (exportPath.isEmpty) throw Exception('Indica o caminho de destino.');
      await _vaultFileService.exportVaultTo(exportPath, fileName: _vaultFileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportado para: $exportPath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importVault() async {
    await _autoLock.restart();
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final importPath = _importController.text.trim();
      if (importPath.isEmpty) throw Exception('Indica o caminho do ficheiro a importar.');
      await _vaultFileService.importVaultFrom(importPath, targetFileName: _vaultFileName);
      await _prefs.setVaultFileName(_vaultFileName);
      ref.read(vaultProvider.notifier).clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importação concluída.')));
      context.go(UnlockPage.routePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao importar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateAutoLock(int minutes) async {
    setState(() {
      _autoLockMinutes = minutes;
    });
    await _prefs.setAutoLockMinutes(minutes);
    await _autoLock.refreshTimeout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Auto-lock ajustado para $minutes minutos')),
    );
  }

  Future<void> _updateThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    await ref.read(themeModeControllerProvider.notifier).setMode(mode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tema ajustado para ${_themeModeLabel(mode)}')),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _exportController,
                decoration: const InputDecoration(
                  labelText: 'Destino exportação (.vltx)',
                ),
                onChanged: (v) {},
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Exportar cofre'),
                subtitle: const Text('Guarda uma cópia cifrada (.vltx)'),
                onTap: _busy ? null : _exportVault,
              ),
              const Divider(),
              TextFormField(
                controller: _importController,
                decoration: const InputDecoration(
                  labelText: 'Origem importação (.vltx)',
                ),
                onChanged: (v) {},
              ),
              ListTile(
                leading: const Icon(Icons.upload_outlined),
                title: const Text('Importar cofre'),
                subtitle: const Text('Substitui o cofre atual pelo ficheiro selecionado'),
                onTap: _busy ? null : _importVault,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Auto-lock'),
                subtitle: const Text('Tempo de inatividade até bloquear'),
                trailing: DropdownButton<int>(
                  value: _autoLockMinutes,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 min')),
                    DropdownMenuItem(value: 2, child: Text('2 min')),
                    DropdownMenuItem(value: 5, child: Text('5 min')),
                    DropdownMenuItem(value: 10, child: Text('10 min')),
                  ],
                  onChanged: _busy ? null : (v) => _updateAutoLock(v ?? 2),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Tema'),
                subtitle: const Text('Modo de aparencia da aplicacao'),
                trailing: DropdownButton<ThemeMode>(
                  value: _themeMode,
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('Sistema')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Escuro')),
                  ],
                  onChanged: _busy ? null : (mode) => _updateThemeMode(mode ?? ThemeMode.system),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
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
