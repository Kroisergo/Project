import 'package:flutter/material.dart';

import '../config/theme/design_tokens.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevated = false,
    this.radius,
    this.backgroundColor,
    this.borderColor,
    this.leadingAccentColor,
    this.leadingAccentWidth = 0,
    this.minHeight,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool elevated;
  final double? radius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? leadingAccentColor;
  final double leadingAccentWidth;
  final double? minHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final effectiveRadius = radius ?? tokens.cardRadius;
    final decoration = BoxDecoration(
      color:
          backgroundColor ?? (elevated ? tokens.surfaceRaised : tokens.surface),
      borderRadius: BorderRadius.circular(effectiveRadius),
      border: Border.all(color: borderColor ?? tokens.border),
      boxShadow: elevated ? tokens.cardShadow : const [],
    );

    final paddedChild = Padding(
      padding: padding ?? EdgeInsets.all(tokens.pagePadding),
      child: child,
    );

    final surfaceChild = leadingAccentColor == null || leadingAccentWidth <= 0
        ? paddedChild
        : ClipRRect(
            borderRadius: BorderRadius.circular(effectiveRadius),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: leadingAccentWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: leadingAccentColor),
                  ),
                ),
                paddedChild,
              ],
            ),
          );

    final content = Container(
      margin: margin,
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: minHeight!),
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: onTap == null
            ? surfaceChild
            : InkWell(
                borderRadius: BorderRadius.circular(effectiveRadius),
                onTap: onTap,
                child: surfaceChild,
              ),
      ),
    );

    return content;
  }
}
