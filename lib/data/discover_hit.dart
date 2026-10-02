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
  });

  final String title;
  final String author;
  final String? imageUrl;
  final String feedUrl;
  final DiscoverSource source;

  /// Identifiant Apple si la recherche iTunes n’a pas fourni de RSS.
  final int? appleId;

  String get dedupeKey {
    final feed = feedUrl.trim().toLowerCase();
    if (feed.isNotEmpty) return feed;
    if (appleId != null) return 'apple:$appleId';
    return 'title:${title.trim().toLowerCase()}';
  }
}
