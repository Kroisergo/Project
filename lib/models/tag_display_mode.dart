enum TagDisplayMode { all, custom, hidden }

extension TagDisplayModeDetails on TagDisplayMode {
  String get preferenceValue {
    switch (this) {
      case TagDisplayMode.all:
        return 'all';
      case TagDisplayMode.custom:
        return 'custom';
      case TagDisplayMode.hidden:
        return 'hidden';
    }
  }

  String get label {
    switch (this) {
      case TagDisplayMode.all:
        return 'Atual';
      case TagDisplayMode.custom:
        return 'Personalizado';
      case TagDisplayMode.hidden:
        return 'Sem área de etiquetas';
    }
  }

  String get description {
    switch (this) {
      case TagDisplayMode.all:
        return 'Mostra todas as etiquetas no início da Home.';
      case TagDisplayMode.custom:
        return 'Mostra apenas as etiquetas escolhidas.';
      case TagDisplayMode.hidden:
        return 'Oculta a área de etiquetas da Home.';
    }
  }
}

TagDisplayMode tagDisplayModeFromPreference(String? value) {
  switch (value) {
    case 'custom':
      return TagDisplayMode.custom;
    case 'hidden':
      return TagDisplayMode.hidden;
    case 'all':
    default:
      return TagDisplayMode.all;
  }
}

String tagDisplayPreferenceKey(String tag) {
  final normalized = tag.trim().toLowerCase();
  const offset = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  const mask = 0xffffffffffffffff;
  var hash = offset;
  for (final unit in normalized.codeUnits) {
    hash ^= unit;
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
