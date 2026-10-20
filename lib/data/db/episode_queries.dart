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

  Future<List<EpisodeEntry>> subscribedPlayedEpisodes() {
    return _episodeWindow(playedOnly: true).get();
  }

  /// Épisode visé par une action gPodder (guid, sinon URL du média).
  Future<Episode?> episodeForSync({
    required String feedUrl,
    required String audioUrl,
    String guid = '',
  }) async {
    final podcast = await (select(
      podcasts,
    )..where((table) => table.feedUrl.equals(feedUrl))).getSingleOrNull();
    if (podcast != null && guid.isNotEmpty) {
      final byGuid =
          await (select(episodes)..where(
                (table) =>
                    table.podcastId.equals(podcast.id) &
                    table.guid.equals(guid),
              ))
              .getSingleOrNull();
      if (byGuid != null) return byGuid;
    }
    if (podcast != null) {
      final byAudio =
          await (select(episodes)..where(
                (table) =>
                    table.podcastId.equals(podcast.id) &
                    table.audioUrl.equals(audioUrl),
              ))
              .getSingleOrNull();
      if (byAudio != null) return byAudio;
    }
    return (select(episodes)
          ..where((table) => table.audioUrl.equals(audioUrl))
          ..limit(1))
        .getSingleOrNull();
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

  /// Épisode juste avant [beforeEpisodeId] dans la playlist.
  /// `null` sans précédent, ou si l’épisode courant n’est pas dans la file.
  Future<EpisodeEntry?> previousInQueue({int? beforeEpisodeId}) async {
    if (beforeEpisodeId == null) return null;
    final items = await _episodeQuery(queuedOnly: true).get();
    if (items.isEmpty) return null;
    final index = items.indexWhere((e) => e.episode.id == beforeEpisodeId);
    if (index <= 0) return null;
    return items[index - 1];
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
    bool inProgressOnly = false,
    int? podcastId,
    int? playlistId,
    String search = '',
    int? limit,
  }) {
    final needle = search.trim();
    final hasSearch = needle.isNotEmpty;
    // Recherche accent/casse-insensible comme les abonnements (`searchMatch`) :
    // SQLite `lower()` ne plie pas les diacritiques, donc on filtre en Dart.
    return _episodeWindow(
      unreadOnly: unreadOnly,
      favoritesOnly: favoritesOnly,
      downloadsOnly: downloadsOnly,
      queuedOnly: queuedOnly,
      historyOnly: historyOnly,
      inProgressOnly: inProgressOnly,
      podcastId: podcastId,
      playlistId: playlistId,
      limit: hasSearch ? null : limit,
    ).watch().map((rows) {
      if (!hasSearch) return rows;
      final matched = [
        for (final entry in rows)
          if (searchMatch(entry.episode.title, needle) ||
              searchMatch(entry.podcast.title, needle))
            entry,
      ];
      if (limit == null || matched.length <= limit) return matched;
      return matched.sublist(0, limit);
    });
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
    bool playedOnly = false,
    bool randomOrder = false,
    int? podcastId,
    int? playlistId,
    int? limit,
    bool stableOrder = false,
    int? afterEpisodeId,
    DateTime? afterPublishedAt,
    DateTime? afterLastPlayedAt,
    bool afterByLastPlayed = false,
    int? afterPlaylistPosition,
    bool beforeAnchor = false,
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
        podcasts.episodeNotification,
        podcasts.subscribed,
        podcasts.playbackSpeed,
        podcasts.skipIntroSeconds,
        podcasts.skipOutroSeconds,
        podcasts.authUsername,
        podcasts.authPassword,
      ])
      ..join([innerJoin(podcasts, podcasts.id.equalsExp(episodes.podcastId))]);
    if (playlistId != null) {
      query.join([
        innerJoin(
          playlistEpisodes,
          playlistEpisodes.episodeId.equalsExp(episodes.id) &
              playlistEpisodes.playlistId.equals(playlistId),
        ),
      ]);
    }
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
    if (playedOnly) query.where(episodes.played.equals(true));
    if (podcastId != null) {
      query.where(episodes.podcastId.equals(podcastId));
    } else if (!downloadsOnly &&
        !queuedOnly &&
        !historyOnly &&
        !inProgressOnly &&
        !recentDownloads &&
        !favoritesOnly &&
        playlistId == null) {
      // Listes « bibliothèque » : masquer les aperçus Explorer.
      query.where(podcasts.subscribed.equals(true));
    }
    if (afterEpisodeId != null) {
      if (afterPlaylistPosition != null) {
        query.where(
          beforeAnchor
              ? playlistEpisodes.position.isSmallerThanValue(
                  afterPlaylistPosition,
                )
              : playlistEpisodes.position.isBiggerThanValue(
                  afterPlaylistPosition,
                ),
        );
      } else if (afterByLastPlayed) {
        final playedAt = episodes.lastPlayedAt;
        query.where(
          afterLastPlayedAt == null
              ? playedAt.isNull() &
                    (beforeAnchor
                        ? episodes.id.isBiggerThanValue(afterEpisodeId)
                        : episodes.id.isSmallerThanValue(afterEpisodeId))
              : beforeAnchor
              ? playedAt.isBiggerThanValue(afterLastPlayedAt) |
                    (playedAt.equals(afterLastPlayedAt) &
                        episodes.id.isBiggerThanValue(afterEpisodeId))
              : playedAt.isSmallerThanValue(afterLastPlayedAt) |
                    (playedAt.equals(afterLastPlayedAt) &
                        episodes.id.isSmallerThanValue(afterEpisodeId)),
        );
      } else if (afterPublishedAt == null) {
        query.where(
          beforeAnchor
              ? episodes.publishedAt.isNotNull() |
                    (episodes.publishedAt.isNull() &
                        episodes.id.isBiggerThanValue(afterEpisodeId))
              : episodes.publishedAt.isNull() &
                    episodes.id.isSmallerThanValue(afterEpisodeId),
        );
      } else {
        final published = episodes.publishedAt;
        query.where(
          beforeAnchor
              ? published.isBiggerThanValue(afterPublishedAt) |
                    (published.equals(afterPublishedAt) &
                        episodes.id.isBiggerThanValue(afterEpisodeId))
              : published.isSmallerThanValue(afterPublishedAt) |
                    (published.equals(afterPublishedAt) &
                        episodes.id.isSmallerThanValue(afterEpisodeId)),
        );
      }
    }
    final tie = !stableOrder
        ? null
        : beforeAnchor
        ? OrderingTerm.asc(episodes.id)
        : OrderingTerm.desc(episodes.id);
    final newestFirst = !beforeAnchor;
    if (randomOrder) {
      query.orderBy([OrderingTerm.random()]);
    } else if (inProgressOnly) {
      query.orderBy([
        newestFirst
            ? OrderingTerm.desc(episodes.lastPlayedAt)
            : OrderingTerm.asc(episodes.lastPlayedAt),
        ?tie,
      ]);
    } else if (recentDownloads) {
      query.orderBy([
        newestFirst
            ? OrderingTerm.desc(episodes.downloadedAt)
            : OrderingTerm.asc(episodes.downloadedAt),
        newestFirst
            ? OrderingTerm.desc(episodes.publishedAt)
            : OrderingTerm.asc(episodes.publishedAt),
        ?tie,
      ]);
    } else if (queuedOnly) {
      query.orderBy([OrderingTerm.asc(episodes.queueIndex)]);
    } else if (playlistId != null) {
      query.orderBy([
        newestFirst
            ? OrderingTerm.asc(playlistEpisodes.position)
            : OrderingTerm.desc(playlistEpisodes.position),
        if (stableOrder)
          newestFirst
              ? OrderingTerm.asc(episodes.id)
              : OrderingTerm.desc(episodes.id),
      ]);
    } else if (historyOnly) {
      query.orderBy([
        newestFirst
            ? OrderingTerm.desc(episodes.lastPlayedAt)
            : OrderingTerm.asc(episodes.lastPlayedAt),
        ?tie,
      ]);
    } else {
      query.orderBy([
        newestFirst
            ? OrderingTerm.desc(episodes.publishedAt)
            : OrderingTerm.asc(episodes.publishedAt),
        ?tie,
      ]);
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
          episodeNotification: row.read(podcasts.episodeNotification)!,
          subscribed: row.read(podcasts.subscribed)!,
          playbackSpeed: row.read(podcasts.playbackSpeed),
          skipIntroSeconds: row.read(podcasts.skipIntroSeconds)!,
          skipOutroSeconds: row.read(podcasts.skipOutroSeconds)!,
          authUsername: row.read(podcasts.authUsername),
          authPassword: row.read(podcasts.authPassword),
          personsJson: '[]',
          fundingJson: '[]',
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
    final row = await (select(
      playbackPositions,
    )..where((table) => table.episodeId.equals(episodeId))).getSingleOrNull();
    return row?.positionMs;
  }

  Future<void> setPlayed(int id, {required bool played}) {
    return transaction(() async {
      final current = await getEpisode(id);
      await (update(episodes)..where((table) => table.id.equals(id))).write(
        EpisodesCompanion(
          played: Value(played),
          positionMs: played ? const Value(0) : const Value.absent(),
        ),
      );
      if (played) {
        await upsertPlaybackPosition(id, 0);
      }
      if (current == null) return;
      final total = current.episode.durationSeconds ?? 0;
      final seconds = total > 0 ? total : 1;
      SyncHooks.reportEpisode(
        SyncEpisodeReport(
          episodeId: id,
          feedUrl: current.podcast.feedUrl,
          audioUrl: current.episode.audioUrl,
          guid: current.episode.guid,
          action: played ? 'play' : 'new',
          positionSeconds: played ? seconds : 0,
          startedSeconds: played ? seconds : 0,
          totalSeconds: played ? seconds : 0,
        ),
      );
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

  /// Place [episodeId] juste après [afterEpisodeId], ou en tête de file.
  Future<void> queueNext(int episodeId, {int? afterEpisodeId}) async {
    final items = await _episodeQuery(queuedOnly: true).get();
    final ids = [for (final item in items) item.episode.id]..remove(episodeId);
    var insertAt = 0;
    if (afterEpisodeId != null) {
      final index = ids.indexOf(afterEpisodeId);
      if (index >= 0) insertAt = index + 1;
    }
    ids.insert(insertAt, episodeId);
    await setQueueOrder(ids);
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

  /// Page suivante d’une liste, sans charger le reste.
  ///
  /// [after] est exclu. L’ordre est celui de la liste, avec l’id pour
  /// départager les dates identiques. [mayHaveMore] est vrai quand la page
  /// SQL était pleine, donc une suite reste possible.
  Future<({List<EpisodeEntry> entries, bool mayHaveMore})> readPlaybackPage({
    bool unreadOnly = false,
    bool favoritesOnly = false,
    bool downloadsOnly = false,
    bool queuedOnly = false,
    bool historyOnly = false,
    bool inProgressOnly = false,
    int? podcastId,
    int? playlistId,
    String search = '',
    EpisodeEntry? after,
    EpisodeEntry? before,
    int limit = 40,
  }) async {
    final anchor = before ?? after;
    final byPlayed = historyOnly || inProgressOnly;
    final afterId = anchor?.episode.id;
    final rows = await _episodeWindow(
      unreadOnly: unreadOnly,
      favoritesOnly: favoritesOnly,
      downloadsOnly: downloadsOnly,
      queuedOnly: queuedOnly,
      historyOnly: historyOnly,
      inProgressOnly: inProgressOnly,
      podcastId: podcastId,
      playlistId: playlistId,
      limit: limit,
      stableOrder: true,
      afterEpisodeId: afterId,
      afterByLastPlayed: byPlayed,
      afterLastPlayedAt: byPlayed ? anchor?.episode.lastPlayedAt : null,
      afterPublishedAt: byPlayed || playlistId != null
          ? null
          : anchor?.episode.publishedAt,
      afterPlaylistPosition: afterId == null || playlistId == null
          ? null
          : await _playlistPosition(playlistId, afterId),
      beforeAnchor: before != null,
    ).get();
    final needle = search.trim();
    final entries = needle.isEmpty
        ? rows
        : [
            for (final entry in rows)
              if (searchMatch(entry.episode.title, needle) ||
                  searchMatch(entry.podcast.title, needle))
                entry,
          ];
    return (
      entries: before != null ? entries.reversed.toList() : entries,
      mayHaveMore: rows.length >= limit,
    );
  }

  Future<int?> _playlistPosition(int playlistId, int episodeId) async {
    final row =
        await (select(playlistEpisodes)..where(
              (table) =>
                  table.playlistId.equals(playlistId) &
                  table.episodeId.equals(episodeId),
            ))
            .getSingleOrNull();
    return row?.position;
  }

  /// Place [episodeIds] en tête de file, dans cet ordre.
  Future<void> prependToQueue(List<int> episodeIds) {
    if (episodeIds.isEmpty) return Future.value();
    return transaction(() async {
      await customUpdate(
        'UPDATE episodes SET queue_index = queue_index + ? '
        'WHERE queue_index IS NOT NULL',
        variables: [Variable<int>(episodeIds.length)],
        updates: {episodes},
      );
      for (var index = 0; index < episodeIds.length; index++) {
        await (update(episodes)
              ..where((table) => table.id.equals(episodeIds[index])))
            .write(EpisodesCompanion(queueIndex: Value(index)));
      }
    });
  }

  /// Ajoute [episodeIds] à la fin de la file, sans toucher à ceux déjà dedans.
  Future<void> appendToQueue(List<int> episodeIds) {
    if (episodeIds.isEmpty) return Future.value();
    return transaction(() async {
      final max = episodes.queueIndex.max();
      final row =
          await (selectOnly(episodes)
                ..addColumns([max])
                ..where(episodes.queueIndex.isNotNull()))
              .getSingle();
      var next = (row.read(max) ?? -1) + 1;
      for (final id in episodeIds) {
        final updated =
            await (update(episodes)..where(
                  (table) => table.id.equals(id) & table.queueIndex.isNull(),
                ))
                .write(EpisodesCompanion(queueIndex: Value(next)));
        if (updated > 0) next++;
      }
    });
  }

  /// Vide la file, puis y place [episodeIds] dans cet ordre.
  Future<void> replaceQueue(List<int> episodeIds) {
    return transaction(() async {
      await (update(episodes)..where((table) => table.queueIndex.isNotNull()))
          .write(const EpisodesCompanion(queueIndex: Value(null)));
      for (var index = 0; index < episodeIds.length; index++) {
        await (update(episodes)
              ..where((table) => table.id.equals(episodeIds[index])))
            .write(EpisodesCompanion(queueIndex: Value(index)));
      }
    });
  }
}
