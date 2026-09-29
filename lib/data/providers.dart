import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';
import 'download_service.dart';
import 'feed_service.dart';

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

final defaultDownloadDirectoryProvider = FutureProvider<String>((ref) {
  return ref.watch(downloadServiceProvider).resolveDownloadDirectory(null);
});

final episodeProvider = StreamProvider.family<EpisodeEntry?, int>((ref, id) {
  return ref.watch(databaseProvider).watchEpisode(id);
});

final podcastsProvider = StreamProvider<List<Podcast>>((ref) {
  return ref.watch(databaseProvider).watchPodcasts();
});

final podcastProvider = StreamProvider.family<Podcast?, int>((ref, id) {
  return ref.watch(databaseProvider).watchPodcast(id);
});

final unreadCountProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).watchUnreadCount();
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
  StreamSubscription<List<EpisodeEntry>>? _subscription;

  @override
  AsyncValue<EpisodeWindow> build() {
    _limit = pageSize;
    _closed = false;
    ref.onDispose(() {
      _closed = true;
      _subscription?.cancel();
    });
    _subscribe();
    return const AsyncLoading();
  }

  void loadMore() {
    if (!query.paginated) return;
    final current = state.asData?.value;
    if (current == null || !current.hasMore) return;
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
          podcastId: query.podcastId,
          search: query.search,
          limit: query.paginated ? _limit : null,
        )
        .listen(
          (rows) {
            if (_closed) return;
            state = AsyncData(
              EpisodeWindow(rows, query.paginated && rows.length >= _limit),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_closed) return;
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
    this.podcastId,
    this.search = '',
    this.paginated = true,
  });

  final bool unreadOnly;
  final bool favoritesOnly;
  final bool downloadsOnly;
  final bool queuedOnly;
  final bool historyOnly;
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

final preferredPodcastsProvider = StreamProvider<List<Podcast>>((ref) {
  return ref.watch(databaseProvider).watchPodcastsByPreference();
});

final randomEpisodesProvider =
    AsyncNotifierProvider<RandomEpisodesNotifier, List<EpisodeEntry>>(
      RandomEpisodesNotifier.new,
    );

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
