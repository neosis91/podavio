import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/skip_segments.dart';

/// Saut automatique et types concernés, pour toute l'application.
class GlobalSkipSettings {
  const GlobalSkipSettings({required this.enabled, required this.kinds});

  final bool enabled;
  final List<SkipSegmentKind> kinds;

  static const enabledKey = 'globalAutoSkipAds';
  static const kindsKey = 'globalAutoSkipKinds';
}

final globalSkipSettingsProvider =
    NotifierProvider<GlobalSkipController, GlobalSkipSettings>(
      GlobalSkipController.new,
    );

class GlobalSkipController extends Notifier<GlobalSkipSettings> {
  @override
  GlobalSkipSettings build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return GlobalSkipSettings(
      enabled: preferences.getBool(GlobalSkipSettings.enabledKey) ?? false,
      kinds: decodeAutoSkipKinds(
        preferences.getString(GlobalSkipSettings.kindsKey) ?? '[]',
      ),
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final preferences = ref.read(sharedPreferencesProvider);
    var kinds = state.kinds;
    if (enabled && kinds.isEmpty) {
      kinds = const [SkipSegmentKind.ad, SkipSegmentKind.sponsor];
      await preferences.setString(
        GlobalSkipSettings.kindsKey,
        encodeAutoSkipKinds(kinds),
      );
    }
    state = GlobalSkipSettings(enabled: enabled, kinds: kinds);
    await preferences.setBool(GlobalSkipSettings.enabledKey, enabled);
  }

  Future<void> setKind(SkipSegmentKind kind, {required bool enabled}) {
    return setKinds([kind], enabled: enabled);
  }

  /// Active ou retire plusieurs types d’un coup. La pub et le sponsor
  /// passent ensemble : l’écran n’en montre qu’un.
  Future<void> setKinds(
    Iterable<SkipSegmentKind> kinds, {
    required bool enabled,
  }) async {
    final selected = state.kinds.toSet();
    if (enabled) {
      selected.addAll(kinds);
    } else {
      selected.removeAll(kinds);
    }
    final next = [
      for (final value in SkipSegmentKind.values)
        if (selected.contains(value)) value,
    ];
    state = GlobalSkipSettings(enabled: state.enabled, kinds: next);
    await ref
        .read(sharedPreferencesProvider)
        .setString(GlobalSkipSettings.kindsKey, encodeAutoSkipKinds(next));
  }
}
