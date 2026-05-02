import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tag_display_mode.dart';
import '../storage/preferences_service.dart';

class TagDisplaySettings {
  final TagDisplayMode mode;
  final Set<String> exposedTagKeys;

  const TagDisplaySettings({
    this.mode = TagDisplayMode.all,
    this.exposedTagKeys = const {},
  });

  bool isTagExposed(String tag) {
    return exposedTagKeys.contains(tagDisplayPreferenceKey(tag));
  }

  TagDisplaySettings copyWith({
    TagDisplayMode? mode,
    Set<String>? exposedTagKeys,
  }) {
    return TagDisplaySettings(
      mode: mode ?? this.mode,
      exposedTagKeys: exposedTagKeys ?? this.exposedTagKeys,
    );
  }
}

class TagDisplayController extends AsyncNotifier<TagDisplaySettings> {
  @override
  Future<TagDisplaySettings> build() async {
    final prefs = ref.read(preferencesServiceProvider);
    return TagDisplaySettings(
      mode: await prefs.getTagDisplayMode(),
      exposedTagKeys: (await prefs.getExposedHomeTagKeys()).toSet(),
    );
  }

  Future<void> setMode(TagDisplayMode mode) async {
    final current = state.valueOrNull ?? const TagDisplaySettings();
    if (current.mode == mode) return;
    final next = current.copyWith(mode: mode);
    state = AsyncData(next);
    await ref.read(preferencesServiceProvider).setTagDisplayMode(mode);
  }

  Future<void> setTagExposed(String tag, bool exposed) async {
    final current = state.valueOrNull ?? const TagDisplaySettings();
    final keys = {...current.exposedTagKeys};
    final key = tagDisplayPreferenceKey(tag);
    if (exposed) {
      keys.add(key);
    } else {
      keys.remove(key);
    }
    final next = current.copyWith(exposedTagKeys: keys);
    state = AsyncData(next);
    await ref.read(preferencesServiceProvider).setExposedHomeTagKeys(keys);
  }
}

final tagDisplayControllerProvider =
    AsyncNotifierProvider<TagDisplayController, TagDisplaySettings>(
      TagDisplayController.new,
    );
