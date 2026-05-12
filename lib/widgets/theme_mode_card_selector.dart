import 'package:flutter/material.dart';

import '../config/theme/design_tokens.dart';
import '../models/app_design_mode.dart';
import 'app_surface.dart';

class ThemeModeCardSelector extends StatelessWidget {
  const ThemeModeCardSelector({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final ThemeMode selected;
  final bool enabled;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);

    return AppSurface(
      elevated: true,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      borderColor: tokens.accent.withValues(alpha: tokens.isDark ? 0.22 : 0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(
                    alpha: tokens.isDark ? 0.18 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: tokens.accent.withValues(
                      alpha: tokens.isDark ? 0.34 : 0.18,
                    ),
                  ),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: tokens.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Escolhe como queres ver a app',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ThemeModeOptionCard(
                mode: ThemeMode.system,
                label: 'Sistema',
                icon: Icons.devices_outlined,
                selected: selected == ThemeMode.system,
                enabled: enabled,
                onChanged: onChanged,
              ),
              const SizedBox(width: 8),
              _ThemeModeOptionCard(
                mode: ThemeMode.light,
                label: 'Claro',
                icon: Icons.light_mode_outlined,
                selected: selected == ThemeMode.light,
                enabled: enabled,
                onChanged: onChanged,
              ),
              const SizedBox(width: 8),
              _ThemeModeOptionCard(
                mode: ThemeMode.dark,
                label: 'Escuro',
                icon: Icons.dark_mode_outlined,
                selected: selected == ThemeMode.dark,
                enabled: enabled,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeModeOptionCard extends StatelessWidget {
  const _ThemeModeOptionCard({
    required this.mode,
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final ThemeMode mode;
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = EncryVaultTheme.of(context);
    final foreground = selected ? tokens.textPrimary : tokens.textSecondary;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? () => onChanged(mode) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 92,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? tokens.accent.withValues(alpha: tokens.isDark ? 0.18 : 0.1)
                  : tokens.inputFill.withValues(alpha: enabled ? 1 : 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? tokens.accent.withValues(
                        alpha: tokens.isDark ? 0.64 : 0.38,
                      )
                    : tokens.border,
                width: selected ? 1.3 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: tokens.accent.withValues(
                          alpha: tokens.isDark ? 0.16 : 0.08,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: selected ? tokens.accent : foreground),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool usesModernThemeModeCards(AppDesignMode designMode) {
  return designMode == AppDesignMode.modern;
}
