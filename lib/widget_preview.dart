import 'package:flutter/material.dart';
import 'package:encryvault/pages/vault_settings/vault_settings_page.dart'; // <-- ajusta

void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VaultSettingsPage(),
    );
  }
}