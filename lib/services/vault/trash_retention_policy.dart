import '../../utils/time_labels.dart';

enum TrashRetentionOption {
  sevenDays,
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  never,
}

extension TrashRetentionOptionDetails on TrashRetentionOption {
  String get preferenceValue {
    switch (this) {
      case TrashRetentionOption.sevenDays:
        return 'sevenDays';
      case TrashRetentionOption.oneMonth:
        return 'oneMonth';
      case TrashRetentionOption.threeMonths:
        return 'threeMonths';
      case TrashRetentionOption.sixMonths:
        return 'sixMonths';
      case TrashRetentionOption.oneYear:
        return 'oneYear';
      case TrashRetentionOption.never:
        return 'never';
    }
  }

  String get label {
    switch (this) {
      case TrashRetentionOption.sevenDays:
        return '7 dias';
      case TrashRetentionOption.oneMonth:
        return '1 mês';
      case TrashRetentionOption.threeMonths:
        return '3 meses';
      case TrashRetentionOption.sixMonths:
        return '6 meses';
      case TrashRetentionOption.oneYear:
        return '1 ano';
      case TrashRetentionOption.never:
        return 'Nunca';
    }
  }

  Duration? get duration {
    switch (this) {
      case TrashRetentionOption.sevenDays:
        return const Duration(days: 7);
      case TrashRetentionOption.oneMonth:
        return const Duration(days: 30);
      case TrashRetentionOption.threeMonths:
        return const Duration(days: 90);
      case TrashRetentionOption.sixMonths:
        return const Duration(days: 180);
      case TrashRetentionOption.oneYear:
        return const Duration(days: 365);
      case TrashRetentionOption.never:
        return null;
    }
  }
}

TrashRetentionOption trashRetentionOptionFromPreference(String? value) {
  switch (value) {
    case 'sevenDays':
      return TrashRetentionOption.sevenDays;
    case 'threeMonths':
      return TrashRetentionOption.threeMonths;
    case 'sixMonths':
      return TrashRetentionOption.sixMonths;
    case 'oneYear':
      return TrashRetentionOption.oneYear;
    case 'never':
      return TrashRetentionOption.never;
    case 'oneMonth':
    default:
      return TrashRetentionOption.oneMonth;
  }
}

class TrashRetentionPolicy {
  static const defaultOption = TrashRetentionOption.oneMonth;

  const TrashRetentionPolicy._();

  static DateTime? permanentDeletionAt(
    DateTime deletedAt, {
    TrashRetentionOption option = defaultOption,
  }) {
    final duration = option.duration;
    if (duration == null) return null;
    return deletedAt.toUtc().add(duration);
  }

  static bool isExpired(
    DateTime deletedAt, {
    TrashRetentionOption option = defaultOption,
    DateTime? now,
  }) {
    final permanentAt = permanentDeletionAt(deletedAt, option: option);
    if (permanentAt == null) return false;
    final reference = (now ?? DateTime.now()).toUtc();
    return !reference.isBefore(permanentAt);
  }

  static String remainingText(
    DateTime deletedAt, {
    TrashRetentionOption option = defaultOption,
  }) {
    final permanentAt = permanentDeletionAt(deletedAt, option: option);
    if (permanentAt == null) return 'Nunca';
    return formatRemaining(permanentAt);
  }

  static String noticeText(TrashRetentionOption option) {
    if (option == TrashRetentionOption.never) {
      return 'As entradas no Lixo não são eliminadas automaticamente.';
    }
    return 'As entradas no Lixo são eliminadas permanentemente após ${option.label}.';
  }

  static String documentNoticeText(TrashRetentionOption option) {
    if (option == TrashRetentionOption.never) {
      return 'Os documentos no Lixo não são eliminados automaticamente.';
    }
    return 'Os documentos no Lixo são eliminados permanentemente após ${option.label}.';
  }
}
