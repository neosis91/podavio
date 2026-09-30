import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'models.dart';

part 'app_database.g.dart';

class Podcasts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get feedUrl => text().unique()();
  TextColumn get title => text()();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get link => text().nullable()();
  DateTimeColumn get subscribedAt => dateTime()();
  DateTimeColumn get refreshedAt => dateTime().nullable()();
  BoolColumn get preferred => boolean().withDefault(const Constant(false))();
}

class Episodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get podcastId =>
      integer().references(Podcasts, #id, onDelete: KeyAction.cascade)();
  TextColumn get guid => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get audioUrl => text()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  BoolColumn get played => boolean().withDefault(const Constant(false))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  TextColumn get downloadPath => text().nullable()();
  IntColumn get queueIndex => integer().nullable()();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  DateTimeColumn get downloadedAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {podcastId, guid},
  ];
}

class EpisodeEntry {
  const EpisodeEntry({required this.episode, required this.podcast});

  final Episode episode;
  final Podcast podcast;

  /// URL distante de la jaquette (épisode, sinon podcast).
  String? get imageUrl {
    final episodeImage = episode.imageUrl?.trim();
    if (episodeImage != null && episodeImage.isNotEmpty) return episodeImage;
    final podcastImage = podcast.imageUrl?.trim();
    if (podcastImage == null || podcastImage.isEmpty) return null;
    return podcastImage;
  }

  /// Fichier local de la jaquette, s’il a déjà été téléchargé.
  String? get imagePath {
    final episodeImage = episode.imageUrl?.trim();
    if (episodeImage != null && episodeImage.isNotEmpty) {
      return episode.imagePath;
    }
    return podcast.imagePath;
  }
}

@DriftDatabase(tables: [Podcasts, Episodes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(driftDatabase(name: 'podavio'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(podcasts, podcasts.preferred);
        await migrator.addColumn(episodes, episodes.downloadedAt);
      }
      if (from < 3) {
        await migrator.addColumn(podcasts, podcasts.imagePath);
        await migrator.addColumn(episodes, episodes.imagePath);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Stream<List<Podcast>> watchPodcasts() {
    return (select(
      podcasts,
    )..orderBy([(table) => OrderingTerm.asc(table.title)])).watch();
  }

  /// Preferred subscriptions first, then the others by title.
  Stream<List<Podcast>> watchPodcastsByPreference() {
    return (select(podcasts)..orderBy([
          (table) => OrderingTerm.desc(table.preferred),
          (table) => OrderingTerm.asc(table.title),
        ]))
        .watch();
  }

  Future<void> setPodcastPreferred(int id, {required bool preferred}) {
    return (update(podcasts)..where((table) => table.id.equals(id))).write(
      PodcastsCompanion(preferred: Value(preferred)),
    );
  }

  Stream<List<EpisodeEntry>> watchInProgress({int limit = 15}) {
    return _episodeWindow(inProgressOnly: true, limit: limit).watch();
  }

  Stream<List<EpisodeEntry>> watchFreshEpisodes({int limit = 16}) {
    return _episodeWindow(freshOnly: true, limit: limit).watch();
  }

  Stream<List<EpisodeEntry>> watchRecentDownloads({int limit = 12}) {
    return _episodeWindow(recentDownloads: true, limit: limit).watch();
  }

  Future<List<EpisodeEntry>> randomEpisodes({int limit = 12}) {
    return _episodeWindow(
      unplayedOnly: true,
      randomOrder: true,
      limit: limit,
    ).get();
  }

  Future<List<Podcast>> listPodcasts() {
    return (select(
      podcasts,
    )..orderBy([(table) => OrderingTerm.asc(table.title)])).get();
  }

  Stream<Podcast?> watchPodcast(int id) {
    return (select(
      podcasts,
    )..where((table) => table.id.equals(id))).watchSingleOrNull();
  }

  Future<Podcast?> getPodcast(int id) {
    return (select(
      podcasts,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<Podcast?> findByFeedUrl(String feedUrl) {
    return (select(
      podcasts,
    )..where((table) => table.feedUrl.equals(feedUrl))).getSingleOrNull();
  }

  Stream<int> watchUnreadCount() {
    final count = episodes.id.count();
    final query = selectOnly(episodes)
      ..addColumns([count])
      ..where(episodes.played.equals(false));
    return query.watch().map((rows) => rows.single.read(count) ?? 0);
  }

  Stream<Map<int, int>> watchUnreadCountsByPodcast() {
    final count = episodes.id.count();
    final query = selectOnly(episodes)
      ..addColumns([episodes.podcastId, count])
      ..where(episodes.played.equals(false))
      ..groupBy([episodes.podcastId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(episodes.podcastId)!: row.read(count) ?? 0,
      },
    );
  }

  Stream<int> watchQueueCount() {
    final count = episodes.id.count();
    final query = selectOnly(episodes)
      ..addColumns([count])
      ..where(episodes.queueIndex.isNotNull());
    return query.watch().map((rows) => rows.single.read(count) ?? 0);
  }

  Stream<List<EpisodeEntry>> watchEpisodes({
    bool unreadOnly = false,
    bool favoritesOnly = false,
    bool downloadsOnly = false,
    bool queuedOnly = false,
    bool historyOnly = false,
    int? podcastId,
    int? episodeId,
  }) {
    return _episodeQuery(
      unreadOnly: unreadOnly,
      favoritesOnly: favoritesOnly,
      downloadsOnly: downloadsOnly,
      queuedOnly: queuedOnly,
      historyOnly: historyOnly,
      podcastId: podcastId,
      episodeId: episodeId,
    ).watch();
  }

  Stream<EpisodeEntry?> watchEpisode(int id) {
    return _episodeQuery(episodeId: id).watchSingleOrNull();
  }

  Future<EpisodeEntry?> getEpisode(int id) {
    return _episodeQuery(episodeId: id).getSingleOrNull();
  }

  Future<EpisodeEntry?> nextInQueue() async {
    final items = await _episodeQuery(queuedOnly: true).get();
    if (items.isEmpty) return null;
    return items.first;
  }

  Selectable<EpisodeEntry> _episodeQuery({
    bool unreadOnly = false,
    bool favoritesOnly = false,
    bool downloadsOnly = false,
    bool queuedOnly = false,
    bool historyOnly = false,
    int? podcastId,
    int? episodeId,
  }) {
    final query = select(episodes)
        .join([innerJoin(podcasts, podcasts.id.equalsExp(episodes.podcastId))]);
    if (unreadOnly) query.where(episodes.played.equals(false));
    if (favoritesOnly) query.where(episodes.favorite.equals(true));
    if (downloadsOnly) query.where(episodes.downloadPath.isNotNull());
    if (queuedOnly) query.where(episodes.queueIndex.isNotNull());
    if (historyOnly) query.where(episodes.lastPlayedAt.isNotNull());
    if (podcastId != null) query.where(episodes.podcastId.equals(podcastId));
    if (episodeId != null) query.where(episodes.id.equals(episodeId));

    if (queuedOnly) {
      query.orderBy([OrderingTerm.asc(episodes.queueIndex)]);
    } else if (historyOnly) {
      query.orderBy([OrderingTerm.desc(episodes.lastPlayedAt)]);
    } else {
      query.orderBy([OrderingTerm.desc(episodes.publishedAt)]);
    }

    return query.map(
      (row) => EpisodeEntry(
        episode: row.readTable(episodes),
        podcast: row.readTable(podcasts),
      ),
    );
  }

  /// List rows without show notes. [limit] keeps the read to the visible page.
  Stream<List<EpisodeEntry>> watchEpisodeWindow({
    bool unreadOnly = false,
    bool favoritesOnly = false,
    bool downloadsOnly = false,
    bool queuedOnly = false,
    bool historyOnly = false,
    int? podcastId,
    String search = '',
    int? limit,
  }) {
    return _episodeWindow(
      unreadOnly: unreadOnly,
      favoritesOnly: favoritesOnly,
      downloadsOnly: downloadsOnly,
      queuedOnly: queuedOnly,
      historyOnly: historyOnly,
      podcastId: podcastId,
      search: search,
      limit: limit,
    ).watch();
  }

  Selectable<EpisodeEntry> _episodeWindow({
    bool unreadOnly = false,
    bool favoritesOnly = false,
    bool downloadsOnly = false,
    bool queuedOnly = false,
    bool historyOnly = false,
    bool inProgressOnly = false,
    bool freshOnly = false,
    bool recentDownloads = false,
    bool unplayedOnly = false,
    bool randomOrder = false,
    int? podcastId,
    String search = '',
    int? limit,
  }) {
    final query = selectOnly(episodes)
      ..addColumns([
        episodes.id,
        episodes.podcastId,
        episodes.guid,
        episodes.title,
        episodes.audioUrl,
        episodes.mimeType,
        episodes.durationSeconds,
        episodes.publishedAt,
        episodes.imageUrl,
        episodes.imagePath,
        episodes.positionMs,
        episodes.played,
        episodes.favorite,
        episodes.downloadPath,
        episodes.queueIndex,
        episodes.lastPlayedAt,
        episodes.downloadedAt,
        podcasts.id,
        podcasts.feedUrl,
        podcasts.title,
        podcasts.author,
        podcasts.imageUrl,
        podcasts.imagePath,
        podcasts.link,
        podcasts.subscribedAt,
        podcasts.refreshedAt,
        podcasts.preferred,
      ])
      ..join([innerJoin(podcasts, podcasts.id.equalsExp(episodes.podcastId))]);
    if (unreadOnly) query.where(episodes.played.equals(false));
    if (favoritesOnly) query.where(episodes.favorite.equals(true));
    if (downloadsOnly) query.where(episodes.downloadPath.isNotNull());
    if (queuedOnly) query.where(episodes.queueIndex.isNotNull());
    if (historyOnly) query.where(episodes.lastPlayedAt.isNotNull());
    if (inProgressOnly) {
      query.where(
        episodes.played.equals(false) &
            episodes.positionMs.isBiggerThanValue(0),
      );
    }
    if (freshOnly) {
      query.where(
        episodes.played.equals(false) & episodes.positionMs.equals(0),
      );
    }
    if (recentDownloads) query.where(episodes.downloadPath.isNotNull());
    if (unplayedOnly) query.where(episodes.played.equals(false));
    if (podcastId != null) query.where(episodes.podcastId.equals(podcastId));
    final needle = search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      query.where(
        episodes.title.lower().contains(needle) |
            podcasts.title.lower().contains(needle) |
            episodes.description.lower().contains(needle),
      );
    }
    if (randomOrder) {
      query.orderBy([OrderingTerm.random()]);
    } else if (inProgressOnly) {
      query.orderBy([OrderingTerm.desc(episodes.lastPlayedAt)]);
    } else if (recentDownloads) {
      query.orderBy([
        OrderingTerm.desc(episodes.downloadedAt),
        OrderingTerm.desc(episodes.publishedAt),
      ]);
    } else if (queuedOnly) {
      query.orderBy([OrderingTerm.asc(episodes.queueIndex)]);
    } else if (historyOnly) {
      query.orderBy([OrderingTerm.desc(episodes.lastPlayedAt)]);
    } else {
      query.orderBy([OrderingTerm.desc(episodes.publishedAt)]);
    }
    if (limit != null) query.limit(limit);
    return query.map(
      (row) => EpisodeEntry(
        episode: Episode(
          id: row.read(episodes.id)!,
          podcastId: row.read(episodes.podcastId)!,
          guid: row.read(episodes.guid)!,
          title: row.read(episodes.title)!,
          description: '',
          audioUrl: row.read(episodes.audioUrl)!,
          mimeType: row.read(episodes.mimeType),
          durationSeconds: row.read(episodes.durationSeconds),
          publishedAt: row.read(episodes.publishedAt),
          imageUrl: row.read(episodes.imageUrl),
          imagePath: row.read(episodes.imagePath),
          positionMs: row.read(episodes.positionMs)!,
          played: row.read(episodes.played)!,
          favorite: row.read(episodes.favorite)!,
          downloadPath: row.read(episodes.downloadPath),
          queueIndex: row.read(episodes.queueIndex),
          lastPlayedAt: row.read(episodes.lastPlayedAt),
          downloadedAt: row.read(episodes.downloadedAt),
        ),
        podcast: Podcast(
          id: row.read(podcasts.id)!,
          feedUrl: row.read(podcasts.feedUrl)!,
          title: row.read(podcasts.title)!,
          author: row.read(podcasts.author)!,
          description: '',
          imageUrl: row.read(podcasts.imageUrl),
          imagePath: row.read(podcasts.imagePath),
          link: row.read(podcasts.link),
          subscribedAt: row.read(podcasts.subscribedAt)!,
          refreshedAt: row.read(podcasts.refreshedAt),
          preferred: row.read(podcasts.preferred)!,
        ),
      ),
    );
  }

  Future<int> saveFeed(FeedDraft draft) {
    return transaction(() async {
      final existing = await findByFeedUrl(draft.feedUrl);
      final int podcastId;
      if (existing == null) {
        podcastId = await into(podcasts).insert(
          PodcastsCompanion.insert(
            feedUrl: draft.feedUrl,
            title: draft.title,
            author: Value(draft.author),
            description: Value(draft.description),
            imageUrl: Value(draft.imageUrl),
            link: Value(draft.link),
            subscribedAt: DateTime.now(),
            refreshedAt: Value(DateTime.now()),
          ),
        );
      } else {
        podcastId = existing.id;
        final imageChanged = (existing.imageUrl ?? '') != (draft.imageUrl ?? '');
        await (update(
          podcasts,
        )..where((table) => table.id.equals(podcastId))).write(
          PodcastsCompanion(
            title: Value(draft.title),
            author: Value(draft.author),
            description: Value(draft.description),
            imageUrl: Value(draft.imageUrl),
            imagePath: imageChanged ? const Value(null) : const Value.absent(),
            link: Value(draft.link),
            refreshedAt: Value(DateTime.now()),
          ),
        );
      }

      final known =
          await (selectOnly(episodes)
                ..addColumns([episodes.id, episodes.guid, episodes.imageUrl])
                ..where(episodes.podcastId.equals(podcastId)))
              .get();
      final idsByGuid = {
        for (final row in known)
          row.read(episodes.guid)!: row.read(episodes.id)!,
      };
      final imageUrlById = {
        for (final row in known)
          row.read(episodes.id)!: row.read(episodes.imageUrl),
      };
      final fresh = <EpisodesCompanion>[];
      final changed = <({int id, EpisodeDraft episode, bool imageChanged})>[];
      final seen = <String>{};
      for (final episode in draft.episodes) {
        if (!seen.add(episode.guid)) continue;
        final existingId = idsByGuid[episode.guid];
        if (existingId == null) {
          fresh.add(
            EpisodesCompanion.insert(
              podcastId: podcastId,
              guid: episode.guid,
              title: episode.title,
              description: Value(episode.description),
              audioUrl: episode.audioUrl,
              mimeType: Value(episode.mimeType),
              durationSeconds: Value(episode.durationSeconds),
              publishedAt: Value(episode.publishedAt),
              imageUrl: Value(episode.imageUrl),
            ),
          );
        } else {
          final previous = imageUrlById[existingId];
          changed.add((
            id: existingId,
            episode: episode,
            imageChanged: (previous ?? '') != (episode.imageUrl ?? ''),
          ));
        }
      }

      if (fresh.isNotEmpty || changed.isNotEmpty) {
        await batch((statement) {
          if (fresh.isNotEmpty) statement.insertAll(episodes, fresh);
          for (final item in changed) {
            statement.update(
              episodes,
              EpisodesCompanion(
                title: Value(item.episode.title),
                description: Value(item.episode.description),
                audioUrl: Value(item.episode.audioUrl),
                mimeType: Value(item.episode.mimeType),
                durationSeconds: Value(item.episode.durationSeconds),
                publishedAt: Value(item.episode.publishedAt),
                imageUrl: Value(item.episode.imageUrl),
                imagePath: item.imageChanged
                    ? const Value(null)
                    : const Value.absent(),
              ),
              where: (table) => table.id.equals(item.id),
            );
          }
        });
      }
      return podcastId;
    });
  }

  Future<List<String>> deletePodcast(int id) async {
    final podcast = await (select(
      podcasts,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    final stored = await (select(
      episodes,
    )..where((table) => table.podcastId.equals(id))).get();
    final paths = <String>[
      if (podcast?.imagePath != null) podcast!.imagePath!,
      for (final episode in stored) ...[
        if (episode.downloadPath != null) episode.downloadPath!,
        if (episode.imagePath != null) episode.imagePath!,
      ],
    ];
    await (delete(episodes)..where((table) => table.podcastId.equals(id))).go();
    await (delete(podcasts)..where((table) => table.id.equals(id))).go();
    return paths;
  }

  Future<void> setPodcastImagePath(int id, String? path) {
    return (update(podcasts)..where((table) => table.id.equals(id))).write(
      PodcastsCompanion(imagePath: Value(path)),
    );
  }

  Future<void> setPodcastImagePaths(
    List<({int id, String path})> updates,
  ) {
    if (updates.isEmpty) return Future.value();
    return batch((statement) {
      for (final item in updates) {
        statement.update(
          podcasts,
          PodcastsCompanion(imagePath: Value(item.path)),
          where: (table) => table.id.equals(item.id),
        );
      }
    });
  }

  Future<void> setEpisodeImagePath(int id, String? path) {
    return (update(episodes)..where((table) => table.id.equals(id))).write(
      EpisodesCompanion(imagePath: Value(path)),
    );
  }

  Future<List<Podcast>> podcastsMissingCovers() {
    return (select(
      podcasts,
    )..where((table) => table.imageUrl.isNotNull() & table.imagePath.isNull()))
        .get();
  }

  Future<void> setPosition(int id, int positionMs) {
    return (update(episodes)..where((table) => table.id.equals(id))).write(
      EpisodesCompanion(
        positionMs: Value(positionMs),
        lastPlayedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setPlayed(int id, {required bool played}) {
    return (update(episodes)..where((table) => table.id.equals(id))).write(
      EpisodesCompanion(
        played: Value(played),
        positionMs: played ? const Value(0) : const Value.absent(),
      ),
    );
  }

  Future<void> markAllPlayed() {
    return (update(
      episodes,
    )..where((table) => table.played.equals(false))).write(
      const EpisodesCompanion(played: Value(true), positionMs: Value(0)),
    );
  }

  Future<void> setFavorite(int id, {required bool favorite}) {
    return (update(episodes)..where((table) => table.id.equals(id))).write(
      EpisodesCompanion(favorite: Value(favorite)),
    );
  }

  Future<List<Episode>> downloadedEpisodes() {
    return (select(
      episodes,
    )..where((table) => table.downloadPath.isNotNull())).get();
  }

  Future<List<Episode>> episodesForPodcast(int podcastId) {
    return (select(episodes)
          ..where((table) => table.podcastId.equals(podcastId))
          ..orderBy([(table) => OrderingTerm.asc(table.publishedAt)]))
        .get();
  }

  Future<PodcastStats> podcastStats(int podcastId) async {
    final items = await episodesForPodcast(podcastId);
    var unread = 0;
    var started = 0;
    var completed = 0;
    var inProgress = 0;
    var favorites = 0;
    var downloads = 0;
    var listenedSeconds = 0;
    var totalDuration = 0;
    var durationSamples = 0;
    final published = <DateTime>[];

    for (final episode in items) {
      if (!episode.played) unread++;
      if (episode.played) completed++;
      if (!episode.played && episode.positionMs > 0) inProgress++;
      if (episode.played ||
          episode.positionMs > 0 ||
          episode.lastPlayedAt != null) {
        started++;
      }
      if (episode.favorite) favorites++;
      if (episode.downloadPath != null) downloads++;

      final duration = episode.durationSeconds;
      if (duration != null && duration > 0) {
        totalDuration += duration;
        durationSamples++;
      }

      if (episode.played) {
        listenedSeconds += duration ?? (episode.positionMs ~/ 1000);
      } else if (episode.positionMs > 0) {
        listenedSeconds += episode.positionMs ~/ 1000;
      }

      final publishedAt = episode.publishedAt;
      if (publishedAt != null) published.add(publishedAt.toUtc());
    }

    published.sort();
    Duration? interval;
    if (published.length >= 3) {
      final gaps = <int>[];
      final start = published.length > 12 ? published.length - 12 : 1;
      for (var i = start; i < published.length; i++) {
        final days = published[i].difference(published[i - 1]).inHours;
        if (days > 0) gaps.add(days);
      }
      if (gaps.isNotEmpty) {
        gaps.sort();
        interval = Duration(hours: gaps[gaps.length ~/ 2]);
      }
    } else if (published.length == 2) {
      final hours = published[1].difference(published[0]).inHours;
      if (hours > 0) interval = Duration(hours: hours);
    }

    final lastPublished = published.isEmpty ? null : published.last;
    final nextEpisode = lastPublished == null || interval == null
        ? null
        : lastPublished.add(interval);

    return PodcastStats(
      episodeCount: items.length,
      unreadCount: unread,
      startedCount: started,
      completedCount: completed,
      inProgressCount: inProgress,
      favoriteCount: favorites,
      downloadCount: downloads,
      downloadBytes: 0,
      listenedSeconds: listenedSeconds,
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
    final allEpisodes = await select(episodes).get();
    final byPodcast = <int, List<Episode>>{};
    for (final episode in allEpisodes) {
      (byPodcast[episode.podcastId] ??= []).add(episode);
    }

    final subscriptions = <SubscriptionStat>[];
    final years = <int, _YearBucket>{};
    final downloads = <DownloadStat>[];
    var totalListened = 0;
    var totalDownloadCount = 0;

    for (final podcast in podcastList) {
      final items = byPodcast[podcast.id] ?? const <Episode>[];
      var completed = 0;
      var started = 0;
      var listened = 0;
      var downloadCount = 0;

      for (final episode in items) {
        final listenedSeconds = _episodeListenedSeconds(episode);
        final startedEpisode =
            episode.played ||
            episode.positionMs > 0 ||
            episode.lastPlayedAt != null;
        if (episode.played) completed++;
        if (startedEpisode) started++;
        listened += listenedSeconds;
        if (episode.downloadPath != null) downloadCount++;

        final playedAt = episode.lastPlayedAt;
        if (startedEpisode && playedAt != null) {
          final local = playedAt.toLocal();
          final bucket = years.putIfAbsent(local.year, _YearBucket.new);
          bucket.listenedSeconds += listenedSeconds;
          bucket.startedCount++;
          if (episode.played) bucket.completedCount++;
          final monthBucket = bucket.months.putIfAbsent(
            local.month,
            _MonthBucket.new,
          );
          monthBucket.listenedSeconds += listenedSeconds;
          monthBucket.startedCount++;
          if (episode.played) monthBucket.completedCount++;
        }
      }

      totalListened += listened;
      totalDownloadCount += downloadCount;

      subscriptions.add(
        SubscriptionStat(
          podcastId: podcast.id,
          title: podcast.title,
          author: podcast.author,
          imageUrl: podcast.imageUrl,
          episodeCount: items.length,
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

    return LibraryStats(
      subscriptions: subscriptions,
      years: yearStats,
      downloads: downloads,
      totalListenedSeconds: totalListened,
      totalDownloadBytes: 0,
      totalDownloadCount: totalDownloadCount,
      podcastCount: podcastList.length,
      episodeCount: allEpisodes.length,
    );
  }

  int _episodeListenedSeconds(Episode episode) {
    if (episode.played) {
      return episode.durationSeconds ?? (episode.positionMs ~/ 1000);
    }
    if (episode.positionMs > 0) return episode.positionMs ~/ 1000;
    return 0;
  }

  Future<void> updateDownloadPath(int id, String path) {
    return (update(episodes)..where((table) => table.id.equals(id))).write(
      EpisodesCompanion(downloadPath: Value(path)),
    );
  }

  Future<void> setDownloadPath(int id, String? path) {
    return (update(episodes)..where((table) => table.id.equals(id))).write(
      EpisodesCompanion(
        downloadPath: Value(path),
        downloadedAt: Value(path == null ? null : DateTime.now()),
      ),
    );
  }

  Future<void> addToQueue(int episodeId) async {
    final episode = await (select(
      episodes,
    )..where((table) => table.id.equals(episodeId))).getSingle();
    if (episode.queueIndex != null) return;
    final max = episodes.queueIndex.max();
    final row =
        await (selectOnly(episodes)
              ..addColumns([max])
              ..where(episodes.queueIndex.isNotNull()))
            .getSingle();
    final next = (row.read(max) ?? -1) + 1;
    await (update(episodes)..where((table) => table.id.equals(episodeId)))
        .write(EpisodesCompanion(queueIndex: Value(next)));
  }

  Future<void> removeFromQueue(int episodeId) {
    return (update(episodes)..where((table) => table.id.equals(episodeId)))
        .write(const EpisodesCompanion(queueIndex: Value(null)));
  }

  Future<void> setQueueOrder(List<int> episodeIds) {
    return transaction(() async {
      for (var index = 0; index < episodeIds.length; index++) {
        await (update(episodes)
              ..where((table) => table.id.equals(episodeIds[index])))
            .write(EpisodesCompanion(queueIndex: Value(index)));
      }
    });
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

