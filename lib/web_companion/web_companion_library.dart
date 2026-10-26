import '../data/app_database.dart';
import 'web_companion_snapshot.dart';

class _EpisodeRef extends WebCompanionEpisodeRef {
  _EpisodeRef(this.episode)
    : super(
        id: episode.id,
        publishedAt: episode.publishedAt,
        positionMs: episode.positionMs,
        played: episode.played,
      );

  final Episode episode;
}

/// Bibliothèque envoyée au navigateur. Les fichiers locaux restent sur le téléphone.
Future<Map<String, Object?>> buildWebCompanionSnapshot(AppDatabase db) async {
  final podcasts = await db.listSubscribed();
  final payload = <Map<String, Object?>>[];
  for (final podcast in podcasts) {
    final episodes = await db.episodesForPodcast(podcast.id);
    final picked = capWebCompanionEpisodes([
      for (final episode in episodes) _EpisodeRef(episode),
    ]);
    payload.add({
      'id': podcast.id,
      'title': podcast.title,
      'author': podcast.author,
      'imageUrl': podcast.imageUrl,
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
          },
      ],
    });
  }
  return {'type': 'snapshot', 'podcasts': payload};
}
