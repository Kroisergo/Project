import 'package:flutter/material.dart';

import '../config/theme/design_tokens.dart';
import '../models/vault_entry.dart';

class VaultCategoryIcon extends StatelessWidget {
  const VaultCategoryIcon({
    super.key,
    required this.category,
    this.size = 48,
    this.iconSize,
  });

  final VaultEntryCategory category;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final accent = vaultEntryCategoryColor(category, tokens.isDark);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Icon(
        vaultEntryCategoryIcon(category),
        color: accent,
        size: iconSize ?? size * 0.44,
      ),
    );
  }
}

IconData vaultEntryCategoryIcon(VaultEntryCategory category) {
  switch (category) {
    case VaultEntryCategory.social:
      return Icons.alternate_email_rounded;
    case VaultEntryCategory.email:
      return Icons.mail_outline_rounded;
    case VaultEntryCategory.bank:
      return Icons.account_balance_outlined;
    case VaultEntryCategory.games:
      return Icons.sports_esports_outlined;
    case VaultEntryCategory.work:
      return Icons.work_outline_rounded;
    case VaultEntryCategory.other:
      return Icons.lock_outline_rounded;
  }
}

Color vaultEntryCategoryColor(VaultEntryCategory category, bool isDark) {
  switch (category) {
    case VaultEntryCategory.social:
      return isDark ? const Color(0xFF8BD3DD) : const Color(0xFF047481);
    case VaultEntryCategory.email:
      return isDark ? const Color(0xFFB9A7FF) : const Color(0xFF6D5BD0);
    case VaultEntryCategory.bank:
      return isDark ? const Color(0xFF8EE6A7) : const Color(0xFF16803C);
    case VaultEntryCategory.games:
      return isDark ? const Color(0xFFFFC857) : const Color(0xFFB7791F);
    case VaultEntryCategory.work:
      return isDark ? const Color(0xFF7DB7FF) : const Color(0xFF1C64D1);
    case VaultEntryCategory.other:
      return isDark ? const Color(0xFFC9CED6) : const Color(0xFF667085);
  }
}
