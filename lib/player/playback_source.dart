import '../data/app_database.dart';
import '../data/providers.dart';

/// Liste d’où la lecture a été lancée. Le lecteur enchaîne dans cet ordre.
class PlaybackSource {
  const PlaybackSource(this.query);

  final EpisodeQuery query;

  static const queue = PlaybackSource(
    EpisodeQuery(queuedOnly: true, paginated: false),
  );

  /// Épisodes d’un podcast, du plus ancien au plus récent.
  /// Les précédents sont les plus anciens, « À suivre » les plus récents.
  /// L’ordre affiché sur la page du podcast ne change pas cette file.
  factory PlaybackSource.podcast(int podcastId) {
    return PlaybackSource(
      EpisodeQuery(podcastId: podcastId, paginated: false, oldestFirst: true),
    );
  }

  factory PlaybackSource.fromQuery(EpisodeQuery query) {
    return PlaybackSource(
      EpisodeQuery(
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
        paginated: false,
        oldestFirst: query.oldestFirst,
      ),
    );
  }

  /// File de lecture (playlist par défaut).
  bool get isQueue => query.queuedOnly && query.playlistId == null;

  bool get canEditOrder => isQueue || query.playlistId != null;

  Stream<List<EpisodeEntry>> watch(AppDatabase database) {
    return database.watchEpisodeWindow(
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
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PlaybackSource && other.query == query;
  }

  @override
  int get hashCode => query.hashCode;
}
