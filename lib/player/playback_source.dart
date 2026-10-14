import '../data/app_database.dart';
import '../data/providers.dart';

/// Liste d’où la lecture a été lancée. Le lecteur enchaîne dans cet ordre.
class PlaybackSource {
  const PlaybackSource(this.query);

  final EpisodeQuery query;

  static const queue = PlaybackSource(
    EpisodeQuery(queuedOnly: true, paginated: false),
  );

  factory PlaybackSource.fromQuery(EpisodeQuery query) {
    return PlaybackSource(
      EpisodeQuery(
        unreadOnly: query.unreadOnly,
        favoritesOnly: query.favoritesOnly,
        downloadsOnly: query.downloadsOnly,
        queuedOnly: query.queuedOnly,
        historyOnly: query.historyOnly,
        inProgressOnly: query.inProgressOnly,
        podcastId: query.podcastId,
        playlistId: query.playlistId,
        search: query.search,
        paginated: false,
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
      queuedOnly: query.queuedOnly,
      historyOnly: query.historyOnly,
      inProgressOnly: query.inProgressOnly,
      podcastId: query.podcastId,
      playlistId: query.playlistId,
      search: query.search,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PlaybackSource && other.query == query;
  }

  @override
  int get hashCode => query.hashCode;
}
