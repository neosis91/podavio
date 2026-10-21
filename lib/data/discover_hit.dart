/// Résultat de découverte / recherche (Apple, Podcast Index, fyyd…).
enum DiscoverSource {
  apple('Apple Podcasts'),
  podcastIndex('Podcast Index'),
  fyyd('fyyd');

  const DiscoverSource(this.label);
  final String label;
}

class DiscoverHit {
  const DiscoverHit({
    required this.title,
    required this.feedUrl,
    required this.source,
    this.author = '',
    this.imageUrl,
    this.appleId,
    this.episodeCount,
    this.lastEpisodeAt,
    this.averageDurationMinutes,
  });

  final String title;
  final String author;
  final String? imageUrl;
  final String feedUrl;
  final DiscoverSource source;

  /// Identifiant Apple si la recherche iTunes n’a pas fourni de RSS.
  final int? appleId;

  /// Nombre d’épisodes connu du catalogue, si fourni.
  final int? episodeCount;

  /// Date du dernier épisode / dernière màj catalogue.
  final DateTime? lastEpisodeAt;

  /// Durée moyenne d’un épisode en minutes, si le catalogue la fournit.
  final int? averageDurationMinutes;

  String get dedupeKey {
    final feed = feedUrl.trim().toLowerCase();
    if (feed.isNotEmpty) return feed;
    if (appleId != null) return 'apple:$appleId';
    return 'title:${title.trim().toLowerCase()}';
  }

  DiscoverHit copyWith({
    String? title,
    String? author,
    String? imageUrl,
    String? feedUrl,
    DiscoverSource? source,
    int? appleId,
    int? episodeCount,
    DateTime? lastEpisodeAt,
    int? averageDurationMinutes,
  }) {
    return DiscoverHit(
      title: title ?? this.title,
      author: author ?? this.author,
      imageUrl: imageUrl ?? this.imageUrl,
      feedUrl: feedUrl ?? this.feedUrl,
      source: source ?? this.source,
      appleId: appleId ?? this.appleId,
      episodeCount: episodeCount ?? this.episodeCount,
      lastEpisodeAt: lastEpisodeAt ?? this.lastEpisodeAt,
      averageDurationMinutes:
          averageDurationMinutes ?? this.averageDurationMinutes,
    );
  }
}
