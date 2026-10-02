import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/providers.dart';
import '../ui/nav_catalog.dart';

/// Compteur affiché sur les jaquettes de la page Abonnements.
enum PodcastCounter {
  unread('unread', 'Épisodes non lus'),
  downloaded('downloaded', 'Épisodes téléchargés'),
  downloadedUnread('downloadedUnread', 'Téléchargés et non lus'),
  queue('queue', 'Playlist'),
  none('none', 'Aucun compteur');

  const PodcastCounter(this.id, this.label);

  final String id;
  final String label;

  static PodcastCounter byId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return PodcastCounter.none;
  }
}

/// Filtres de la page Abonnements (multi-sélection).
class PodcastFilters {
  const PodcastFilters({
    this.counterAboveZero = false,
    this.autoDownload,
    this.keepUpdated,
  });

  static const empty = PodcastFilters();

  /// Compteur (réglage Compteur) supérieur à zéro.
  final bool counterAboveZero;

  /// `true` = avec téléchargements auto, `false` = sans, `null` = indifférent.
  final bool? autoDownload;

  /// `true` = maintenu à jour, `false` = non maintenu, `null` = indifférent.
  final bool? keepUpdated;

  bool get isEmpty =>
      !counterAboveZero && autoDownload == null && keepUpdated == null;

  List<String> toIds() {
    return [
      if (counterAboveZero) 'counterAboveZero',
      if (autoDownload == true) 'withAutoDownload',
      if (autoDownload == false) 'withoutAutoDownload',
      if (keepUpdated == true) 'keepUpdated',
      if (keepUpdated == false) 'notKeepUpdated',
    ];
  }

  static PodcastFilters fromIds(List<String>? ids) {
    if (ids == null || ids.isEmpty) return empty;
    final set = ids.toSet();
    bool? autoDownload;
    if (set.contains('withAutoDownload')) {
      autoDownload = true;
    } else if (set.contains('withoutAutoDownload')) {
      autoDownload = false;
    }
    bool? keepUpdated;
    if (set.contains('keepUpdated')) {
      keepUpdated = true;
    } else if (set.contains('notKeepUpdated')) {
      keepUpdated = false;
    }
    return PodcastFilters(
      counterAboveZero: set.contains('counterAboveZero'),
      autoDownload: autoDownload,
      keepUpdated: keepUpdated,
    );
  }

  PodcastFilters copyWith({
    bool? counterAboveZero,
    bool? autoDownload,
    bool clearAutoDownload = false,
    bool? keepUpdated,
    bool clearKeepUpdated = false,
  }) {
    return PodcastFilters(
      counterAboveZero: counterAboveZero ?? this.counterAboveZero,
      autoDownload: clearAutoDownload
          ? null
          : (autoDownload ?? this.autoDownload),
      keepUpdated: clearKeepUpdated
          ? null
          : (keepUpdated ?? this.keepUpdated),
    );
  }
}

/// Tri de la page Abonnements.
enum PodcastSort {
  published('published', 'Date de publication'),
  alphabetical('alphabetical', 'Ordre alphabétique'),
  counter('counter', 'Compteur'),
  played('played', 'Nombre lus');

  const PodcastSort(this.id, this.label);

  final String id;
  final String label;

  static PodcastSort byId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return PodcastSort.published;
  }
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.accent,
    required this.pureBlack,
    required this.wallpaperColors,
    required this.speed,
    required this.volume,
    required this.skipBackSeconds,
    required this.skipForwardSeconds,
    required this.showRemainingTime,
    required this.keepScreenOn,
    required this.podcastColumns,
    required this.podcastList,
    required this.podcastShowNames,
    required this.podcastCounter,
    required this.podcastSort,
    required this.podcastFilters,
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
  final double volume;
  final int skipBackSeconds;
  final int skipForwardSeconds;
  final bool showRemainingTime;
  final bool keepScreenOn;
  final int podcastColumns;
  final bool podcastList;
  final bool podcastShowNames;
  final PodcastCounter podcastCounter;
  final PodcastSort podcastSort;
  final PodcastFilters podcastFilters;
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
    double? volume,
    int? skipBackSeconds,
    int? skipForwardSeconds,
    bool? showRemainingTime,
    bool? keepScreenOn,
    int? podcastColumns,
    bool? podcastList,
    bool? podcastShowNames,
    PodcastCounter? podcastCounter,
    PodcastSort? podcastSort,
    PodcastFilters? podcastFilters,
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
      volume: volume ?? this.volume,
      skipBackSeconds: skipBackSeconds ?? this.skipBackSeconds,
      skipForwardSeconds: skipForwardSeconds ?? this.skipForwardSeconds,
      showRemainingTime: showRemainingTime ?? this.showRemainingTime,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      podcastColumns: podcastColumns ?? this.podcastColumns,
      podcastList: podcastList ?? this.podcastList,
      podcastShowNames: podcastShowNames ?? this.podcastShowNames,
      podcastCounter: podcastCounter ?? this.podcastCounter,
      podcastSort: podcastSort ?? this.podcastSort,
      podcastFilters: podcastFilters ?? this.podcastFilters,
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
      volume: _volume(preferences.getDouble('volume')),
      skipBackSeconds: preferences.getInt('skipBack') ?? 10,
      skipForwardSeconds: preferences.getInt('skipForward') ?? 30,
      showRemainingTime: preferences.getBool('showRemainingTime') ?? false,
      keepScreenOn: preferences.getBool('keepScreenOn') ?? false,
      podcastColumns: _columns(preferences.getInt('podcastColumns')),
      podcastList: preferences.getBool('podcastList') ?? false,
      podcastShowNames: preferences.getBool('podcastShowNames') ?? true,
      podcastCounter: PodcastCounter.byId(
        preferences.getString('podcastCounter'),
      ),
      podcastSort: PodcastSort.byId(preferences.getString('podcastSort')),
      podcastFilters: PodcastFilters.fromIds(
        preferences.getStringList('podcastFilters'),
      ),
      navOrder: normalizeNavOrder(preferences.getStringList('navOrder')),
      enqueueDownloads: preferences.getBool('enqueueDownloads') ?? true,
      dequeueDeletedDownloads:
          preferences.getBool('dequeueDeletedDownloads') ?? true,
      downloadDirectory: preferences.getString('downloadDirectory'),
    );
  }

  static int _columns(int? stored) {
    if (stored == null || stored < 1 || stored > 8) return 3;
    return stored;
  }

  static double _volume(double? stored) {
    if (stored == null) return 1;
    return stored.clamp(0.0, 1.0);
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

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    await ref.read(sharedPreferencesProvider).setDouble('volume', clamped);
  }

  Future<void> setSkipBack(int seconds) async {
    state = state.copyWith(skipBackSeconds: seconds);
    await ref.read(sharedPreferencesProvider).setInt('skipBack', seconds);
  }

  Future<void> setSkipForward(int seconds) async {
    state = state.copyWith(skipForwardSeconds: seconds);
    await ref.read(sharedPreferencesProvider).setInt('skipForward', seconds);
  }

  Future<void> setShowRemainingTime(bool enabled) async {
    state = state.copyWith(showRemainingTime: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('showRemainingTime', enabled);
  }

  Future<void> setKeepScreenOn(bool enabled) async {
    state = state.copyWith(keepScreenOn: enabled);
    await ref.read(sharedPreferencesProvider).setBool('keepScreenOn', enabled);
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
    final stored = (columns ?? state.podcastColumns).clamp(1, 8);
    state = state.copyWith(podcastList: false, podcastColumns: stored);
    await preferences.setBool('podcastList', false);
    await preferences.setInt('podcastColumns', stored);
  }

  Future<void> setPodcastShowNames(bool enabled) async {
    state = state.copyWith(podcastShowNames: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('podcastShowNames', enabled);
  }

  Future<void> setPodcastCounter(PodcastCounter counter) async {
    state = state.copyWith(podcastCounter: counter);
    await ref
        .read(sharedPreferencesProvider)
        .setString('podcastCounter', counter.id);
  }

  Future<void> setPodcastSort(PodcastSort sort) async {
    state = state.copyWith(podcastSort: sort);
    await ref.read(sharedPreferencesProvider).setString('podcastSort', sort.id);
  }

  Future<void> setPodcastFilters(PodcastFilters filters) async {
    state = state.copyWith(podcastFilters: filters);
    final preferences = ref.read(sharedPreferencesProvider);
    final ids = filters.toIds();
    if (ids.isEmpty) {
      await preferences.remove('podcastFilters');
    } else {
      await preferences.setStringList('podcastFilters', ids);
    }
  }

  Future<void> setNavOrder(List<String> order) async {
    final normalized = normalizeNavOrder(order);
    state = state.copyWith(navOrder: normalized);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList('navOrder', normalized);
  }
}
