import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../data/discover_languages.dart';
import '../data/download_policy.dart';
import '../data/providers.dart';
import '../l10n/interface_locale.dart';
import '../ui/nav_catalog.dart';
import 'episode_filters.dart';
import 'episode_list_density.dart';
import 'home_categories.dart';
import 'home_shelves.dart';
import 'mini_player_buttons.dart';
import 'outside_app_control.dart';
import 'podcast_list_settings.dart';

export '../data/download_policy.dart'
    show automaticDownloadLimits, podcastAutoDownloadLimit;
export '../data/download_policy.dart' show EpisodeCacheCleanup;
export 'episode_filters.dart';
export 'episode_list_density.dart';
export 'home_categories.dart';
export 'home_shelves.dart';
export 'mini_player_buttons.dart';
export 'outside_app_control.dart';
export 'podcast_list_settings.dart';

/// Tailles proposées pour le cache d’épisodes. Une valeur absente est illimitée.
const episodeCacheSizes = <int>[5, 10, 20, 50, 100, 200, 500, 1000];

/// `null`, zéro ou une taille inconnue → illimité.
int? episodeCacheSizeFromStored(int? stored) {
  if (stored == null || !episodeCacheSizes.contains(stored)) return null;
  return stored;
}

/// Clé anglaise de la taille affichée. `null` = illimité.
String episodeCacheSizeLabel(int? size) {
  if (size == null) return 'Unlimited';
  return '$size episodes';
}

/// `null` ou une valeur inconnue → illimité.
int? automaticDownloadLimitFromStored(int? stored) {
  if (stored == null || !automaticDownloadLimits.contains(stored)) return null;
  return stored;
}

/// Clé anglaise du plafond affiché. `null` = illimité.
String automaticDownloadLimitLabel(int? limit) {
  if (limit == null) return 'Unlimited';
  if (limit == 1) return '1 episode';
  return '$limit episodes';
}

/// Nombre de téléchargements en même temps. Défaut : 2.
const simultaneousDownloadChoices = <int>[1, 2, 3, 4, 5];

int simultaneousDownloadsFromStored(int? stored) {
  if (stored == null || !simultaneousDownloadChoices.contains(stored)) {
    return 2;
  }
  return stored;
}

/// Clé anglaise du nombre affiché.
String simultaneousDownloadsLabel(int count) {
  return switch (count) {
    1 => '1 at a time',
    2 => '2 at a time',
    3 => '3 at a time',
    4 => '4 at a time',
    _ => '5 at a time',
  };
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.accent,
    required this.pureBlack,
    required this.ecoMode,
    required this.onboardingComplete,
    required this.wallpaperColors,
    required this.tintFromCover,
    required this.homeShelves,
    required this.homeCategories,
    required this.homeCategoriesChosen,
    required this.speed,
    required this.volume,
    required this.skipBackSeconds,
    required this.skipForwardSeconds,
    required this.outsideApp,
    required this.showRemainingTime,
    required this.timeRespectsSpeed,
    required this.keepScreenOn,
    required this.miniPlayerButtons,
    required this.preferPodcastCover,
    required this.episodeListDensity,
    required this.episodeFilters,
    required this.podcastColumns,
    required this.podcastList,
    required this.podcastShowNames,
    required this.podcastCounter,
    required this.podcastSort,
    required this.podcastFilters,
    required this.navOrder,
    required this.enqueueDownloads,
    required this.dequeueDeletedDownloads,
    required this.automaticDownload,
    required this.automaticDownloadLimit,
    required this.simultaneousDownloads,
    required this.allowMobileData,
    required this.allowMobileStreaming,
    required this.allowMobileRefresh,
    required this.notifyDownloadActivity,
    required this.notifyDownloadErrors,
    required this.notifySyncErrors,
    required this.notifyNewEpisodes,
    required this.episodeCacheSize,
    required this.deleteAfterPlayback,
    required this.episodeCacheCleanup,
    required this.downloadDirectory,
    required this.automaticDatabaseBackup,
    required this.automaticDatabaseBackupFolder,
    required this.refreshIntervalMinutes,
    required this.discoverLanguages,
    required this.discoverLanguagesPicked,
    required this.interfaceLanguage,
  });

  final ThemeMode themeMode;
  final AppAccent accent;
  final bool pureBlack;

  /// Moins de requêtes : pas de nouvelles jaquettes, noir pur à l’activation.
  final bool ecoMode;

  /// L’accueil de première ouverture a été quitté.
  final bool onboardingComplete;

  final bool wallpaperColors;

  /// Le lecteur et le haut de l’accueil prennent la couleur de la pochette.
  final bool tintFromCover;

  /// Ordre et masquage des étagères de l’accueil.
  final HomeShelves homeShelves;

  /// Pastilles de catégories de l’accueil.
  final HomeCategories homeCategories;

  /// Vrai après un choix dans Interface. Sinon l’accueil suit le mois.
  final bool homeCategoriesChosen;

  final double speed;
  final double volume;
  final int skipBackSeconds;
  final int skipForwardSeconds;

  /// Saut temporel ou épisode précédent / suivant, hors de l’application.
  final OutsideAppControl outsideApp;
  final bool showRemainingTime;

  /// Position / durée affichées en temps réel selon la vitesse de lecture.
  final bool timeRespectsSpeed;
  final bool keepScreenOn;

  /// Boutons affichés dans la barre mini (play/pause toujours inclus).
  final MiniPlayerButtons miniPlayerButtons;

  /// Afficher la jaquette du podcast plutôt que celle de l’épisode.
  final bool preferPodcastCover;

  /// Densité des tuiles d’épisodes (confortable / compact).
  final EpisodeListDensity episodeListDensity;

  /// Filtres de la page Épisodes.
  final EpisodeFilters episodeFilters;
  final int podcastColumns;
  final bool podcastList;
  final bool podcastShowNames;
  final PodcastCounter podcastCounter;
  final PodcastSort podcastSort;
  final PodcastFilters podcastFilters;
  final List<String> navOrder;
  final bool enqueueDownloads;
  final bool dequeueDeletedDownloads;

  /// Téléchargement automatique. Éteint, le mécanisme s’arrête sans effacer
  /// le choix de chaque abonnement.
  final bool automaticDownload;

  /// Nombre max d’épisodes à télécharger automatiquement par podcast.
  /// `null` = illimité. Les non lus déjà téléchargés comptent dans le plafond.
  final int? automaticDownloadLimit;

  /// Fichiers téléchargés en même temps, manuels compris.
  final int simultaneousDownloads;

  /// Autorise les téléchargements sur les données mobiles.
  /// Sinon ils attendent le Wi-Fi. Un téléchargement lancé à la main demande
  /// confirmation. Départ : coupé.
  final bool allowMobileData;

  /// Autorise le streaming sur les données mobiles. Sinon un fichier local
  /// se lit, un flux distant attend le Wi-Fi. Départ : coupé.
  final bool allowMobileStreaming;

  /// Autorise l’actualisation des abonnements sur les données mobiles.
  /// Sinon elle attend le Wi-Fi. Départ : coupé.
  final bool allowMobileRefresh;

  /// Notification pendant un téléchargement, et à la fin. Départ : coupé.
  final bool notifyDownloadActivity;

  /// Notification quand un téléchargement échoue. Départ : coupé.
  final bool notifyDownloadErrors;

  /// Notification quand la synchronisation échoue. Départ : coupé.
  final bool notifySyncErrors;

  /// Notification quand un abonnement publie. Départ : coupé.
  /// L’activer inclut tous les abonnements ; chacun peut ensuite être coupé.
  final bool notifyNewEpisodes;

  /// Nombre maximal de fichiers locaux. `null` = illimité.
  final int? episodeCacheSize;

  /// Supprime le fichier quand la lecture se termine. Les favoris restent.
  /// Marquer un épisode lu à la main ne le supprime pas.
  final bool deleteAfterPlayback;

  /// Quand libérer de la place avant un téléchargement automatique.
  final EpisodeCacheCleanup episodeCacheCleanup;

  final String? downloadDirectory;

  /// Sauvegarde automatique de la base (style AntennaPod).
  final bool automaticDatabaseBackup;

  /// Dossier des sauvegardes auto (chemin local ou URI SAF).
  final String? automaticDatabaseBackupFolder;

  /// Délai mini entre deux actualisations globales (0 = pas de limite).
  final int refreshIntervalMinutes;

  /// Langues d’Explorer. `*` = toutes.
  final List<String> discoverLanguages;

  /// Dernière sélection précise, conservée quand « Toutes » est actif.
  final List<String> discoverLanguagesPicked;

  /// Code de langue de l’interface, ou `null` pour suivre le système.
  final String? interfaceLanguage;

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppAccent? accent,
    bool? pureBlack,
    bool? ecoMode,
    bool? onboardingComplete,
    bool? wallpaperColors,
    bool? tintFromCover,
    HomeShelves? homeShelves,
    HomeCategories? homeCategories,
    bool? homeCategoriesChosen,
    double? speed,
    double? volume,
    int? skipBackSeconds,
    int? skipForwardSeconds,
    OutsideAppControl? outsideApp,
    bool? showRemainingTime,
    bool? timeRespectsSpeed,
    bool? keepScreenOn,
    MiniPlayerButtons? miniPlayerButtons,
    bool? preferPodcastCover,
    EpisodeListDensity? episodeListDensity,
    EpisodeFilters? episodeFilters,
    int? podcastColumns,
    bool? podcastList,
    bool? podcastShowNames,
    PodcastCounter? podcastCounter,
    PodcastSort? podcastSort,
    PodcastFilters? podcastFilters,
    List<String>? navOrder,
    bool? enqueueDownloads,
    bool? dequeueDeletedDownloads,
    bool? automaticDownload,
    int? automaticDownloadLimit,
    bool clearAutomaticDownloadLimit = false,
    int? simultaneousDownloads,
    bool? allowMobileData,
    bool? allowMobileStreaming,
    bool? allowMobileRefresh,
    bool? notifyDownloadActivity,
    bool? notifyDownloadErrors,
    bool? notifySyncErrors,
    bool? notifyNewEpisodes,
    int? episodeCacheSize,
    bool clearEpisodeCacheSize = false,
    bool? deleteAfterPlayback,
    EpisodeCacheCleanup? episodeCacheCleanup,
    String? downloadDirectory,
    bool clearDownloadDirectory = false,
    bool? automaticDatabaseBackup,
    String? automaticDatabaseBackupFolder,
    bool clearAutomaticDatabaseBackupFolder = false,
    int? refreshIntervalMinutes,
    List<String>? discoverLanguages,
    List<String>? discoverLanguagesPicked,
    String? interfaceLanguage,
    bool clearInterfaceLanguage = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
      pureBlack: pureBlack ?? this.pureBlack,
      ecoMode: ecoMode ?? this.ecoMode,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      wallpaperColors: wallpaperColors ?? this.wallpaperColors,
      tintFromCover: tintFromCover ?? this.tintFromCover,
      homeShelves: homeShelves ?? this.homeShelves,
      homeCategories: homeCategories ?? this.homeCategories,
      homeCategoriesChosen: homeCategoriesChosen ?? this.homeCategoriesChosen,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      skipBackSeconds: skipBackSeconds ?? this.skipBackSeconds,
      skipForwardSeconds: skipForwardSeconds ?? this.skipForwardSeconds,
      outsideApp: outsideApp ?? this.outsideApp,
      showRemainingTime: showRemainingTime ?? this.showRemainingTime,
      timeRespectsSpeed: timeRespectsSpeed ?? this.timeRespectsSpeed,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      miniPlayerButtons: miniPlayerButtons ?? this.miniPlayerButtons,
      preferPodcastCover: preferPodcastCover ?? this.preferPodcastCover,
      episodeListDensity: episodeListDensity ?? this.episodeListDensity,
      episodeFilters: episodeFilters ?? this.episodeFilters,
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
      automaticDownload: automaticDownload ?? this.automaticDownload,
      automaticDownloadLimit: clearAutomaticDownloadLimit
          ? null
          : (automaticDownloadLimit ?? this.automaticDownloadLimit),
      simultaneousDownloads:
          simultaneousDownloads ?? this.simultaneousDownloads,
      allowMobileData: allowMobileData ?? this.allowMobileData,
      allowMobileStreaming: allowMobileStreaming ?? this.allowMobileStreaming,
      allowMobileRefresh: allowMobileRefresh ?? this.allowMobileRefresh,
      notifyDownloadActivity:
          notifyDownloadActivity ?? this.notifyDownloadActivity,
      notifyDownloadErrors: notifyDownloadErrors ?? this.notifyDownloadErrors,
      notifySyncErrors: notifySyncErrors ?? this.notifySyncErrors,
      notifyNewEpisodes: notifyNewEpisodes ?? this.notifyNewEpisodes,
      episodeCacheSize: clearEpisodeCacheSize
          ? null
          : (episodeCacheSize ?? this.episodeCacheSize),
      deleteAfterPlayback: deleteAfterPlayback ?? this.deleteAfterPlayback,
      episodeCacheCleanup: episodeCacheCleanup ?? this.episodeCacheCleanup,
      downloadDirectory: clearDownloadDirectory
          ? null
          : (downloadDirectory ?? this.downloadDirectory),
      automaticDatabaseBackup:
          automaticDatabaseBackup ?? this.automaticDatabaseBackup,
      automaticDatabaseBackupFolder: clearAutomaticDatabaseBackupFolder
          ? null
          : (automaticDatabaseBackupFolder ??
                this.automaticDatabaseBackupFolder),
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      discoverLanguages: discoverLanguages ?? this.discoverLanguages,
      discoverLanguagesPicked:
          discoverLanguagesPicked ?? this.discoverLanguagesPicked,
      interfaceLanguage: clearInterfaceLanguage
          ? null
          : (interfaceLanguage ?? this.interfaceLanguage),
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
    final ecoMode = preferences.getBool('ecoMode') ?? false;
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[themeName] ?? ThemeMode.system,
      accent: AppAccent.byId(preferences.getString('accent')),
      pureBlack: ecoMode || (preferences.getBool('pureBlack') ?? false),
      ecoMode: ecoMode,
      onboardingComplete: preferences.getBool('onboardingComplete') ?? false,
      wallpaperColors: preferences.getBool('wallpaperColors') ?? false,
      tintFromCover: preferences.getBool('tintFromCover') ?? true,
      homeShelves: HomeShelves.fromIds(
        preferences.getStringList('homeShelves'),
      ),
      homeCategories: HomeCategories.fromIds(
        preferences.getStringList('homeCategories'),
      ),
      homeCategoriesChosen: HomeCategories.recognizes(
        preferences.getStringList('homeCategories'),
      ),
      speed: preferences.getDouble('speed') ?? 1,
      volume: _volume(preferences.getDouble('volume')),
      skipBackSeconds: preferences.getInt('skipBack') ?? 10,
      skipForwardSeconds: preferences.getInt('skipForward') ?? 30,
      outsideApp: OutsideAppControl.byId(preferences.getString('outsideApp')),
      showRemainingTime: preferences.getBool('showRemainingTime') ?? false,
      timeRespectsSpeed: preferences.getBool('timeRespectsSpeed') ?? false,
      keepScreenOn: preferences.getBool('keepScreenOn') ?? false,
      miniPlayerButtons: MiniPlayerButtons.fromIds(
        preferences.getStringList('miniPlayerButtons'),
      ),
      preferPodcastCover: preferences.getBool('preferPodcastCover') ?? false,
      episodeListDensity: EpisodeListDensity.byId(
        preferences.getString('episodeListDensity'),
      ),
      episodeFilters: EpisodeFilters.fromIds(
        preferences.getStringList('episodeFilters'),
      ),
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
      automaticDownload: preferences.getBool('automaticDownload') ?? false,
      automaticDownloadLimit: automaticDownloadLimitFromStored(
        preferences.getInt('automaticDownloadLimit'),
      ),
      simultaneousDownloads: simultaneousDownloadsFromStored(
        preferences.getInt('simultaneousDownloads'),
      ),
      allowMobileData: preferences.getBool('allowMobileData') ?? false,
      allowMobileStreaming:
          preferences.getBool('allowMobileStreaming') ??
          preferences.getBool('allowMobileData') ??
          false,
      allowMobileRefresh: preferences.getBool('allowMobileRefresh') ?? false,
      notifyDownloadActivity:
          preferences.getBool('notifyDownloadActivity') ?? false,
      notifyDownloadErrors:
          preferences.getBool('notifyDownloadErrors') ?? false,
      notifySyncErrors: preferences.getBool('notifySyncErrors') ?? false,
      notifyNewEpisodes: preferences.getBool('notifyNewEpisodes') ?? false,
      episodeCacheSize: episodeCacheSizeFromStored(
        preferences.getInt('episodeCacheSize'),
      ),
      deleteAfterPlayback: preferences.getBool('deleteAfterPlayback') ?? false,
      episodeCacheCleanup: EpisodeCacheCleanup.byId(
        preferences.getString('episodeCacheCleanup'),
      ),
      downloadDirectory: preferences.getString('downloadDirectory'),
      automaticDatabaseBackup:
          preferences.getBool('automaticDatabaseBackup') ?? false,
      automaticDatabaseBackupFolder: preferences.getString(
        'automaticDatabaseBackupFolder',
      ),
      refreshIntervalMinutes: _refreshIntervalMinutes(
        preferences.getInt('refreshIntervalMinutes'),
      ),
      discoverLanguages: _discoverLanguages(preferences),
      discoverLanguagesPicked: _discoverLanguagesPicked(preferences),
      interfaceLanguage: normalizeInterfaceLanguage(
        preferences.getString('interfaceLanguage'),
      ),
    );
  }

  static List<String> _discoverLanguages(SharedPreferences preferences) {
    return normalizeDiscoverLanguages(
      preferences.getStringList('discoverLanguages'),
    );
  }

  static List<String> _discoverLanguagesPicked(SharedPreferences preferences) {
    final stored = preferences.getStringList('discoverLanguagesPicked');
    if (stored != null) return normalizeDiscoverLanguagesPicked(stored);
    final languages = _discoverLanguages(preferences);
    if (discoverLanguagesAreAll(languages)) return discoverLanguagesDefault;
    return languages;
  }

  static int _columns(int? stored) {
    if (stored == null || stored < 1 || stored > 8) return 3;
    return stored;
  }

  static int _refreshIntervalMinutes(int? stored) {
    if (stored == null) return 5;
    if (stored < 0) return 5;
    return stored;
  }

  static double _volume(double? stored) {
    if (stored == null) return 1;
    return stored.clamp(0.0, 1.0);
  }

  Future<void> setInterfaceLanguage(String? code) async {
    final normalized = normalizeInterfaceLanguage(code);
    final preferences = ref.read(sharedPreferencesProvider);
    if (normalized == null) {
      state = state.copyWith(clearInterfaceLanguage: true);
      await preferences.remove('interfaceLanguage');
      return;
    }
    state = state.copyWith(interfaceLanguage: normalized);
    await preferences.setString('interfaceLanguage', normalized);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.ecoMode) return;
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString('theme', mode.name);
  }

  Future<void> setAccent(AppAccent accent) async {
    state = state.copyWith(accent: accent);
    await ref.read(sharedPreferencesProvider).setString('accent', accent.id);
  }

  Future<void> setPureBlack(bool enabled) async {
    if (state.ecoMode && !enabled) return;
    state = state.copyWith(pureBlack: enabled);
    await ref.read(sharedPreferencesProvider).setBool('pureBlack', enabled);
  }

  /// Active le noir pur et l’y maintient. Le désactiver laisse le noir pur tel quel.
  Future<void> setEcoMode(bool enabled) async {
    final preferences = ref.read(sharedPreferencesProvider);
    if (enabled) {
      state = state.copyWith(ecoMode: true, pureBlack: true);
      await preferences.setBool('ecoMode', true);
      await preferences.setBool('pureBlack', true);
      return;
    }
    state = state.copyWith(ecoMode: false);
    await preferences.setBool('ecoMode', false);
  }

  Future<void> setOnboardingComplete(bool enabled) async {
    state = state.copyWith(onboardingComplete: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('onboardingComplete', enabled);
  }

  Future<void> setWallpaperColors(bool enabled) async {
    state = state.copyWith(wallpaperColors: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('wallpaperColors', enabled);
  }

  Future<void> setTintFromCover(bool enabled) async {
    state = state.copyWith(tintFromCover: enabled);
    await ref.read(sharedPreferencesProvider).setBool('tintFromCover', enabled);
  }

  Future<void> setHomeShelves(HomeShelves shelves) async {
    state = state.copyWith(homeShelves: shelves);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList('homeShelves', shelves.toIds());
  }

  Future<void> setHomeCategories(HomeCategories categories) async {
    state = state.copyWith(
      homeCategories: categories,
      homeCategoriesChosen: true,
    );
    await ref
        .read(sharedPreferencesProvider)
        .setStringList('homeCategories', categories.toIds());
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

  Future<void> setOutsideApp(OutsideAppControl control) async {
    state = state.copyWith(outsideApp: control);
    await ref
        .read(sharedPreferencesProvider)
        .setString('outsideApp', control.id);
  }

  Future<void> setShowRemainingTime(bool enabled) async {
    state = state.copyWith(showRemainingTime: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('showRemainingTime', enabled);
  }

  Future<void> setTimeRespectsSpeed(bool enabled) async {
    state = state.copyWith(timeRespectsSpeed: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('timeRespectsSpeed', enabled);
  }

  Future<void> setKeepScreenOn(bool enabled) async {
    state = state.copyWith(keepScreenOn: enabled);
    await ref.read(sharedPreferencesProvider).setBool('keepScreenOn', enabled);
  }

  Future<void> setMiniPlayerButtons(MiniPlayerButtons buttons) async {
    state = state.copyWith(miniPlayerButtons: buttons);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList('miniPlayerButtons', buttons.toIds());
  }

  Future<void> setPreferPodcastCover(bool enabled) async {
    state = state.copyWith(preferPodcastCover: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('preferPodcastCover', enabled);
  }

  Future<void> setEpisodeListDensity(EpisodeListDensity density) async {
    state = state.copyWith(episodeListDensity: density);
    await ref
        .read(sharedPreferencesProvider)
        .setString('episodeListDensity', density.id);
  }

  Future<void> setEpisodeFilters(EpisodeFilters filters) async {
    state = state.copyWith(episodeFilters: filters);
    // Toujours écrire la liste (même vide) pour distinguer « jamais
    // configuré » (défaut Non lus) de « Tout effacer » (tous les épisodes).
    await ref
        .read(sharedPreferencesProvider)
        .setStringList('episodeFilters', filters.toIds());
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

  Future<void> setAutomaticDatabaseBackup(bool enabled) async {
    state = state.copyWith(automaticDatabaseBackup: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('automaticDatabaseBackup', enabled);
  }

  Future<void> setAutomaticDatabaseBackupFolder(String? folder) async {
    if (folder == null || folder.isEmpty) {
      state = state.copyWith(clearAutomaticDatabaseBackupFolder: true);
      await ref
          .read(sharedPreferencesProvider)
          .remove('automaticDatabaseBackupFolder');
      return;
    }
    state = state.copyWith(automaticDatabaseBackupFolder: folder);
    await ref
        .read(sharedPreferencesProvider)
        .setString('automaticDatabaseBackupFolder', folder);
  }

  Future<void> setAutomaticDownload(bool enabled) async {
    state = state.copyWith(automaticDownload: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('automaticDownload', enabled);
  }

  Future<void> setAllowMobileData(bool enabled) async {
    state = state.copyWith(allowMobileData: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('allowMobileData', enabled);
  }

  Future<void> setAllowMobileStreaming(bool enabled) async {
    state = state.copyWith(allowMobileStreaming: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('allowMobileStreaming', enabled);
  }

  Future<void> setAllowMobileRefresh(bool enabled) async {
    state = state.copyWith(allowMobileRefresh: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('allowMobileRefresh', enabled);
  }

  Future<void> setNotifyDownloadActivity(bool enabled) async {
    state = state.copyWith(notifyDownloadActivity: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('notifyDownloadActivity', enabled);
  }

  Future<void> setNotifyDownloadErrors(bool enabled) async {
    state = state.copyWith(notifyDownloadErrors: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('notifyDownloadErrors', enabled);
  }

  Future<void> setNotifySyncErrors(bool enabled) async {
    state = state.copyWith(notifySyncErrors: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('notifySyncErrors', enabled);
  }

  Future<void> setNotifyNewEpisodes(bool enabled) async {
    state = state.copyWith(notifyNewEpisodes: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('notifyNewEpisodes', enabled);
  }

  Future<void> setAutomaticDownloadLimit(int? limit) async {
    final normalized = automaticDownloadLimitFromStored(limit);
    final preferences = ref.read(sharedPreferencesProvider);
    if (normalized == null) {
      state = state.copyWith(clearAutomaticDownloadLimit: true);
      await preferences.remove('automaticDownloadLimit');
      return;
    }
    state = state.copyWith(automaticDownloadLimit: normalized);
    await preferences.setInt('automaticDownloadLimit', normalized);
  }

  Future<void> setSimultaneousDownloads(int count) async {
    final normalized = simultaneousDownloadsFromStored(count);
    state = state.copyWith(simultaneousDownloads: normalized);
    await ref
        .read(sharedPreferencesProvider)
        .setInt('simultaneousDownloads', normalized);
  }

  Future<void> setEpisodeCacheSize(int? size) async {
    final normalized = episodeCacheSizeFromStored(size);
    final preferences = ref.read(sharedPreferencesProvider);
    if (normalized == null) {
      state = state.copyWith(clearEpisodeCacheSize: true);
      await preferences.remove('episodeCacheSize');
      return;
    }
    state = state.copyWith(episodeCacheSize: normalized);
    await preferences.setInt('episodeCacheSize', normalized);
  }

  Future<void> setDeleteAfterPlayback(bool enabled) async {
    state = state.copyWith(deleteAfterPlayback: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('deleteAfterPlayback', enabled);
  }

  Future<void> setEpisodeCacheCleanup(EpisodeCacheCleanup cleanup) async {
    state = state.copyWith(episodeCacheCleanup: cleanup);
    await ref
        .read(sharedPreferencesProvider)
        .setString('episodeCacheCleanup', cleanup.id);
  }

  Future<void> setEnqueueDownloads(bool enabled) async {
    state = state.copyWith(enqueueDownloads: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool('enqueueDownloads', enabled);
  }

  Future<void> setRefreshIntervalMinutes(int minutes) async {
    final clamped = minutes < 0 ? 0 : minutes;
    state = state.copyWith(refreshIntervalMinutes: clamped);
    await ref
        .read(sharedPreferencesProvider)
        .setInt('refreshIntervalMinutes', clamped);
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

  Future<void> setDiscoverLanguages(List<String> languages) async {
    final normalized = normalizeDiscoverLanguages(languages);
    final preferences = ref.read(sharedPreferencesProvider);
    if (discoverLanguagesAreAll(normalized)) {
      state = state.copyWith(discoverLanguages: normalized);
      await preferences.setStringList('discoverLanguages', normalized);
      return;
    }
    state = state.copyWith(
      discoverLanguages: normalized,
      discoverLanguagesPicked: normalized,
    );
    await preferences.setStringList('discoverLanguages', normalized);
    await preferences.setStringList('discoverLanguagesPicked', normalized);
  }

  /// Active ou coupe « Toutes les langues » sans oublier la sélection précise.
  Future<void> setDiscoverAllLanguages(bool all) async {
    final preferences = ref.read(sharedPreferencesProvider);
    final picked = state.discoverLanguagesPicked;
    if (all) {
      state = state.copyWith(discoverLanguages: const [discoverLanguagesAll]);
      await preferences.setStringList('discoverLanguages', const [
        discoverLanguagesAll,
      ]);
      await preferences.setStringList('discoverLanguagesPicked', picked);
      return;
    }
    state = state.copyWith(discoverLanguages: picked);
    await preferences.setStringList('discoverLanguages', picked);
  }

  Future<void> setNavOrder(List<String> order) async {
    final normalized = normalizeNavOrder(order);
    state = state.copyWith(navOrder: normalized);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList('navOrder', normalized);
  }
}
