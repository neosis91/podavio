import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';
import 'cover_service.dart';
import 'download_notifications.dart';
import 'status_notifications.dart';
import 'download_service.dart';
import 'feed_service.dart';
import 'models.dart';
import '../settings/settings_controller.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences n’est pas initialisé.');
});

final _databaseClose = Expando<Future<void>>();

/// Ferme [database] une seule fois. Un second appel attend la même fermeture.
Future<void> closeAppDatabase(AppDatabase database) {
  return _databaseClose[database] ??= database.close();
}

/// `false` pendant un import : `close()` attend les watch Drift encore
/// ouverts, donc l’import les coupe d’abord et ferme lui-même l’ancienne base.
bool _closeDatabaseOnDispose = true;

enum DatabasePhase { open, replacing }

class DatabasePhaseNotifier extends Notifier<DatabasePhase> {
  @override
  DatabasePhase build() => DatabasePhase.open;

  void beginReplacement() {
    _closeDatabaseOnDispose = false;
    state = DatabasePhase.replacing;
  }

  void finishReplacement() {
    _closeDatabaseOnDispose = true;
    state = DatabasePhase.open;
  }
}

final databasePhaseProvider =
    NotifierProvider<DatabasePhaseNotifier, DatabasePhase>(
      DatabasePhaseNotifier.new,
    );

final _mojibakeRepairs = Expando<Future<void>>();

/// Une fois par base : remet les accents des titres mal décodés.
final mojibakeRepairProvider = Provider<void>((ref) {
  if (ref.watch(databasePhaseProvider) != DatabasePhase.open) return;
  final database = ref.watch(databaseProvider);
  unawaited(_mojibakeRepairs[database] ??= database.repairMojibakeText());
});

final databaseProvider = Provider<AppDatabase>((ref) {
  // Tant que le fichier est remplacé, les lecteurs se désabonnent sans
  // qu’une nouvelle connexion s’ouvre sur l’ancien ou le nouveau fichier.
  if (ref.watch(databasePhaseProvider) != DatabasePhase.open) {
    throw StateError('Database is being replaced.');
  }
  final database = AppDatabase.defaults();
  ref.onDispose(() {
    if (!_closeDatabaseOnDispose) return;
    unawaited(closeAppDatabase(database));
  });
  return database;
});

final feedServiceProvider = Provider<FeedService>((ref) {
  return FeedService(ref.watch(databaseProvider));
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(ref.watch(databaseProvider));
});

final downloadNotificationsProvider = Provider<DownloadNotifications>((ref) {
  return SystemDownloadNotifications();
});

final statusNotificationsProvider = Provider<StatusNotifications>((ref) {
  return SystemStatusNotifications();
});

final coverServiceProvider = Provider<CoverService>((ref) {
  return CoverService(ref.watch(databaseProvider));
});

final defaultDownloadDirectoryProvider = FutureProvider<String>((ref) {
  return ref.watch(downloadServiceProvider).resolveDownloadDirectory(null);
});

final episodeProvider = StreamProvider.family<EpisodeEntry?, int>((ref, id) {
  return ref.watch(databaseProvider).watchEpisode(id);
});

/// Chapitres d’un épisode (chargement lazy depuis l’URL Podcast Index).
final chaptersProvider = StreamProvider.family<List<EpisodeChapter>, int>((
  ref,
  id,
) {
  unawaited(ref.watch(feedServiceProvider).ensureChapters(id));
  return ref.watch(databaseProvider).watchChapters(id);
});

/// Résultat du fetch réseau des chapitres (le stream Drift émet `[]` tout de suite).
enum ChaptersLoadPhase { loaded, failed }

/// Suit `ensureChapters` plutôt que `AsyncValue.isLoading` du watch Drift.
final chaptersLoadStateProvider = FutureProvider.family<ChaptersLoadPhase, int>(
  (ref, id) async {
    final feed = ref.watch(feedServiceProvider);
    await feed.ensureChapters(id);
    if (feed.chaptersRecentlyFailed(id)) return ChaptersLoadPhase.failed;
    return ChaptersLoadPhase.loaded;
  },
);

final podcastsProvider = StreamProvider<List<Podcast>>((ref) {
  final sort = ref.watch(settingsProvider.select((s) => s.podcastSort));
  final database = ref.watch(databaseProvider);
  return switch (sort) {
    PodcastSort.published => database.watchPodcasts(),
    _ => database.watchPodcastsPlain(),
  };
});

/// Télécharge automatiquement les jaquettes de podcasts manquantes.
final coverPrefetchProvider = Provider<void>((ref) {
  // Le shell l’écoute en permanence. Pendant un import, la base refuse les
  // lectures : on se retire sans propager l’erreur jusqu’au widget.
  if (ref.watch(databasePhaseProvider) != DatabasePhase.open) return;
  final eco = ref.watch(
    settingsProvider.select((settings) => settings.ecoMode),
  );
  final service = ref.watch(coverServiceProvider);
  service.downloadsEnabled = !eco;
  if (eco) return;
  ref.listen<AsyncValue<List<Podcast>>>(podcastsProvider, (_, next) {
    next.whenData((_) => service.schedulePodcastSync());
  });
  Future.microtask(service.schedulePodcastSync);
});

final podcastProvider = StreamProvider.family<Podcast?, int>((ref, id) {
  return ref.watch(databaseProvider).watchPodcast(id);
});

final unreadCountProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).watchUnreadCount();
});

final unreadCountsByPodcastProvider = StreamProvider<Map<int, int>>((ref) {
  return ref.watch(databaseProvider).watchUnreadCountsByPodcast();
});

final podcastEpisodeCountProvider = StreamProvider.family<int, int>((ref, id) {
  return ref
      .watch(databaseProvider)
      .watchEpisodeCountsByPodcast()
      .map((counts) => counts[id] ?? 0);
});

final playlistsProvider = StreamProvider<List<PlaylistSummary>>((ref) {
  return ref.watch(databaseProvider).watchPlaylists();
});

final playlistEpisodesProvider = StreamProvider.family<List<EpisodeEntry>, int>(
  (ref, playlistId) {
    return ref.watch(databaseProvider).watchPlaylistEpisodes(playlistId);
  },
);

final customPlaylistEpisodeIdsProvider = StreamProvider<Set<int>>((ref) {
  return ref.watch(databaseProvider).watchCustomPlaylistEpisodeIds();
});

final customPlaylistIdsProvider = StreamProvider.family<Set<int>, int>((
  ref,
  episodeId,
) {
  return ref.watch(databaseProvider).watchCustomPlaylistIds(episodeId);
});

final episodesProvider =
    NotifierProvider.family<
      EpisodesNotifier,
      AsyncValue<EpisodeWindow>,
      EpisodeQuery
    >(EpisodesNotifier.new);

class EpisodeWindow {
  const EpisodeWindow(this.entries, this.hasMore);

  final List<EpisodeEntry> entries;
  final bool hasMore;
}

class EpisodesNotifier extends Notifier<AsyncValue<EpisodeWindow>> {
  EpisodesNotifier(this.query);

  final EpisodeQuery query;
  static const pageSize = 40;
  var _limit = pageSize;
  var _closed = false;
  var _loadingMore = false;
  StreamSubscription<List<EpisodeEntry>>? _subscription;

  @override
  AsyncValue<EpisodeWindow> build() {
    _limit = pageSize;
    _closed = false;
    _loadingMore = false;
    ref.onDispose(() {
      _closed = true;
      _subscription?.cancel();
    });
    _subscribe();
    return const AsyncLoading();
  }

  void loadMore() {
    if (!query.paginated || _loadingMore) return;
    final current = state.asData?.value;
    if (current == null || !current.hasMore) return;
    _loadingMore = true;
    _limit += pageSize;
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = ref
        .read(databaseProvider)
        .watchEpisodeWindow(
          unreadOnly: query.unreadOnly,
          favoritesOnly: query.favoritesOnly,
          downloadsOnly: query.downloadsOnly,
          cacheOnly: query.cacheOnly,
          queuedOnly: query.queuedOnly,
          historyOnly: query.historyOnly,
          inProgressOnly: query.inProgressOnly,
          podcastId: query.podcastId,
          playlistId: query.playlistId,
          search: query.search,
          oldestFirst: query.oldestFirst,
          limit: query.paginated ? _limit : null,
        )
        .listen(
          (rows) {
            if (_closed) return;
            _loadingMore = false;
            state = AsyncData(
              EpisodeWindow(rows, query.paginated && rows.length >= _limit),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_closed) return;
            _loadingMore = false;
            state = AsyncError(error, stackTrace);
          },
        );
  }
}

class EpisodeQuery {
  const EpisodeQuery({
    this.unreadOnly = false,
    this.favoritesOnly = false,
    this.downloadsOnly = false,
    this.cacheOnly = false,
    this.queuedOnly = false,
    this.historyOnly = false,
    this.inProgressOnly = false,
    this.podcastId,
    this.playlistId,
    this.search = '',
    this.paginated = true,
    this.oldestFirst = false,
  });

  final bool unreadOnly;
  final bool favoritesOnly;
  final bool downloadsOnly;
  final bool cacheOnly;
  final bool queuedOnly;
  final bool historyOnly;
  final bool inProgressOnly;
  final int? podcastId;
  final int? playlistId;
  final String search;
  final bool paginated;

  /// Plus ancien en tête. La page d’un podcast peut l’inverser pour l’affichage.
  /// La file du lecteur, elle, reste dans cet ordre.
  final bool oldestFirst;

  @override
  bool operator ==(Object other) {
    return other is EpisodeQuery &&
        other.unreadOnly == unreadOnly &&
        other.favoritesOnly == favoritesOnly &&
        other.downloadsOnly == downloadsOnly &&
        other.cacheOnly == cacheOnly &&
        other.queuedOnly == queuedOnly &&
        other.historyOnly == historyOnly &&
        other.inProgressOnly == inProgressOnly &&
        other.podcastId == podcastId &&
        other.playlistId == playlistId &&
        other.search == search &&
        other.paginated == paginated &&
        other.oldestFirst == oldestFirst;
  }

  @override
  int get hashCode => Object.hash(
    unreadOnly,
    favoritesOnly,
    downloadsOnly,
    cacheOnly,
    queuedOnly,
    historyOnly,
    inProgressOnly,
    podcastId,
    playlistId,
    search,
    paginated,
    oldestFirst,
  );
}

final inProgressProvider = StreamProvider<List<EpisodeEntry>>((ref) {
  return ref.watch(databaseProvider).watchInProgress();
});

final freshEpisodesProvider = StreamProvider<List<EpisodeEntry>>((ref) {
  return ref.watch(databaseProvider).watchFreshEpisodes();
});

final recentDownloadsProvider = StreamProvider<List<EpisodeEntry>>((ref) {
  return ref.watch(databaseProvider).watchRecentDownloads();
});

final favoriteEpisodesProvider = StreamProvider<List<EpisodeEntry>>((ref) {
  return ref
      .watch(databaseProvider)
      .watchEpisodeWindow(favoritesOnly: true, limit: 16);
});

/// Lectures récentes, sans les épisodes encore dans « Continuer d’écouter ».
final recentPlayedProvider = StreamProvider<List<EpisodeEntry>>((ref) {
  final playing = ref.watch(inProgressProvider).asData?.value ?? const [];
  final playingIds = {for (final entry in playing) entry.episode.id};
  return ref
      .watch(databaseProvider)
      .watchEpisodeWindow(historyOnly: true, limit: 28)
      .map((rows) {
        final played = [
          for (final entry in rows)
            if (!playingIds.contains(entry.episode.id)) entry,
        ];
        if (played.length <= 12) return played;
        return played.sublist(0, 12);
      });
});

final preferredPodcastsProvider = StreamProvider<List<Podcast>>((ref) {
  return ref.watch(databaseProvider).watchPodcastsByPreference();
});

final randomEpisodesProvider =
    AsyncNotifierProvider<RandomEpisodesNotifier, List<EpisodeEntry>>(
      RandomEpisodesNotifier.new,
    );

final podcastStatsSignalProvider =
    StreamProvider.family<(int, int, int, int, int, int), int>((
      ref,
      podcastId,
    ) {
      return ref.watch(databaseProvider).watchPodcastStatsSignal(podcastId);
    });

final podcastStatsProvider = FutureProvider.family<PodcastStats, int>((
  ref,
  podcastId,
) async {
  ref.watch(podcastStatsSignalProvider(podcastId));
  final stats = await ref.read(databaseProvider).podcastStats(podcastId);
  final bytes = await ref
      .read(downloadServiceProvider)
      .downloadBytesForPodcast(podcastId);
  return PodcastStats(
    episodeCount: stats.episodeCount,
    unreadCount: stats.unreadCount,
    startedCount: stats.startedCount,
    completedCount: stats.completedCount,
    inProgressCount: stats.inProgressCount,
    favoriteCount: stats.favoriteCount,
    downloadCount: stats.downloadCount,
    downloadBytes: bytes,
    listenedSeconds: stats.listenedSeconds,
    totalDurationSeconds: stats.totalDurationSeconds,
    averageDurationSeconds: stats.averageDurationSeconds,
    releaseInterval: stats.releaseInterval,
    lastPublishedAt: stats.lastPublishedAt,
    nextEpisodeAt: stats.nextEpisodeAt,
  );
});

final libraryStatsSignalProvider =
    StreamProvider<(int, int, int, int, int, int)>((ref) {
      return ref.watch(databaseProvider).watchLibraryStatsSignal();
    });

final libraryStatsProvider = FutureProvider<LibraryStats>((ref) async {
  ref.watch(libraryStatsSignalProvider);
  final stats = await ref.read(databaseProvider).libraryStats();
  final bytesByPodcast = await ref
      .read(downloadServiceProvider)
      .downloadBytesByPodcast();
  final downloads =
      [
        for (final item in stats.downloads)
          DownloadStat(
            podcastId: item.podcastId,
            title: item.title,
            author: item.author,
            imageUrl: item.imageUrl,
            downloadCount: item.downloadCount,
            downloadBytes: bytesByPodcast[item.podcastId] ?? 0,
          ),
      ]..sort((a, b) {
        final byBytes = b.downloadBytes.compareTo(a.downloadBytes);
        if (byBytes != 0) return byBytes;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
  final totalBytes = downloads.fold<int>(
    0,
    (sum, item) => sum + item.downloadBytes,
  );
  return LibraryStats(
    subscriptions: stats.subscriptions,
    years: stats.years,
    downloads: downloads,
    totalListenedSeconds: stats.totalListenedSeconds,
    totalDownloadBytes: totalBytes,
    totalDownloadCount: stats.totalDownloadCount,
    podcastCount: stats.podcastCount,
    episodeCount: stats.episodeCount,
  );
});

class RandomEpisodesNotifier extends AsyncNotifier<List<EpisodeEntry>> {
  @override
  Future<List<EpisodeEntry>> build() {
    return ref.read(databaseProvider).randomEpisodes();
  }

  Future<void> reshuffle() async {
    state = await AsyncValue.guard(
      () => ref.read(databaseProvider).randomEpisodes(),
    );
  }
}
