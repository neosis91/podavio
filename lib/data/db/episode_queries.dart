part of '../app_database.dart';

mixin _EpisodeQueries on _$AppDatabase {
  Stream<List<EpisodeEntry>> watchInProgress({int limit = 15}) {
    return _episodeWindow(inProgressOnly: true, limit: limit).watch();
  }

  /// Dernier épisode touché par une lecture (pour reprise au démarrage).
  Future<EpisodeEntry?> lastPlayedEpisode() async {
    final history = await _episodeWindow(historyOnly: true, limit: 1).get();
    if (history.isEmpty) return null;
    return history.first;
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

  Stream<int> watchUnreadCount() {
    final count = episodes.id.count();
    final query = selectOnly(episodes)
      ..addColumns([count])
      ..where(episodes.played.equals(false));
    return query.watch().map((rows) => rows.single.read(count) ?? 0);
  }

  Stream<Map<int, int>> watchUnreadCountsByPodcast() {
    return watchEpisodeCountsByPodcast(unreadOnly: true);
  }

  Stream<Map<int, int>> watchEpisodeCountsByPodcast({
    bool unreadOnly = false,
    bool playedOnly = false,
    bool downloadsOnly = false,
    bool queuedOnly = false,
  }) {
    final count = episodes.id.count();
    final query = selectOnly(episodes)
      ..addColumns([episodes.podcastId, count])
      ..groupBy([episodes.podcastId]);
    if (unreadOnly) query.where(episodes.played.equals(false));
    if (playedOnly) query.where(episodes.played.equals(true));
    if (downloadsOnly) query.where(episodes.downloadPath.isNotNull());
    if (queuedOnly) query.where(episodes.queueIndex.isNotNull());
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

  Future<EpisodeEntry?> nextInQueue({int? afterEpisodeId}) async {
    final items = await _episodeQuery(queuedOnly: true).get();
    if (items.isEmpty) return null;
    if (afterEpisodeId == null) return items.first;
    final index = items.indexWhere((e) => e.episode.id == afterEpisodeId);
    if (index >= 0) {
      if (index + 1 >= items.length) return null;
      return items[index + 1];
    }
    // Épisode courant hors file → premier de la file.
    return items.first;
  }

  Stream<bool> watchHasNextInQueue({int? afterEpisodeId}) {
    return watchEpisodeWindow(queuedOnly: true).map((items) {
      if (items.isEmpty) return false;
      if (afterEpisodeId == null) return true;
      final index = items.indexWhere((e) => e.episode.id == afterEpisodeId);
      if (index >= 0) return index + 1 < items.length;
      return true;
    });
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
        episodes.chaptersUrl,
        episodes.chaptersFetched,
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
        podcasts.autoDownload,
        podcasts.keepUpdated,
        podcasts.subscribed,
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
        episodes.played.equals(false) &
            episodes.positionMs.equals(0) &
            podcasts.subscribed.equals(true),
      );
    }
    if (recentDownloads) query.where(episodes.downloadPath.isNotNull());
    if (unplayedOnly) query.where(episodes.played.equals(false));
    if (podcastId != null) {
      query.where(episodes.podcastId.equals(podcastId));
    } else if (!downloadsOnly &&
        !queuedOnly &&
        !historyOnly &&
        !inProgressOnly &&
        !recentDownloads &&
        !favoritesOnly) {
      // Listes « bibliothèque » : masquer les aperçus Explorer.
      query.where(podcasts.subscribed.equals(true));
    }
    final needle = search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      // Titres seulement (pas description) : LIKE sur le texte long est trop coûteux.
      query.where(
        episodes.title.lower().contains(needle) |
            podcasts.title.lower().contains(needle),
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
          chaptersUrl: row.read(episodes.chaptersUrl),
          chaptersFetched: row.read(episodes.chaptersFetched) ?? false,
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
          autoDownload: row.read(podcasts.autoDownload)!,
          keepUpdated: row.read(podcasts.keepUpdated)!,
          subscribed: row.read(podcasts.subscribed)!,
        ),
      ),
    );
  }

  Future<void> setEpisodeImagePath(int id, String? path) {
    return (update(episodes)..where((table) => table.id.equals(id))).write(
      EpisodesCompanion(imagePath: Value(path)),
    );
  }

  Future<void> setPosition(
    int id,
    int positionMs, {
    bool touchLastPlayed = true,
  }) {
    return (update(episodes)..where((table) => table.id.equals(id))).write(
      EpisodesCompanion(
        positionMs: Value(positionMs),
        lastPlayedAt: touchLastPlayed
            ? Value(DateTime.now())
            : const Value.absent(),
      ),
    );
  }

  /// Écrit uniquement dans `playback_positions` (pas de pulse des listes Drift).
  Future<void> upsertPlaybackPosition(int episodeId, int positionMs) {
    return into(playbackPositions).insertOnConflictUpdate(
      PlaybackPositionsCompanion(
        episodeId: Value(episodeId),
        positionMs: Value(positionMs),
      ),
    );
  }

  Future<int?> playbackPositionMs(int episodeId) async {
    final row = await (select(playbackPositions)
          ..where((table) => table.episodeId.equals(episodeId)))
        .getSingleOrNull();
    return row?.positionMs;
  }

  Future<void> setPlayed(int id, {required bool played}) {
    return transaction(() async {
      await (update(episodes)..where((table) => table.id.equals(id))).write(
        EpisodesCompanion(
          played: Value(played),
          positionMs: played ? const Value(0) : const Value.absent(),
        ),
      );
      if (played) {
        await upsertPlaybackPosition(id, 0);
      }
    });
  }

  Future<void> markAllPlayed() {
    return transaction(() async {
      await (update(
        episodes,
      )..where((table) => table.played.equals(false))).write(
        const EpisodesCompanion(played: Value(true), positionMs: Value(0)),
      );
      await delete(playbackPositions).go();
    });
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
