part of '../app_database.dart';

mixin _StatsQueries on _$AppDatabase, _PodcastQueries {
  /// Signal léger pour invalider `podcastStatsProvider` sans charger toute la liste.
  Stream<(int, int, int, int, int, int)> watchPodcastStatsSignal(int podcastId) {
    return customSelect(
      'SELECT COUNT(*) AS c, '
      'COALESCE(SUM(position_ms), 0) AS s, '
      'COALESCE(MAX(id), 0) AS m, '
      'COALESCE(SUM(CASE WHEN played = 1 THEN 1 ELSE 0 END), 0) AS p, '
      'COALESCE(SUM(CASE WHEN favorite = 1 THEN 1 ELSE 0 END), 0) AS f, '
      'COALESCE(SUM(CASE WHEN download_path IS NOT NULL THEN 1 ELSE 0 END), 0) '
      'AS d '
      'FROM episodes WHERE podcast_id = ?',
      variables: [Variable.withInt(podcastId)],
      readsFrom: {episodes},
    ).watch().map((rows) {
      final row = rows.single;
      return (
        row.read<int>('c'),
        row.read<int>('s'),
        row.read<int>('m'),
        row.read<int>('p'),
        row.read<int>('f'),
        row.read<int>('d'),
      );
    });
  }

  /// Signal bibliothèque (agrégats) — évite de se rattacher à `podcastsProvider`
  /// (invalidé aussi par `image_path`).
  Stream<(int, int, int, int, int, int)> watchLibraryStatsSignal() {
    return customSelect(
      'SELECT '
      '(SELECT COUNT(*) FROM podcasts WHERE subscribed = 1) AS podcast_count, '
      '(SELECT COUNT(*) FROM episodes) AS episode_count, '
      '(SELECT COALESCE(SUM(position_ms), 0) FROM episodes) AS position_sum, '
      '(SELECT COALESCE(SUM(CASE WHEN played = 1 THEN 1 ELSE 0 END), 0) '
      'FROM episodes) AS played_sum, '
      '(SELECT COALESCE(SUM(CASE WHEN download_path IS NOT NULL THEN 1 ELSE 0 END), 0) '
      'FROM episodes) AS download_sum, '
      '(SELECT COALESCE(MAX(id), 0) FROM episodes) AS max_id',
      readsFrom: {podcasts, episodes},
    ).watch().map((rows) {
      final row = rows.single;
      return (
        row.read<int>('podcast_count'),
        row.read<int>('episode_count'),
        row.read<int>('position_sum'),
        row.read<int>('played_sum'),
        row.read<int>('download_sum'),
        row.read<int>('max_id'),
      );
    });
  }

  Future<PodcastStats> podcastStats(int podcastId) async {
    final agg = await customSelect(
      'SELECT '
      'COUNT(*) AS episode_count, '
      'SUM(CASE WHEN played = 0 THEN 1 ELSE 0 END) AS unread_count, '
      'SUM(CASE WHEN played = 1 THEN 1 ELSE 0 END) AS completed_count, '
      'SUM(CASE WHEN played = 0 AND position_ms > 0 THEN 1 ELSE 0 END) '
      'AS in_progress_count, '
      'SUM(CASE WHEN played = 1 OR position_ms > 0 OR last_played_at IS NOT NULL '
      'THEN 1 ELSE 0 END) AS started_count, '
      'SUM(CASE WHEN favorite = 1 THEN 1 ELSE 0 END) AS favorite_count, '
      'SUM(CASE WHEN download_path IS NOT NULL THEN 1 ELSE 0 END) '
      'AS download_count, '
      'SUM(CASE '
      'WHEN played = 1 THEN COALESCE(duration_seconds, position_ms / 1000) '
      'WHEN position_ms > 0 THEN position_ms / 1000 '
      'ELSE 0 END) AS listened_seconds, '
      'SUM(CASE WHEN duration_seconds IS NOT NULL AND duration_seconds > 0 '
      'THEN duration_seconds ELSE 0 END) AS total_duration, '
      'SUM(CASE WHEN duration_seconds IS NOT NULL AND duration_seconds > 0 '
      'THEN 1 ELSE 0 END) AS duration_samples '
      'FROM episodes WHERE podcast_id = ?',
      variables: [Variable.withInt(podcastId)],
      readsFrom: {episodes},
    ).getSingle();

    final episodeCount = agg.read<int>('episode_count');
    final totalDuration = agg.read<int?>('total_duration') ?? 0;
    final durationSamples = agg.read<int?>('duration_samples') ?? 0;

    // Intervalle de parution : projection `published_at` uniquement.
    final publishedQuery = selectOnly(episodes)
      ..addColumns([episodes.publishedAt])
      ..where(
        episodes.podcastId.equals(podcastId) & episodes.publishedAt.isNotNull(),
      )
      ..orderBy([OrderingTerm.asc(episodes.publishedAt)]);
    final published = [
      for (final row in await publishedQuery.get())
        row.read(episodes.publishedAt)!.toUtc(),
    ];

    final interval = _releaseInterval(published);
    final lastPublished = published.isEmpty ? null : published.last;
    final nextEpisode = lastPublished == null || interval == null
        ? null
        : lastPublished.add(interval);

    return PodcastStats(
      episodeCount: episodeCount,
      unreadCount: agg.read<int?>('unread_count') ?? 0,
      startedCount: agg.read<int?>('started_count') ?? 0,
      completedCount: agg.read<int?>('completed_count') ?? 0,
      inProgressCount: agg.read<int?>('in_progress_count') ?? 0,
      favoriteCount: agg.read<int?>('favorite_count') ?? 0,
      downloadCount: agg.read<int?>('download_count') ?? 0,
      downloadBytes: 0,
      listenedSeconds: agg.read<int?>('listened_seconds') ?? 0,
      totalDurationSeconds: totalDuration,
      averageDurationSeconds: durationSamples == 0
          ? null
          : (totalDuration / durationSamples).round(),
      releaseInterval: interval,
      lastPublishedAt: lastPublished?.toLocal(),
      nextEpisodeAt: nextEpisode?.toLocal(),
    );
  }

  Future<LibraryStats> libraryStats() async {
    final podcastList = await listPodcasts();

    final aggRows = await customSelect(
      'SELECT podcast_id, '
      'COUNT(*) AS episode_count, '
      'SUM(CASE WHEN played = 1 THEN 1 ELSE 0 END) AS completed_count, '
      'SUM(CASE WHEN played = 1 OR position_ms > 0 OR last_played_at IS NOT NULL '
      'THEN 1 ELSE 0 END) AS started_count, '
      'SUM(CASE '
      'WHEN played = 1 THEN COALESCE(duration_seconds, position_ms / 1000) '
      'WHEN position_ms > 0 THEN position_ms / 1000 '
      'ELSE 0 END) AS listened_seconds, '
      'SUM(CASE WHEN download_path IS NOT NULL THEN 1 ELSE 0 END) '
      'AS download_count '
      'FROM episodes GROUP BY podcast_id',
      readsFrom: {episodes},
    ).get();
    final byPodcast = {
      for (final row in aggRows) row.read<int>('podcast_id'): row,
    };

    // Historique année/mois : colonnes utiles, abonnements seulement.
    final historyQuery = selectOnly(episodes).join([
      innerJoin(
        podcasts,
        podcasts.id.equalsExp(episodes.podcastId),
        useColumns: false,
      ),
    ])
      ..addColumns([
        episodes.played,
        episodes.positionMs,
        episodes.durationSeconds,
        episodes.lastPlayedAt,
      ])
      ..where(
        episodes.lastPlayedAt.isNotNull() & podcasts.subscribed.equals(true),
      );
    final years = <int, _YearBucket>{};
    for (final row in await historyQuery.get()) {
      final played = row.read(episodes.played)!;
      final positionMs = row.read(episodes.positionMs)!;
      final durationSeconds = row.read(episodes.durationSeconds);
      final playedAt = row.read(episodes.lastPlayedAt)!;
      final listenedSeconds = _listenedSeconds(
        played: played,
        positionMs: positionMs,
        durationSeconds: durationSeconds,
      );
      final local = playedAt.toLocal();
      final bucket = years.putIfAbsent(local.year, _YearBucket.new);
      bucket.listenedSeconds += listenedSeconds;
      bucket.startedCount++;
      if (played) bucket.completedCount++;
      final monthBucket = bucket.months.putIfAbsent(
        local.month,
        _MonthBucket.new,
      );
      monthBucket.listenedSeconds += listenedSeconds;
      monthBucket.startedCount++;
      if (played) monthBucket.completedCount++;
    }

    final subscriptions = <SubscriptionStat>[];
    final downloads = <DownloadStat>[];
    var totalListened = 0;
    var totalDownloadCount = 0;

    for (final podcast in podcastList) {
      final row = byPodcast[podcast.id];
      final count = row?.read<int>('episode_count') ?? 0;
      final completed = row?.read<int?>('completed_count') ?? 0;
      final started = row?.read<int?>('started_count') ?? 0;
      final listened = row?.read<int?>('listened_seconds') ?? 0;
      final downloadCount = row?.read<int?>('download_count') ?? 0;

      totalListened += listened;
      totalDownloadCount += downloadCount;

      subscriptions.add(
        SubscriptionStat(
          podcastId: podcast.id,
          title: podcast.title,
          author: podcast.author,
          imageUrl: podcast.imageUrl,
          episodeCount: count,
          completedCount: completed,
          startedCount: started,
          listenedSeconds: listened,
          downloadCount: downloadCount,
        ),
      );

      if (downloadCount > 0) {
        downloads.add(
          DownloadStat(
            podcastId: podcast.id,
            title: podcast.title,
            author: podcast.author,
            imageUrl: podcast.imageUrl,
            downloadCount: downloadCount,
            downloadBytes: 0,
          ),
        );
      }
    }

    subscriptions.sort((a, b) {
      final byListen = b.listenedSeconds.compareTo(a.listenedSeconds);
      if (byListen != 0) return byListen;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    downloads.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );

    final yearStats =
        years.entries
            .map((entry) {
              final months = [
                for (var month = 1; month <= 12; month++)
                  MonthStat(
                    year: entry.key,
                    month: month,
                    listenedSeconds:
                        entry.value.months[month]?.listenedSeconds ?? 0,
                    startedCount: entry.value.months[month]?.startedCount ?? 0,
                    completedCount:
                        entry.value.months[month]?.completedCount ?? 0,
                  ),
              ];
              return YearStat(
                year: entry.key,
                listenedSeconds: entry.value.listenedSeconds,
                startedCount: entry.value.startedCount,
                completedCount: entry.value.completedCount,
                months: months,
              );
            })
            .toList()
          ..sort((a, b) => b.year.compareTo(a.year));

    // Total global (y compris aperçus non abonnés), comme avant.
    final episodeCount =
        (await customSelect(
              'SELECT COUNT(*) AS c FROM episodes',
              readsFrom: {episodes},
            ).getSingle()).read<int>('c');

    return LibraryStats(
      subscriptions: subscriptions,
      years: yearStats,
      downloads: downloads,
      totalListenedSeconds: totalListened,
      totalDownloadBytes: 0,
      totalDownloadCount: totalDownloadCount,
      podcastCount: podcastList.length,
      episodeCount: episodeCount,
    );
  }

  static Duration? _releaseInterval(List<DateTime> publishedUtc) {
    if (publishedUtc.length >= 3) {
      final gaps = <int>[];
      final start = publishedUtc.length > 12 ? publishedUtc.length - 12 : 1;
      for (var i = start; i < publishedUtc.length; i++) {
        final hours = publishedUtc[i].difference(publishedUtc[i - 1]).inHours;
        if (hours > 0) gaps.add(hours);
      }
      if (gaps.isNotEmpty) {
        gaps.sort();
        return Duration(hours: gaps[gaps.length ~/ 2]);
      }
    } else if (publishedUtc.length == 2) {
      final hours = publishedUtc[1].difference(publishedUtc[0]).inHours;
      if (hours > 0) return Duration(hours: hours);
    }
    return null;
  }

  static int _listenedSeconds({
    required bool played,
    required int positionMs,
    required int? durationSeconds,
  }) {
    if (played) return durationSeconds ?? (positionMs ~/ 1000);
    if (positionMs > 0) return positionMs ~/ 1000;
    return 0;
  }

}
class _YearBucket {
  var listenedSeconds = 0;
  var startedCount = 0;
  var completedCount = 0;
  final months = <int, _MonthBucket>{};
}

class _MonthBucket {
  var listenedSeconds = 0;
  var startedCount = 0;
  var completedCount = 0;
}

