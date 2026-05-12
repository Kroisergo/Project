import 'package:flutter/material.dart';

import '../../../config/theme/design_tokens.dart';
import '../../../models/app_design_mode.dart';

enum VaultDocumentAction { preview, details, export, delete }

class VaultDocumentsCardActions extends StatelessWidget {
  const VaultDocumentsCardActions({
    super.key,
    required this.onDetails,
    required this.onPreview,
    required this.onExport,
    required this.onDelete,
  });

  final VoidCallback onDetails;
  final VoidCallback onPreview;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final isClassic = tokens.designMode == AppDesignMode.classic;

    return PopupMenuButton<VaultDocumentAction>(
      tooltip: 'Ações',
      color: tokens.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isClassic ? 10 : 18),
        side: BorderSide(color: tokens.border),
      ),
      onSelected: (action) {
        switch (action) {
          case VaultDocumentAction.preview:
            onPreview();
          case VaultDocumentAction.details:
            onDetails();
          case VaultDocumentAction.export:
            onExport();
          case VaultDocumentAction.delete:
            onDelete();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: VaultDocumentAction.preview,
          child: _DocumentMenuRow(
            icon: Icons.visibility_outlined,
            label: 'Visualizar',
          ),
        ),
        PopupMenuItem(
          value: VaultDocumentAction.details,
          child: _DocumentMenuRow(icon: Icons.info_outline, label: 'Detalhes'),
        ),
        PopupMenuItem(
          value: VaultDocumentAction.export,
          child: _DocumentMenuRow(
            icon: Icons.file_download_outlined,
            label: 'Exportar documento',
          ),
        ),
        PopupMenuItem(
          value: VaultDocumentAction.delete,
          child: _DocumentMenuRow(
            icon: Icons.delete_outline_rounded,
            label: 'Eliminar documento',
          ),
        ),
      ],
    );
  }
}

class _DocumentMenuRow extends StatelessWidget {
  const _DocumentMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Flexible(child: Text(label)),
      ],
    );
  }
}
