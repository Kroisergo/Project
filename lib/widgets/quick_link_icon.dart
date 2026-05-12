import 'package:flutter/material.dart';

import '../models/quick_link_preset.dart';

IconData quickLinkIconData(QuickLinkIcon icon) {
  switch (icon) {
    case QuickLinkIcon.social:
      return Icons.groups_2_outlined;
    case QuickLinkIcon.email:
      return Icons.mail_outline;
    case QuickLinkIcon.bank:
      return Icons.account_balance_outlined;
    case QuickLinkIcon.shopping:
      return Icons.shopping_bag_outlined;
    case QuickLinkIcon.work:
      return Icons.work_outline;
    case QuickLinkIcon.games:
      return Icons.sports_esports_outlined;
    case QuickLinkIcon.cloud:
      return Icons.cloud_outlined;
    case QuickLinkIcon.code:
      return Icons.code_outlined;
    case QuickLinkIcon.media:
      return Icons.play_circle_outline;
    case QuickLinkIcon.key:
      return Icons.key_outlined;
    case QuickLinkIcon.other:
      return Icons.link_outlined;
  }
}

class QuickLinkIconBadge extends StatelessWidget {
  final QuickLinkIcon icon;
  final double size;
  final double iconSize;

  const QuickLinkIconBadge({
    super.key,
    required this.icon,
    this.size = 34,
    this.iconSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(size * 0.35),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Icon(
        quickLinkIconData(icon),
        size: iconSize,
        color: colors.primary,
      ),
    );
  }
}
