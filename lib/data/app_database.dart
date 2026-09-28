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

  String? get imageUrl => episode.imageUrl ?? podcast.imageUrl;
}

@DriftDatabase(tables: [Podcasts, Episodes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(driftDatabase(name: 'podavio'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(podcasts, podcasts.preferred);
        await migrator.addColumn(episodes, episodes.downloadedAt);
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
        await (update(
          podcasts,
        )..where((table) => table.id.equals(podcastId))).write(
          PodcastsCompanion(
            title: Value(draft.title),
            author: Value(draft.author),
            description: Value(draft.description),
            imageUrl: Value(draft.imageUrl),
            link: Value(draft.link),
            refreshedAt: Value(DateTime.now()),
          ),
        );
      }

      final known =
          await (selectOnly(episodes)
                ..addColumns([episodes.id, episodes.guid])
                ..where(episodes.podcastId.equals(podcastId)))
              .get();
      final idsByGuid = {
        for (final row in known)
          row.read(episodes.guid)!: row.read(episodes.id)!,
      };
      final fresh = <EpisodesCompanion>[];
      final changed = <({int id, EpisodeDraft episode})>[];
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
          changed.add((id: existingId, episode: episode));
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
    final stored = await (select(
      episodes,
    )..where((table) => table.podcastId.equals(id))).get();
    final paths = stored
        .map((episode) => episode.downloadPath)
        .whereType<String>()
        .toList();
    await (delete(episodes)..where((table) => table.podcastId.equals(id))).go();
    await (delete(podcasts)..where((table) => table.id.equals(id))).go();
    return paths;
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
