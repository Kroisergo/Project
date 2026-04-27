import 'package:password_strength_checker/password_strength_checker.dart';

class PasswordFeedbackService {
  const PasswordFeedbackService._();

  static List<String> messages({
    required String password,
    bool isReused = false,
  }) {
    final value = password.trim();
    if (value.isEmpty) {
      return const ['Sem palavra-passe guardada.'];
    }

    final feedback = <String>[];
    final lower = value.toLowerCase();
    final strength = PasswordStrength.calculate(text: value);

    if (strength == PasswordStrength.alreadyExposed) {
      feedback.add('Parece uma palavra-passe exposta ou muito comum.');
    }
    if (value.length < 8) {
      feedback.add('Muito curta.');
    } else if (value.length < 12) {
      feedback.add('Curta; 12 ou mais caracteres e recomendado.');
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      feedback.add('Sem letras maiusculas.');
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      feedback.add('Sem letras minusculas.');
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      feedback.add('Sem numeros.');
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      feedback.add('Sem simbolos.');
    }
    if (RegExp(r'(.)\1{2,}').hasMatch(value)) {
      feedback.add('Tem caracteres demasiado repetidos.');
    }
    if (_hasCommonPattern(lower)) {
      feedback.add('Contem padroes comuns ou previsiveis.');
    }
    if (isReused) {
      feedback.add('Parece reutilizada noutra entrada.');
    }

    if (feedback.isEmpty) {
      if (strength == PasswordStrength.secure) {
        feedback.add('Muito forte.');
      } else if (strength == PasswordStrength.strong) {
        feedback.add('Forte.');
      } else {
        feedback.add('Razoavel; podes melhorar com mais comprimento.');
      }
    }

    return feedback;
  }

  static bool _hasCommonPattern(String lower) {
    const patterns = [
      '1234',
      'abcd',
      'qwerty',
      'password',
      'passw0rd',
      'palavrapasse',
      'senha',
      'admin',
      'letmein',
      '0000',
      '1111',
    ];
    return patterns.any(lower.contains);
  }
}
