enum QuickLinkIcon {
  social,
  email,
  bank,
  shopping,
  work,
  games,
  cloud,
  code,
  media,
  key,
  other,
}

extension QuickLinkIconDetails on QuickLinkIcon {
  String get label {
    switch (this) {
      case QuickLinkIcon.social:
        return 'Social';
      case QuickLinkIcon.email:
        return 'Email';
      case QuickLinkIcon.bank:
        return 'Banco';
      case QuickLinkIcon.shopping:
        return 'Compras';
      case QuickLinkIcon.work:
        return 'Trabalho';
      case QuickLinkIcon.games:
        return 'Jogos';
      case QuickLinkIcon.cloud:
        return 'Nuvem';
      case QuickLinkIcon.code:
        return 'Código';
      case QuickLinkIcon.media:
        return 'Media';
      case QuickLinkIcon.key:
        return 'Palavra-passe';
      case QuickLinkIcon.other:
        return 'Outro';
    }
  }

  String get preferenceValue => name;
}

QuickLinkIcon quickLinkIconFromPreference(String? value) {
  for (final icon in QuickLinkIcon.values) {
    if (icon.preferenceValue == value) return icon;
  }
  return QuickLinkIcon.other;
}

class QuickLinkPreset {
  final String label;
  final String url;
  final QuickLinkIcon icon;

  const QuickLinkPreset({
    required this.label,
    required this.url,
    required this.icon,
  });

  String get normalizedUrl => normalizeQuickLinkUrl(url);

  Map<String, Object?> toJson() {
    return {
      'label': label.trim(),
      'url': normalizedUrl,
      'icon': icon.preferenceValue,
    };
  }

  static QuickLinkPreset? fromJson(Object? value) {
    if (value is! Map) return null;
    final label = '${value['label'] ?? ''}'.trim();
    final url = normalizeQuickLinkUrl('${value['url'] ?? ''}');
    if (label.isEmpty || url.isEmpty) return null;
    return QuickLinkPreset(
      label: label,
      url: url,
      icon: quickLinkIconFromPreference(value['icon']?.toString()),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is QuickLinkPreset &&
        other.label == label &&
        other.url == url &&
        other.icon == icon;
  }

  @override
  int get hashCode => Object.hash(label, url, icon);
}

String normalizeQuickLinkUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.contains('://')) return value;
  return 'https://$value';
}

const quickLinkPreviewLimit = 2;

const defaultQuickLinkPresets = [
  QuickLinkPreset(
    label: 'Instagram',
    url: 'https://www.instagram.com/',
    icon: QuickLinkIcon.social,
  ),
  QuickLinkPreset(
    label: 'Facebook',
    url: 'https://www.facebook.com/',
    icon: QuickLinkIcon.social,
  ),
  QuickLinkPreset(
    label: 'X / Twitter',
    url: 'https://twitter.com/',
    icon: QuickLinkIcon.social,
  ),
  QuickLinkPreset(
    label: 'Google',
    url: 'https://accounts.google.com/',
    icon: QuickLinkIcon.key,
  ),
  QuickLinkPreset(
    label: 'GitHub',
    url: 'https://github.com/',
    icon: QuickLinkIcon.code,
  ),
  QuickLinkPreset(
    label: 'Amazon',
    url: 'https://www.amazon.com/',
    icon: QuickLinkIcon.shopping,
  ),
  QuickLinkPreset(
    label: 'Microsoft',
    url: 'https://login.live.com/',
    icon: QuickLinkIcon.work,
  ),
  QuickLinkPreset(
    label: 'Apple ID',
    url: 'https://appleid.apple.com/',
    icon: QuickLinkIcon.key,
  ),
  QuickLinkPreset(
    label: 'PayPal',
    url: 'https://www.paypal.com/',
    icon: QuickLinkIcon.bank,
  ),
  QuickLinkPreset(
    label: 'Proton',
    url: 'https://account.proton.me/',
    icon: QuickLinkIcon.email,
  ),
  QuickLinkPreset(
    label: 'LinkedIn',
    url: 'https://www.linkedin.com/',
    icon: QuickLinkIcon.work,
  ),
  QuickLinkPreset(
    label: 'Discord',
    url: 'https://discord.com/',
    icon: QuickLinkIcon.social,
  ),
  QuickLinkPreset(
    label: 'Steam',
    url: 'https://store.steampowered.com/',
    icon: QuickLinkIcon.games,
  ),
];

List<QuickLinkPreset> effectiveQuickLinkPresets(
  Iterable<QuickLinkPreset> custom,
) {
  final links = <QuickLinkPreset>[];
  final seenUrls = <String>{};

  void add(QuickLinkPreset preset) {
    final label = preset.label.trim();
    final url = preset.normalizedUrl;
    if (label.isEmpty || url.isEmpty) return;
    final key = url.toLowerCase();
    if (!seenUrls.add(key)) return;
    links.add(QuickLinkPreset(label: label, url: url, icon: preset.icon));
  }

  for (final preset in defaultQuickLinkPresets) {
    add(preset);
  }
  for (final preset in custom) {
    add(preset);
  }
  return links;
}

List<QuickLinkPreset> previewQuickLinkPresets(List<QuickLinkPreset> links) {
  return links.take(quickLinkPreviewLimit).toList();
}

List<QuickLinkPreset> remainingQuickLinkPresets(List<QuickLinkPreset> links) {
  return links.skip(quickLinkPreviewLimit).toList();
}
