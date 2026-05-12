import 'package:flutter/material.dart';

import '../config/theme/design_tokens.dart';
import '../models/app_design_mode.dart';

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final isClassic = tokens.designMode == AppDesignMode.classic;
    final effectiveSize = size ?? (isClassic ? 72.0 : 104.0);
    final imagePadding = effectiveSize * (isClassic ? 0.14 : 0.13);
    final radius = isClassic ? tokens.cardRadius + 2 : effectiveSize / 2;
    final haloColor = isClassic
        ? tokens.surfaceRaised
        : tokens.accent.withValues(alpha: tokens.isDark ? 0.12 : 0.07);
    final borderColor = isClassic
        ? tokens.border
        : tokens.accent.withValues(alpha: tokens.isDark ? 0.55 : 0.24);

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        color: haloColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: tokens.accent.withValues(
              alpha: isClassic
                  ? (tokens.isDark ? 0.1 : 0.06)
                  : (tokens.isDark ? 0.16 : 0.06),
            ),
            blurRadius: isClassic ? 16 : (tokens.isDark ? 28 : 18),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(imagePadding),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isClassic ? 10 : 22),
          child: Image.asset(
            'assets/branding/app_icon.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
