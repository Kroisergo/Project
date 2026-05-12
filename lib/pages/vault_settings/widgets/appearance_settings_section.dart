import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_design_mode.dart';
import '../../../services/theme/app_design_controller.dart';
import '../../../services/theme/theme_mode_controller.dart';
import '../../../widgets/theme_mode_card_selector.dart';

class AppearanceSettingsSection extends ConsumerWidget {
  const AppearanceSettingsSection({
    super.key,
    this.enabled = true,
    this.onStateChanged,
  });

  final bool enabled;
  final VoidCallback? onStateChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designMode =
        ref.watch(appDesignControllerProvider).valueOrNull ??
        AppDesignMode.modern;
    final themeMode =
        ref.watch(themeModeControllerProvider).valueOrNull ?? ThemeMode.system;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Design', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppDesignMode>(
              segments: AppDesignMode.values
                  .map(
                    (mode) => ButtonSegment<AppDesignMode>(
                      value: mode,
                      label: Text(mode.label),
                    ),
                  )
                  .toList(),
              selected: {designMode},
              onSelectionChanged: enabled
                  ? (selection) =>
                        _setDesignMode(context, ref, selection.single)
                  : null,
            ),
          ),
          const SizedBox(height: 18),
          if (usesModernThemeModeCards(designMode))
            ThemeModeCardSelector(
              selected: themeMode,
              enabled: enabled,
              onChanged: (mode) => _setThemeMode(context, ref, mode),
            )
          else ...[
            Text('Tema', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('Sistema'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Claro'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Escuro'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: enabled
                    ? (selection) =>
                          _setThemeMode(context, ref, selection.single)
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setDesignMode(
    BuildContext context,
    WidgetRef ref,
    AppDesignMode mode,
  ) async {
    onStateChanged?.call();
    await ref.read(appDesignControllerProvider.notifier).setMode(mode);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Design ajustado para ${mode.label}')),
    );
  }

  Future<void> _setThemeMode(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
  ) async {
    onStateChanged?.call();
    await ref.read(themeModeControllerProvider.notifier).setMode(mode);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tema ajustado para ${_themeModeLabel(mode)}')),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Sistema';
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Escuro';
    }
  }
}
