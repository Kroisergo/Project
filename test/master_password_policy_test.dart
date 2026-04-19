import 'package:flutter_test/flutter_test.dart';
import 'package:password_strength_checker/password_strength_checker.dart';

import 'package:encryvault/services/security/master_password_policy.dart';

void main() {
  group('MasterPasswordPolicy', () {
    test('rejects passwords missing mandatory requirements', () {
      expect(MasterPasswordPolicy.evaluate('Short1!').isValid, isFalse);
      expect(
        MasterPasswordPolicy.evaluate('longpassword1!').hasUppercase,
        isFalse,
      );
      expect(
        MasterPasswordPolicy.evaluate('LONGPASSWORD1!').hasLowercase,
        isFalse,
      );
      expect(
        MasterPasswordPolicy.evaluate('LongPassword!!').hasNumber,
        isFalse,
      );
      expect(
        MasterPasswordPolicy.evaluate('LongPassword12').hasSpecialChar,
        isFalse,
      );
      expect(
        MasterPasswordPolicy.evaluate('LongPassword12.').hasSpecialChar,
        isFalse,
      );
    });

    test('accepts password that satisfies all requirements', () {
      final result = MasterPasswordPolicy.evaluate('LongPassword12!');

      expect(result.isValid, isTrue);
      expect(result.strength, PasswordStrength.secure);
    });
  });
}
