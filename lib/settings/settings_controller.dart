import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/providers.dart';
import '../ui/nav_catalog.dart';

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.accent,
    required this.pureBlack,
    required this.wallpaperColors,
    required this.speed,
    required this.skipBackSeconds,
    required this.skipForwardSeconds,
    required this.podcastColumns,
    required this.podcastList,
    required this.navOrder,
    required this.enqueueDownloads,
    required this.dequeueDeletedDownloads,
    required this.downloadDirectory,
  });

  final ThemeMode themeMode;
  final AppAccent accent;
  final bool pureBlack;
  final bool wallpaperColors;
  final double speed;
  final int skipBackSeconds;
  final int skipForwardSeconds;
  final int podcastColumns;
  final bool podcastList;
  final List<String> navOrder;
  final bool enqueueDownloads;
  final bool dequeueDeletedDownloads;
  final String? downloadDirectory;

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppAccent? accent,
    bool? pureBlack,
    bool? wallpaperColors,
    double? speed,
    int? skipBackSeconds,
    int? skipForwardSeconds,
    int? podcastColumns,
    bool? podcastList,
    List<String>? navOrder,
    bool? enqueueDownloads,
    bool? dequeueDeletedDownloads,
    String? downloadDirectory,
    bool clearDownloadDirectory = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
      pureBlack: pureBlack ?? this.pureBlack,
      wallpaperColors: wallpaperColors ?? this.wallpaperColors,
      speed: speed ?? this.speed,
      skipBackSeconds: skipBackSeconds ?? this.skipBackSeconds,
      skipForwardSeconds: skipForwardSeconds ?? this.skipForwardSeconds,
      podcastColumns: podcastColumns ?? this.podcastColumns,
      podcastList: podcastList ?? this.podcastList,
      navOrder: navOrder ?? this.navOrder,
      enqueueDownloads: enqueueDownloads ?? this.enqueueDownloads,
      dequeueDeletedDownloads:
          dequeueDeletedDownloads ?? this.dequeueDeletedDownloads,
      downloadDirectory: clearDownloadDirectory
          ? null
          : (downloadDirectory ?? this.downloadDirectory),
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    final themeName = preferences.getString('theme') ?? ThemeMode.system.name;
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[themeName] ?? ThemeMode.system,
      accent: AppAccent.byId(preferences.getString('accent')),
      pureBlack: preferences.getBool('pureBlack') ?? false,
      wallpaperColors: preferences.getBool('wallpaperColors') ?? false,
      speed: preferences.getDouble('speed') ?? 1,
      skipBackSeconds: preferences.getInt('skipBack') ?? 10,
      skipForwardSeconds: preferences.getInt('skipForward') ?? 30,
      podcastColumns: _columns(preferences.getInt('podcastColumns')),
      podcastList: preferences.getBool('podcastList') ?? false,
      navOrder: normalizeNavOrder(preferences.getStringList('navOrder')),
      enqueueDownloads: preferences.getBool('enqueueDownloads') ?? true,
      dequeueDeletedDownloads:
          preferences.getBool('dequeueDeletedDownloads') ?? true,
      downloadDirectory: preferences.getString('downloadDirectory'),
    );
  }

  static int _columns(int? stored) {
    if (stored == null || stored < 1 || stored > 6) return 3;
    return stored;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString('theme', mode.name);
  }

  Future<void> setAccent(AppAccent accent) async {
    state = state.copyWith(accent: accent);
    await ref.read(sharedPreferencesProvider).setString('accent', accent.id);
  }

  Future<void> setPureBlack(bool enabled) async {
    state = state.copyWith(pureBlack: enabled);
    await ref.read(sharedPreferencesProvider).setBool('pureBlack', enabled);
  }

  Future<void> setWallpaperColors(bool enabled) async {
    state = state.copyWith(wallpaperColors: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('wallpaperColors', enabled);
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(speed: speed);
    await ref.read(sharedPreferencesProvider).setDouble('speed', speed);
  }

  Future<void> setSkipBack(int seconds) async {
    state = state.copyWith(skipBackSeconds: seconds);
    await ref.read(sharedPreferencesProvider).setInt('skipBack', seconds);
  }

  Future<void> setSkipForward(int seconds) async {
    state = state.copyWith(skipForwardSeconds: seconds);
    await ref.read(sharedPreferencesProvider).setInt('skipForward', seconds);
  }

  Future<void> setDownloadDirectory(String? directory) async {
    final preferences = ref.read(sharedPreferencesProvider);
    if (directory == null || directory.isEmpty) {
      state = state.copyWith(clearDownloadDirectory: true);
      await preferences.remove('downloadDirectory');
      return;
    }
    state = state.copyWith(downloadDirectory: directory);
    await preferences.setString('downloadDirectory', directory);
  }

  Future<void> setDequeueDeletedDownloads(bool enabled) async {
    state = state.copyWith(dequeueDeletedDownloads: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('dequeueDeletedDownloads', enabled);
  }

  Future<void> setEnqueueDownloads(bool enabled) async {
    state = state.copyWith(enqueueDownloads: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('enqueueDownloads', enabled);
  }

  Future<void> setPodcastLayout({required bool list, int? columns}) async {
    final preferences = ref.read(sharedPreferencesProvider);
    if (list) {
      state = state.copyWith(podcastList: true);
      await preferences.setBool('podcastList', true);
      return;
    }
    final stored = (columns ?? state.podcastColumns).clamp(1, 6);
    state = state.copyWith(podcastList: false, podcastColumns: stored);
    await preferences.setBool('podcastList', false);
    await preferences.setInt('podcastColumns', stored);
  }

  Future<void> setNavOrder(List<String> order) async {
    final normalized = normalizeNavOrder(order);
    state = state.copyWith(navOrder: normalized);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList('navOrder', normalized);
  }
}
