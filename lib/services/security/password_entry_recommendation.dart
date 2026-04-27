import 'package:password_strength_checker/password_strength_checker.dart';

import '../../utils/time_labels.dart';

class PasswordEntryRecommendation {
  final PasswordStrength? strength;
  final Duration changeAfter;
  final DateTime dueAt;

  const PasswordEntryRecommendation({
    required this.strength,
    required this.changeAfter,
    required this.dueAt,
  });

  bool get isDue => !DateTime.now().toUtc().isBefore(dueAt);

  String get strengthLabel {
    return switch (strength) {
      PasswordStrength.alreadyExposed => 'exposta',
      PasswordStrength.weak => 'fraca',
      PasswordStrength.medium => 'média',
      PasswordStrength.strong => 'forte',
      PasswordStrength.secure => 'segura',
      null => 'por avaliar',
    };
  }

  String get recommendationText {
    if (isDue) {
      return 'Muda a palavra-passe agora.';
    }
    return 'Mudar dentro de ${formatRemaining(dueAt)}.';
  }
}

class PasswordEntryRecommendationService {
  const PasswordEntryRecommendationService._();

  static PasswordEntryRecommendation evaluate({
    required String password,
    required DateTime passwordUpdatedAt,
  }) {
    final strength = password.isEmpty
        ? null
        : PasswordStrength.calculate(text: password);
    final changeAfter = _changeAfter(strength);
    return PasswordEntryRecommendation(
      strength: strength,
      changeAfter: changeAfter,
      dueAt: passwordUpdatedAt.toUtc().add(changeAfter),
    );
  }

  static Duration _changeAfter(PasswordStrength? strength) {
    return switch (strength) {
      PasswordStrength.alreadyExposed => const Duration(days: 30),
      PasswordStrength.weak => const Duration(days: 30),
      PasswordStrength.medium => const Duration(days: 90),
      PasswordStrength.strong => const Duration(days: 180),
      PasswordStrength.secure => const Duration(days: 180),
      null => const Duration(days: 30),
    };
  }
}
