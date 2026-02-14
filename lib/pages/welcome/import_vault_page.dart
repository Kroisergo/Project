import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../services/storage/preferences_service.dart';
import '../../services/storage/vault_file_service.dart';
import '../../services/vault/vault_state.dart';
import '../../utils/constants.dart';
import '../unlock/unlock_page.dart';
import '../welcome/welcome_page.dart';

class ImportVaultPage extends ConsumerStatefulWidget {
  static const routePath = '/import';
  static const routeName = 'import';

  const ImportVaultPage({super.key});

  @override
  ConsumerState<ImportVaultPage> createState() => _ImportVaultPageState();
}

class _ImportVaultPageState extends ConsumerState<ImportVaultPage> {
  bool _busy = false;
  final _vaultFileService = VaultFileService();
  final _prefs = PreferencesService();
  final _pathController = TextEditingController();
  String _path = '';

  @override
  void initState() {
    super.initState();
    _initDefault();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _initDefault() async {
    final docs = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    _path = p.join(docs.path, VaultConstants.defaultVaultName);
    _pathController.text = _path;
    setState(() {});
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      _path = _pathController.text.trim();
      if (_path.isEmpty) throw Exception('Indica caminho do ficheiro .vltx');
      final currentName = await _prefs.getVaultFileName();
      final targetName = _vaultFileService.normalizeVaultName(
        currentName ?? p.basename(_path),
      );
      await _vaultFileService.importVaultFrom(_path, targetFileName: targetName);
      await _prefs.setVaultFileName(targetName);
      ref.read(vaultProvider.notifier).clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cofre importado de: $_path')));
      context.go(UnlockPage.routePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao importar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Cofre'),
        leading: BackButton(
          onPressed: () => context.go(WelcomePage.routePath),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: 'Caminho do ficheiro (.vltx)',
              ),
              onChanged: (v) => _path = v.trim(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Seleciona um ficheiro .vltx para substituir o cofre local.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ? null : _import,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Importar'),
            ),
            if (_busy) const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}
