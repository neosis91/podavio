import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';
import 'cover_service.dart';
import 'download_notifications.dart';
import 'download_service.dart';
import 'feed_service.dart';
import 'models.dart';
import '../settings/settings_controller.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences n’est pas initialisé.');
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
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
  final service = ref.watch(coverServiceProvider);
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

final queueCountProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).watchQueueCount();
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
          queuedOnly: query.queuedOnly,
          historyOnly: query.historyOnly,
          inProgressOnly: query.inProgressOnly,
          podcastId: query.podcastId,
          search: query.search,
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
    this.queuedOnly = false,
    this.historyOnly = false,
    this.inProgressOnly = false,
    this.podcastId,
    this.search = '',
    this.paginated = true,
  });

  final bool unreadOnly;
  final bool favoritesOnly;
  final bool downloadsOnly;
  final bool queuedOnly;
  final bool historyOnly;
  final bool inProgressOnly;
  final int? podcastId;
  final String search;
  final bool paginated;

  @override
  bool operator ==(Object other) {
    return other is EpisodeQuery &&
        other.unreadOnly == unreadOnly &&
        other.favoritesOnly == favoritesOnly &&
        other.downloadsOnly == downloadsOnly &&
        other.queuedOnly == queuedOnly &&
        other.historyOnly == historyOnly &&
        other.inProgressOnly == inProgressOnly &&
        other.podcastId == podcastId &&
        other.search == search &&
        other.paginated == paginated;
  }

  @override
  int get hashCode => Object.hash(
    unreadOnly,
    favoritesOnly,
    downloadsOnly,
    queuedOnly,
    historyOnly,
    inProgressOnly,
    podcastId,
    search,
    paginated,
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
