class FeedDraft {
  const FeedDraft({
    required this.feedUrl,
    required this.title,
    required this.author,
    required this.description,
    required this.episodes,
    this.imageUrl,
    this.link,
  });

  final String feedUrl;
  final String title;
  final String author;
  final String description;
  final String? imageUrl;
  final String? link;
  final List<EpisodeDraft> episodes;
}

class EpisodeDraft {
  const EpisodeDraft({
    required this.guid,
    required this.title,
    required this.description,
    required this.audioUrl,
    this.mimeType,
    this.durationSeconds,
    this.publishedAt,
    this.imageUrl,
  });

  final String guid;
  final String title;
  final String description;
  final String audioUrl;
  final String? mimeType;
  final int? durationSeconds;
  final DateTime? publishedAt;
  final String? imageUrl;
}

class SubscribeResult {
  const SubscribeResult({required this.podcastId, required this.created});

  final int podcastId;
  final bool created;
}

class RefreshReport {
  const RefreshReport({required this.total, required this.failed});

  final int total;
  final int failed;
}
