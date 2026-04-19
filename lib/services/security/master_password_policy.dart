import 'package:password_strength_checker/password_strength_checker.dart';

class PasswordRequirement {
  final String label;
  final bool met;

  const PasswordRequirement({required this.label, required this.met});
}

class MasterPasswordPolicyResult {
  final String password;
  final PasswordStrength? strength;

  const MasterPasswordPolicyResult({
    required this.password,
    required this.strength,
  });

  bool get hasMinLength => password.length >= MasterPasswordPolicy.minLength;

  bool get hasUppercase => RegExp(r'[A-Z]').hasMatch(password);

  bool get hasLowercase => RegExp(r'[a-z]').hasMatch(password);

  bool get hasNumber => RegExp(r'[0-9]').hasMatch(password);

  bool get hasSpecialChar =>
      MasterPasswordPolicy.hasAllowedSpecialChar(password);

  bool get isValid => requirements.every((requirement) => requirement.met);

  List<PasswordRequirement> get requirements => [
    PasswordRequirement(
      label: 'Minimo ${MasterPasswordPolicy.minLength} caracteres',
      met: hasMinLength,
    ),
    PasswordRequirement(
      label: 'Pelo menos 1 letra maiuscula',
      met: hasUppercase,
    ),
    PasswordRequirement(
      label: 'Pelo menos 1 letra minuscula',
      met: hasLowercase,
    ),
    PasswordRequirement(label: 'Pelo menos 1 numero', met: hasNumber),
    PasswordRequirement(
      label: 'Pelo menos 1 caracter especial permitido',
      met: hasSpecialChar,
    ),
  ];

  String? get firstMissingRequirement {
    for (final requirement in requirements) {
      if (!requirement.met) return requirement.label;
    }
    return null;
  }
}

class MasterPasswordPolicy {
  static const minLength = 12;
  static const specialChars = [
    '!',
    '@',
    '#',
    r'$',
    '%',
    '&',
    '*',
    '(',
    ')',
    '?',
    '-',
    '_',
    '=',
  ];

  const MasterPasswordPolicy._();

  static bool hasAllowedSpecialChar(String password) {
    return password.split('').any(specialChars.contains);
  }

  static MasterPasswordPolicyResult evaluate(String password) {
    return MasterPasswordPolicyResult(
      password: password,
      strength: strengthOf(password),
    );
  }

  static PasswordStrength? strengthOf(String password) {
    if (password.isEmpty) return null;
    return PasswordStrength.calculate(text: password);
  }
}
