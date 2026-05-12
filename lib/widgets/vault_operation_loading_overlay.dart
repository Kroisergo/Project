import 'package:flutter/material.dart';

import '../config/theme/design_tokens.dart';
import '../models/app_design_mode.dart';
import 'app_brand_mark.dart';
import 'app_surface.dart';

class VaultOperationLoadingOverlay extends StatelessWidget {
  const VaultOperationLoadingOverlay({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final isModern = usesModernVaultLoadingStyle(tokens.designMode);

    return Positioned.fill(
      child: ColoredBox(
        color: tokens.background.withValues(alpha: tokens.isDark ? 0.92 : 0.88),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isModern && tokens.usesSoftGradient
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: tokens.isDark
                        ? const [
                            Color(0xF2030812),
                            Color(0xF2081223),
                            Color(0xF2170D2D),
                          ]
                        : [
                            tokens.background.withValues(alpha: 0.94),
                            tokens.surfaceRaised.withValues(alpha: 0.94),
                            tokens.background.withValues(alpha: 0.94),
                          ],
                  )
                : null,
          ),
          child: Stack(
            children: [
              const ModalBarrier(dismissible: false, color: Colors.transparent),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: isModern
                        ? _ModernLoadingCard(title: title, message: message)
                        : _ClassicLoadingCard(title: title, message: message),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernLoadingCard extends StatefulWidget {
  const _ModernLoadingCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_ModernLoadingCard> createState() => _ModernLoadingCardState();
}

class _ModernLoadingCardState extends State<_ModernLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.94,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.06,
          end: 0.94,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);

    return AppSurface(
      elevated: true,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      borderColor: tokens.accent.withValues(alpha: tokens.isDark ? 0.34 : 0.2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                scale: _pulse,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.24),
                        blurRadius: 34,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              RotationTransition(
                turns: _controller,
                child: SizedBox(
                  width: 132,
                  height: 132,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    strokeCap: StrokeCap.round,
                    value: 0.26,
                    color: tokens.accent.withValues(alpha: 0.7),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              SizedBox(
                width: 118,
                height: 118,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                  color: tokens.accent,
                  backgroundColor: tokens.accent.withValues(alpha: 0.12),
                ),
              ),
              const AppBrandMark(size: 82),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            minHeight: 4,
            color: tokens.accent,
            backgroundColor: tokens.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}

class _ClassicLoadingCard extends StatelessWidget {
  const _ClassicLoadingCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);

    return AppSurface(
      elevated: false,
      radius: 12,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      leadingAccentColor: tokens.accentMuted,
      leadingAccentWidth: 3,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: tokens.accent,
              backgroundColor: tokens.border,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool usesModernVaultLoadingStyle(AppDesignMode designMode) {
  return designMode == AppDesignMode.modern;
}
