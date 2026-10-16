import 'chapters_parser.dart';

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
    this.chaptersUrl,
    this.chapters = const [],
  });

  final String guid;
  final String title;
  final String description;
  final String audioUrl;
  final String? mimeType;
  final int? durationSeconds;
  final DateTime? publishedAt;
  final String? imageUrl;
  final String? chaptersUrl;
  final List<ChapterDraft> chapters;
}

class SubscribeResult {
  const SubscribeResult({required this.podcastId, required this.created});

  final int podcastId;
  final bool created;
}

/// Résultat de l’enregistrement d’un flux.
class SavedFeed {
  const SavedFeed({required this.podcastId, required this.newEpisodeIds});

  final int podcastId;

  /// Épisodes dont le guid vient d’apparaître sur un abonnement déjà suivi.
  ///
  /// Vide au premier ajout, pour un aperçu, ou quand aucun guid n’est nouveau.
  final List<int> newEpisodeIds;
}

class SubscribeFailure {
  const SubscribeFailure({required this.feedUrl, required this.message});

  final String feedUrl;
  final String message;
}

class RefreshReport {
  const RefreshReport({
    required this.total,
    this.failures = const [],
    this.arrivals = const [],
  });

  final int total;
  final List<SubscribeFailure> failures;

  /// Podcasts qui viennent de publier, et dont la notification est activée.
  final List<NewEpisodeArrival> arrivals;

  int get failed => failures.length;
}

/// Nouveaux épisodes d’un abonnement déjà suivi, prêts à être annoncés.
class NewEpisodeArrival {
  const NewEpisodeArrival({
    required this.podcastId,
    required this.title,
    required this.count,
  });

  final int podcastId;
  final String title;
  final int count;
}

/// Un abonnement déjà suivi, maintenu à jour, et que l’utilisateur a demandé
/// à suivre dans Notifications, sans l’avoir coupé sur le podcast.
bool shouldNotifyNewEpisodes({
  required bool notifyNewEpisodes,
  required bool keepUpdated,
  required bool episodeNotification,
  required int newCount,
}) {
  return notifyNewEpisodes &&
      keepUpdated &&
      episodeNotification &&
      newCount > 0;
}

class PodcastStats {
  const PodcastStats({
    required this.episodeCount,
    required this.unreadCount,
    required this.startedCount,
    required this.completedCount,
    required this.inProgressCount,
    required this.favoriteCount,
    required this.downloadCount,
    required this.downloadBytes,
    required this.listenedSeconds,
    required this.totalDurationSeconds,
    required this.averageDurationSeconds,
    required this.releaseInterval,
    required this.lastPublishedAt,
    required this.nextEpisodeAt,
  });

  final int episodeCount;
  final int unreadCount;
  final int startedCount;
  final int completedCount;
  final int inProgressCount;
  final int favoriteCount;
  final int downloadCount;
  final int downloadBytes;
  final int listenedSeconds;
  final int totalDurationSeconds;
  final int? averageDurationSeconds;
  final Duration? releaseInterval;
  final DateTime? lastPublishedAt;
  final DateTime? nextEpisodeAt;
}

class SubscriptionStat {
  const SubscriptionStat({
    required this.podcastId,
    required this.title,
    required this.author,
    required this.imageUrl,
    required this.episodeCount,
    required this.completedCount,
    required this.startedCount,
    required this.listenedSeconds,
    required this.downloadCount,
  });

  final int podcastId;
  final String title;
  final String author;
  final String? imageUrl;
  final int episodeCount;
  final int completedCount;
  final int startedCount;
  final int listenedSeconds;
  final int downloadCount;

  double get progress =>
      episodeCount == 0 ? 0 : (completedCount / episodeCount).clamp(0.0, 1.0);
}

class YearStat {
  const YearStat({
    required this.year,
    required this.listenedSeconds,
    required this.startedCount,
    required this.completedCount,
    required this.months,
  });

  final int year;
  final int listenedSeconds;
  final int startedCount;
  final int completedCount;
  final List<MonthStat> months;
}

class MonthStat {
  const MonthStat({
    required this.year,
    required this.month,
    required this.listenedSeconds,
    required this.startedCount,
    required this.completedCount,
  });

  final int year;
  final int month;
  final int listenedSeconds;
  final int startedCount;
  final int completedCount;
}

class DownloadStat {
  const DownloadStat({
    required this.podcastId,
    required this.title,
    required this.author,
    required this.imageUrl,
    required this.downloadCount,
    required this.downloadBytes,
  });

  final int podcastId;
  final String title;
  final String author;
  final String? imageUrl;
  final int downloadCount;
  final int downloadBytes;
}

class LibraryStats {
  const LibraryStats({
    required this.subscriptions,
    required this.years,
    required this.downloads,
    required this.totalListenedSeconds,
    required this.totalDownloadBytes,
    required this.totalDownloadCount,
    required this.podcastCount,
    required this.episodeCount,
  });

  final List<SubscriptionStat> subscriptions;
  final List<YearStat> years;
  final List<DownloadStat> downloads;
  final int totalListenedSeconds;
  final int totalDownloadBytes;
  final int totalDownloadCount;
  final int podcastCount;
  final int episodeCount;
}
