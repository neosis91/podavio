import '../data/app_database.dart';
import 'web_companion_snapshot.dart';

class _EpisodeRef extends WebCompanionEpisodeRef {
  _EpisodeRef(this.episode, {required super.pinned})
    : super(
        id: episode.id,
        publishedAt: episode.publishedAt,
        positionMs: episode.positionMs,
        played: episode.played,
        favorite: episode.favorite,
        downloaded: _downloaded(episode),
        lastPlayedAt: episode.lastPlayedAt,
      );

  final Episode episode;

  static bool _downloaded(Episode episode) {
    final path = episode.downloadPath?.trim();
    return path != null && path.isNotEmpty;
  }
}

/// Bibliothèque envoyée au navigateur. Les fichiers locaux restent sur le téléphone.
Future<Map<String, Object?>> buildWebCompanionSnapshot(AppDatabase db) async {
  final library = await _libraryLists(db);
  final podcasts = await db.listSubscribed();
  final payload = <Map<String, Object?>>[];
  for (final podcast in podcasts) {
    final episodes = await db.episodesForPodcast(podcast.id);
    final picked = capWebCompanionEpisodes([
      for (final episode in episodes)
        _EpisodeRef(episode, pinned: library.pins.contains(episode.id)),
    ]);
    payload.add({
      'id': podcast.id,
      'title': podcast.title,
      'author': podcast.author,
      'imageUrl': podcast.imageUrl,
      'preferred': podcast.preferred,
      'episodes': [
        for (final item in picked)
          {
            'id': item.episode.id,
            'title': item.episode.title,
            'audioUrl': item.episode.audioUrl,
            'imageUrl': item.episode.imageUrl,
            'durationMs': item.episode.durationSeconds == null
                ? null
                : item.episode.durationSeconds! * 1000,
            'positionMs': item.episode.positionMs,
            'publishedAt': item.episode.publishedAt?.toUtc().toIso8601String(),
            'favorite': item.favorite,
            'downloaded': item.downloaded,
            'played': item.played,
            'lastPlayedAt': item.lastPlayedAt?.toUtc().toIso8601String(),
            'downloadedAt': item.episode.downloadedAt?.toUtc().toIso8601String(),
          },
      ],
    });
  }
  return {
    'type': 'snapshot',
    'podcasts': payload,
    'playlists': library.playlists,
  };
}

class _LibraryLists {
  const _LibraryLists({required this.playlists, required this.pins});

  final List<Map<String, Object?>> playlists;
  final Set<int> pins;
}

Future<_LibraryLists> _libraryLists(AppDatabase db) async {
  final summaries = await db.watchPlaylists().first;
  final playlists = <Map<String, Object?>>[];
  final pins = <int>{};
  for (final playlist in summaries) {
    final entries = await db
        .watchEpisodeWindow(
          queuedOnly: playlist.isDefault,
          playlistId: playlist.isDefault ? null : playlist.id,
        )
        .first;
    final ids = [for (final entry in entries) entry.episode.id];
    pins.addAll(ids);
    playlists.add({
      'id': playlist.id,
      'name': playlist.name,
      'isDefault': playlist.isDefault,
      'episodeIds': ids,
    });
  }
  return _LibraryLists(playlists: playlists, pins: pins);
}
