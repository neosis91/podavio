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

  /// Sens de lecture pour le seed de file : vers les plus récents.
  ///
  /// Les listes datées (podcast, favoris, téléchargements, boîte) sont
  /// affichées du plus récent au plus ancien : « suivant » doit remonter
  /// vers le plus récent. Les playlists / la file gardent l’ordre affiché.
  bool get playsTowardNewer {
    if (isQueue || query.playlistId != null) return false;
    if (query.historyOnly || query.inProgressOnly) return false;
    return true;
  }

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
