import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/constants.dart';
import '../storage/preferences_service.dart';

class IgnoredAlertDurationOption {
  final String label;
  final Duration? duration;

  const IgnoredAlertDurationOption({
    required this.label,
    required this.duration,
  });

  bool get hasExpiry => duration != null;

  String get confirmationMessage {
    if (!hasExpiry) return 'Aviso ignorado até ativar novamente.';
    return 'Aviso ignorado por $label.';
  }

  int expiryValue(DateTime now) {
    final duration = this.duration;
    if (duration == null) return VaultConstants.ignoredAlertNoExpiryValue;
    return now.toUtc().add(duration).millisecondsSinceEpoch;
  }

  static const values = [
    IgnoredAlertDurationOption(label: '1 hora', duration: Duration(hours: 1)),
    IgnoredAlertDurationOption(label: '8 horas', duration: Duration(hours: 8)),
    IgnoredAlertDurationOption(
      label: '24 horas',
      duration: Duration(hours: 24),
    ),
    IgnoredAlertDurationOption(label: '7 dias', duration: Duration(days: 7)),
    // Meses sao guardados como duracoes fixas para evitar regras ambiguas em
    // finais de mes, anos bissextos e mudancas de calendario.
    IgnoredAlertDurationOption(label: '1 mês', duration: Duration(days: 30)),
    IgnoredAlertDurationOption(label: '3 meses', duration: Duration(days: 90)),
    IgnoredAlertDurationOption(label: 'Até ativar novamente', duration: null),
  ];
}

class IgnoredAlertExpiries {
  const IgnoredAlertExpiries._();

  static bool isIgnored(
    String key,
    Map<String, int> expiries, {
    DateTime? now,
  }) {
    final expiry = expiries[key];
    if (expiry == null) return false;
    if (expiry == VaultConstants.ignoredAlertNoExpiryValue) return true;
    final reference = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return expiry > reference;
  }

  static Map<String, int> removeExpired(
    Map<String, int> expiries, {
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return Map<String, int>.from(expiries)..removeWhere(
      (_, expiry) =>
          expiry != VaultConstants.ignoredAlertNoExpiryValue &&
          expiry <= reference,
    );
  }
}

class IgnoredEntryAlertsController
    extends StateNotifier<AsyncValue<Map<String, int>>> {
  IgnoredEntryAlertsController(this._preferences)
    : super(const AsyncValue.loading()) {
    load();
  }

  final PreferencesService _preferences;

  Future<void> load({DateTime? now}) async {
    final saved = await _preferences.getIgnoredEntryAlertExpiries();
    final cleaned = IgnoredAlertExpiries.removeExpired(saved, now: now);
    if (cleaned.length != saved.length) {
      await _preferences.setIgnoredEntryAlertExpiries(cleaned);
    }
    state = AsyncValue.data(cleaned);
  }

  Future<void> ignore(
    String key,
    IgnoredAlertDurationOption duration, {
    DateTime? now,
  }) async {
    final current = state.valueOrNull ?? {};
    final cleaned = IgnoredAlertExpiries.removeExpired(current, now: now);
    final expiry = duration.expiryValue(now ?? DateTime.now());
    final updated = {...cleaned, key: expiry};
    await _preferences.setIgnoredEntryAlertExpiries(updated);
    state = AsyncValue.data(updated);
  }

  Future<void> remove(String key, {DateTime? now}) async {
    final current = state.valueOrNull ?? {};
    final cleaned = IgnoredAlertExpiries.removeExpired(current, now: now)
      ..remove(key);
    await _preferences.setIgnoredEntryAlertExpiries(cleaned);
    state = AsyncValue.data(cleaned);
  }
}

final ignoredEntryAlertsProvider =
    StateNotifierProvider<
      IgnoredEntryAlertsController,
      AsyncValue<Map<String, int>>
    >((ref) {
      return IgnoredEntryAlertsController(ref.read(preferencesServiceProvider));
    });
