import 'package:flutter_test/flutter_test.dart';
import 'package:password_strength_checker/password_strength_checker.dart';

import 'package:encryvault/models/vault_data.dart';
import 'package:encryvault/models/vault_entry.dart';
import 'package:encryvault/models/vault_sort_mode.dart';
import 'package:encryvault/services/security/entry_password_generator.dart';
import 'package:encryvault/services/security/master_password_policy.dart';
import 'package:encryvault/services/security/password_feedback_service.dart';
import 'package:encryvault/services/security/password_entry_recommendation.dart';
import 'package:encryvault/services/security/password_health_service.dart';
import 'package:encryvault/services/vault/trash_retention_policy.dart';
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
      expect(entry.passwordUpdatedAt, DateTime.utc(2026, 1, 2));
      expect(entry.lastOpenedAt, DateTime.utc(2026, 1, 2));
      expect(entry.openCount, 0);
      expect(entry.passwordHistory, hasLength(1));
      expect(entry.passwordHistory.first.password, 'secret');
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
        passwordUpdatedAt: now,
        lastOpenedAt: now,
        passwordHistory: const [],
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

    test(
      'entry generator respects minimum length and avoids ambiguous chars',
      () {
        final password = EntryPasswordGenerator.generate(
          const EntryPasswordGeneratorOptions(length: 8),
        );

        expect(password.length, 12);
        for (final char in EntryPasswordGenerator.ambiguousCharacters) {
          expect(password.contains(char), isFalse);
        }
        expect(RegExp(r'[a-z]').hasMatch(password), isTrue);
        expect(RegExp(r'[A-Z]').hasMatch(password), isTrue);
        expect(RegExp(r'[0-9]').hasMatch(password), isTrue);
        expect(RegExp(r'[^A-Za-z0-9]').hasMatch(password), isTrue);
      },
    );
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
        passwordUpdatedAt: now,
        lastOpenedAt: now,
        passwordHistory: const [],
      );
      final deletedEntry = entry.copyWith(
        deletedAt: now.add(const Duration(days: 1)),
      );

      expect(shouldShowVaultFilters([]), isFalse);
      expect(shouldShowVaultFilters([deletedEntry]), isFalse);
      expect(shouldShowVaultFilters([entry]), isTrue);
    });
  });

  group('Entry password recommendation', () {
    test('uses shorter change interval for weak passwords', () {
      final updatedAt = DateTime.utc(2026, 1, 1);
      final result = PasswordEntryRecommendationService.evaluate(
        password: 'weak',
        passwordUpdatedAt: updatedAt,
      );

      expect(result.changeAfter, const Duration(days: 30));
      expect(result.dueAt, DateTime.utc(2026, 1, 31));
    });

    test('uses longer change interval for strong passwords', () {
      final updatedAt = DateTime.utc(2026, 1, 1);
      final result = PasswordEntryRecommendationService.evaluate(
        password: 'LongPassword12!',
        passwordUpdatedAt: updatedAt,
      );

      expect(result.changeAfter, const Duration(days: 180));
      expect(result.dueAt, DateTime.utc(2026, 6, 30));
    });
  });

  group('Password health', () {
    test('counts weak and reused passwords without deleted entries', () {
      final now = DateTime.utc(2026, 1, 1);
      final weakA = _entry(
        id: '1',
        password: 'weak',
        updatedAt: now.subtract(const Duration(days: 40)),
      );
      final weakB = _entry(
        id: '2',
        password: 'weak',
        updatedAt: now.subtract(const Duration(days: 40)),
      );
      final deleted = _entry(
        id: '3',
        password: 'weak',
        updatedAt: now,
        deletedAt: now,
      );

      final report = PasswordHealthService.analyze([
        weakA,
        weakB,
        deleted,
      ], now: now);

      expect(report.total, 2);
      expect(report.weak, 2);
      expect(report.reused, 2);
      expect(report.reusedGroups, 1);
    });

    test('counts never opened, rarely used, large history and old trash', () {
      final now = DateTime.utc(2026, 2, 1);
      final neverOpened = _entry(
        id: 'never',
        password: 'StrongPassword12!',
        updatedAt: now,
        openCount: 0,
      );
      final largeHistory = _entry(
        id: 'history',
        password: 'StrongPassword34!',
        updatedAt: now,
        openCount: 2,
        historyLength: 5,
      );
      final oldTrash = _entry(
        id: 'trash',
        password: 'StrongPassword56!',
        updatedAt: now,
        deletedAt: now.subtract(const Duration(days: 31)),
      );

      final report = PasswordHealthService.analyze(
        [neverOpened, largeHistory, oldTrash],
        now: now,
        trashRetention: TrashRetentionOption.never,
      );

      expect(report.neverOpened, 1);
      expect(report.rarelyUsed, 1);
      expect(report.largeHistory, 1);
      expect(report.oldTrash, 1);
    });

    test('returns concrete feedback messages', () {
      final messages = PasswordFeedbackService.messages(
        password: 'password123',
        isReused: true,
      );

      expect(messages, contains('Sem letras maiusculas.'));
      expect(messages, contains('Sem simbolos.'));
      expect(messages, contains('Parece reutilizada noutra entrada.'));
    });
  });

  group('Trash retention policy', () {
    test('expires deleted entries with the default one month policy', () {
      final deletedAt = DateTime.utc(2026, 1, 1);

      expect(
        TrashRetentionPolicy.permanentDeletionAt(
          deletedAt,
          option: TrashRetentionOption.oneMonth,
        ),
        DateTime.utc(2026, 1, 31),
      );
      expect(
        TrashRetentionPolicy.isExpired(
          deletedAt,
          option: TrashRetentionOption.oneMonth,
          now: DateTime.utc(2026, 1, 30, 23, 59),
        ),
        isFalse,
      );
      expect(
        TrashRetentionPolicy.isExpired(
          deletedAt,
          option: TrashRetentionOption.oneMonth,
          now: DateTime.utc(2026, 1, 31),
        ),
        isTrue,
      );
    });

    test('never policy does not expire deleted entries', () {
      final deletedAt = DateTime.utc(2026, 1, 1);

      expect(
        TrashRetentionPolicy.permanentDeletionAt(
          deletedAt,
          option: TrashRetentionOption.never,
        ),
        isNull,
      );
      expect(
        TrashRetentionPolicy.isExpired(
          deletedAt,
          option: TrashRetentionOption.never,
          now: DateTime.utc(2027, 1, 1),
        ),
        isFalse,
      );
    });
  });

  group('Vault sorting', () {
    test('sorts by recently opened and usage count', () {
      final now = DateTime.utc(2026, 1, 10);
      final lowUse = _entry(
        id: 'low',
        password: 'a',
        updatedAt: now,
        lastOpenedAt: now.subtract(const Duration(days: 1)),
        openCount: 1,
      );
      final highUse = _entry(
        id: 'high',
        password: 'b',
        updatedAt: now,
        lastOpenedAt: now,
        openCount: 3,
      );

      expect(
        filterAndSortEntries(
          entries: [lowUse, highUse],
          query: '',
          selectedTags: const {},
          sortMode: VaultSortMode.recentlyOpened,
        ).map((entry) => entry.id),
        ['high', 'low'],
      );
      expect(
        filterAndSortEntries(
          entries: [lowUse, highUse],
          query: '',
          selectedTags: const {},
          sortMode: VaultSortMode.mostUsed,
        ).map((entry) => entry.id),
        ['high', 'low'],
      );
      expect(
        filterAndSortEntries(
          entries: [lowUse, highUse],
          query: '',
          selectedTags: const {},
          sortMode: VaultSortMode.leastUsed,
        ).map((entry) => entry.id),
        ['low', 'high'],
      );
    });
  });
}

VaultEntry _entry({
  required String id,
  required String password,
  required DateTime updatedAt,
  DateTime? lastOpenedAt,
  int openCount = 0,
  DateTime? deletedAt,
  int historyLength = 1,
}) {
  final history = List.generate(historyLength, (index) {
    final isCurrent = index == historyLength - 1;
    return VaultPasswordHistoryItem(
      password: isCurrent ? password : '$password-$index',
      changedAt: updatedAt.subtract(Duration(days: historyLength - index - 1)),
    );
  });
  return VaultEntry(
    id: id,
    title: id,
    username: '',
    password: password,
    notes: '',
    tags: const [],
    createdAt: updatedAt,
    updatedAt: updatedAt,
    passwordUpdatedAt: updatedAt,
    lastOpenedAt: lastOpenedAt ?? updatedAt,
    openCount: openCount,
    passwordHistory: history,
    deletedAt: deletedAt,
  );
}
