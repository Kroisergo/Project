import 'dart:math';

import 'package:password_strength_checker/password_strength_checker.dart';

import 'master_password_policy.dart';

class EntryPasswordGeneratorOptions {
  final int length;
  final bool includeUppercase;
  final bool includeLowercase;
  final bool includeNumbers;
  final bool includeSymbols;
  final bool avoidAmbiguous;

  const EntryPasswordGeneratorOptions({
    this.length = EntryPasswordGenerator.defaultLength,
    this.includeUppercase = true,
    this.includeLowercase = true,
    this.includeNumbers = true,
    this.includeSymbols = true,
    this.avoidAmbiguous = true,
  });

  EntryPasswordGeneratorOptions copyWith({
    int? length,
    bool? includeUppercase,
    bool? includeLowercase,
    bool? includeNumbers,
    bool? includeSymbols,
    bool? avoidAmbiguous,
  }) {
    return EntryPasswordGeneratorOptions(
      length: length ?? this.length,
      includeUppercase: includeUppercase ?? this.includeUppercase,
      includeLowercase: includeLowercase ?? this.includeLowercase,
      includeNumbers: includeNumbers ?? this.includeNumbers,
      includeSymbols: includeSymbols ?? this.includeSymbols,
      avoidAmbiguous: avoidAmbiguous ?? this.avoidAmbiguous,
    );
  }

  bool get hasAnyGroup =>
      includeUppercase || includeLowercase || includeNumbers || includeSymbols;
}

class EntryPasswordGenerator {
  static const minLength = 12;
  static const defaultLength = 20;
  static const ambiguousCharacters = {'O', '0', 'l', '1', 'I'};

  static const _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _numbers = '0123456789';

  const EntryPasswordGenerator._();

  static String generate(EntryPasswordGeneratorOptions options) {
    final safeLength = options.length < minLength ? minLength : options.length;
    if (!options.hasAnyGroup) {
      throw ArgumentError('Ativa pelo menos um tipo de caracteres.');
    }

    if (!options.avoidAmbiguous) {
      final generator = PasswordGenerator(
        length: safeLength,
        minLowercase: options.includeLowercase ? 1 : 0,
        minUppercase: options.includeUppercase ? 1 : 0,
        minDigits: options.includeNumbers ? 1 : 0,
        minSpecial: options.includeSymbols ? 1 : 0,
        useLowercase: options.includeLowercase,
        useUppercase: options.includeUppercase,
        useDigits: options.includeNumbers,
        useSpecialChars: options.includeSymbols,
        specialChars: MasterPasswordPolicy.specialChars,
        numberOfShuffles: 2,
      );
      return generator.generate();
    }

    return _generateWithoutAmbiguous(options, safeLength);
  }

  static String _generateWithoutAmbiguous(
    EntryPasswordGeneratorOptions options,
    int length,
  ) {
    final groups = <String>[];
    if (options.includeLowercase) groups.add(_withoutAmbiguous(_lowercase));
    if (options.includeUppercase) groups.add(_withoutAmbiguous(_uppercase));
    if (options.includeNumbers) groups.add(_withoutAmbiguous(_numbers));
    if (options.includeSymbols) {
      groups.add(MasterPasswordPolicy.specialChars.join());
    }

    final random = Random.secure();
    final chars = <String>[];
    for (final group in groups) {
      chars.add(group[random.nextInt(group.length)]);
    }

    final allChars = groups.join();
    while (chars.length < length) {
      chars.add(allChars[random.nextInt(allChars.length)]);
    }
    chars.shuffle(random);
    return chars.join();
  }

  static String _withoutAmbiguous(String value) {
    return value
        .split('')
        .where((char) => !ambiguousCharacters.contains(char))
        .join();
  }
}
