import 'package:flutter/material.dart';

import '../../../config/theme/design_tokens.dart';
import '../../../models/app_design_mode.dart';
import '../../../models/vault_document.dart';
import '../../../utils/file_size_labels.dart';
import '../../../widgets/app_surface.dart';
import 'vault_documents_card_actions.dart';

class VaultDocumentCard extends StatelessWidget {
  const VaultDocumentCard({
    super.key,
    required this.document,
    required this.onExport,
    required this.onDelete,
    required this.onDetails,
  });

  final VaultDocumentMetadata document;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final isClassic = tokens.designMode == AppDesignMode.classic;
    return AppSurface(
      elevated: !isClassic,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(isClassic ? 10 : 16),
              border: Border.all(color: tokens.border),
            ),
            child: Icon(Icons.description_outlined, color: tokens.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_typeLabel(document)}  |  ${formatFileSize(document.sizeBytes)}  |  ${_formatDate(document.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          VaultDocumentsCardActions(
            onDetails: onDetails,
            onExport: onExport,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

String _typeLabel(VaultDocumentMetadata document) {
  if (document.extension.isNotEmpty) return '.${document.extension}';
  return document.mimeType;
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
