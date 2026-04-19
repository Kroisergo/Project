import 'package:flutter_test/flutter_test.dart';
import 'package:password_strength_checker/password_strength_checker.dart';

import 'package:encryvault/models/vault_data.dart';
import 'package:encryvault/models/vault_entry.dart';
import 'package:encryvault/services/security/master_password_policy.dart';
import 'package:encryvault/services/vault/vault_sort_controller.dart';

void main() {
  group('VaultEntry trash fields', () {
    test('keeps old JSON compatible when deletedAt is missing', () {
      final entry = VaultEntry.fromJson({
        'id': '1',
        'title': 'Email',
        'username': 'user',
        'password': 'secret',
        'notes': '',
        'tags': ['mail'],
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-02T00:00:00.000Z',
      });

      expect(entry.isDeleted, isFalse);
      expect(entry.deletedAt, isNull);
      expect(entry.toJson().containsKey('deletedAt'), isFalse);
    });

    test('separates active and deleted entries', () {
      final now = DateTime.utc(2026, 1, 1);
      final active = VaultEntry(
        id: 'active',
        title: 'Active',
        username: '',
        password: '',
        notes: '',
        tags: const [],
        createdAt: now,
        updatedAt: now,
      );
      final deleted = active.copyWith(
        title: 'Deleted',
        deletedAt: now.add(const Duration(days: 1)),
      );
      final data = VaultData(
        version: 1,
        updatedAt: now,
        entries: [active, deleted],
      );

      expect(data.activeEntries, [active]);
      expect(data.deletedEntries, [deleted]);
      expect(deleted.toJson()['deletedAt'], isNotNull);
    });
  });

  group('PasswordGenerator', () {
    test('generates passwords with length 12 or greater', () {
      const generator = PasswordGenerator(
        length: 20,
        minLowercase: 4,
        minUppercase: 4,
        minDigits: 4,
        minSpecial: 4,
        specialChars: MasterPasswordPolicy.specialChars,
        numberOfShuffles: 2,
      );

      final password = generator.generate();

      expect(password.length, greaterThanOrEqualTo(12));
      expect(RegExp(r'[a-z]').hasMatch(password), isTrue);
      expect(RegExp(r'[A-Z]').hasMatch(password), isTrue);
      expect(RegExp(r'[0-9]').hasMatch(password), isTrue);
      expect(RegExp(r'[^A-Za-z0-9]').hasMatch(password), isTrue);
    });
  });

  group('Vault filters visibility', () {
    test('only shows filters when there are active entries', () {
      final now = DateTime.utc(2026, 1, 1);
      final entry = VaultEntry(
        id: '1',
        title: 'Site',
        username: '',
        password: '',
        notes: '',
        tags: const [],
        createdAt: now,
        updatedAt: now,
      );

      expect(shouldShowVaultFilters([]), isFalse);
      expect(shouldShowVaultFilters([entry]), isTrue);
    });
  });
}
