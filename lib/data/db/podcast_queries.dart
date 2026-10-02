part of '../app_database.dart';

mixin _PodcastQueries on _$AppDatabase, _ChapterQueries {
  Stream<List<Podcast>> watchPodcasts() {
    // Plus récent dernier épisode en tête ; sans épisode → en bas.
    final latestEpisode = episodes.publishedAt.max();
    final latestOrEpoch = coalesce([
      latestEpisode,
      Constant(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
    ]);
    final query = select(podcasts).join([
      leftOuterJoin(episodes, episodes.podcastId.equalsExp(podcasts.id)),
    ])
      ..where(podcasts.subscribed.equals(true))
      ..addColumns([latestEpisode])
      ..groupBy([podcasts.id])
      ..orderBy([
        OrderingTerm(expression: latestOrEpoch, mode: OrderingMode.desc),
        OrderingTerm.asc(podcasts.title),
      ]);
    return query.map((row) => row.readTable(podcasts)).watch();
  }

  /// Abonnements sans join épisodes (tri géré côté UI).
  Stream<List<Podcast>> watchPodcastsPlain() {
    return (select(podcasts)
          ..where((table) => table.subscribed.equals(true))
          ..orderBy([(table) => OrderingTerm.asc(table.title)]))
        .watch();
  }

  /// Preferred subscriptions first, then the others by title.
  Stream<List<Podcast>> watchPodcastsByPreference() {
    return (select(podcasts)
          ..where((table) => table.subscribed.equals(true))
          ..orderBy([
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

  Future<void> setPodcastAutoDownload(int id, {required bool autoDownload}) {
    return (update(podcasts)..where((table) => table.id.equals(id))).write(
      PodcastsCompanion(autoDownload: Value(autoDownload)),
    );
  }

  Future<void> setPodcastKeepUpdated(int id, {required bool keepUpdated}) {
    return (update(podcasts)..where((table) => table.id.equals(id))).write(
      PodcastsCompanion(keepUpdated: Value(keepUpdated)),
    );
  }

  Future<void> setPodcastSubscribed(int id, {required bool subscribed}) {
    return (update(podcasts)..where((table) => table.id.equals(id))).write(
      PodcastsCompanion(
        subscribed: Value(subscribed),
        // Nouvel abonnement : reprendre le suivi auto.
        keepUpdated: subscribed ? const Value(true) : const Value.absent(),
        subscribedAt: subscribed ? Value(DateTime.now()) : const Value.absent(),
      ),
    );
  }

  Future<List<Podcast>> listPodcasts({bool subscribedOnly = true}) {
    final query = select(podcasts)
      ..orderBy([(table) => OrderingTerm.asc(table.title)]);
    if (subscribedOnly) {
      query.where((table) => table.subscribed.equals(true));
    }
    return query.get();
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

  Future<int> saveFeed(
    FeedDraft draft, {
    bool? subscribed,
    bool? keepUpdated,
  }) {
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
            subscribed: Value(subscribed ?? true),
            keepUpdated: Value(keepUpdated ?? subscribed ?? true),
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
            subscribed: subscribed == null
                ? const Value.absent()
                : Value(subscribed),
            keepUpdated: keepUpdated == null
                ? const Value.absent()
                : Value(keepUpdated),
          ),
        );
      }

      final known =
          await (selectOnly(episodes)
                ..addColumns([
                  episodes.id,
                  episodes.guid,
                  episodes.title,
                  episodes.description,
                  episodes.audioUrl,
                  episodes.mimeType,
                  episodes.durationSeconds,
                  episodes.publishedAt,
                  episodes.imageUrl,
                  episodes.chaptersUrl,
                ])
                ..where(episodes.podcastId.equals(podcastId)))
              .get();
      final knownByGuid = <String, ({
        int id,
        String title,
        String description,
        String audioUrl,
        String? mimeType,
        int? durationSeconds,
        DateTime? publishedAt,
        String? imageUrl,
        String? chaptersUrl,
      })>{
        for (final row in known)
          row.read(episodes.guid)!: (
            id: row.read(episodes.id)!,
            title: row.read(episodes.title)!,
            description: row.read(episodes.description) ?? '',
            audioUrl: row.read(episodes.audioUrl)!,
            mimeType: row.read(episodes.mimeType),
            durationSeconds: row.read(episodes.durationSeconds),
            publishedAt: row.read(episodes.publishedAt),
            imageUrl: row.read(episodes.imageUrl),
            chaptersUrl: row.read(episodes.chaptersUrl),
          ),
      };
      final fresh = <EpisodesCompanion>[];
      final changed = <({int id, EpisodeDraft episode, bool imageChanged})>[];
      final chapterUrlChangedIds = <int>[];
      final seen = <String>{};
      for (final episode in draft.episodes) {
        if (!seen.add(episode.guid)) continue;
        final existing = knownByGuid[episode.guid];
        if (existing == null) {
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
              chaptersUrl: Value(episode.chaptersUrl),
              chaptersFetched: Value(episode.chapters.isNotEmpty),
            ),
          );
        } else {
          final chaptersUrlChanged =
              (existing.chaptersUrl ?? '') != (episode.chaptersUrl ?? '');
          if (chaptersUrlChanged) {
            chapterUrlChangedIds.add(existing.id);
          }
          final imageChanged =
              (existing.imageUrl ?? '') != (episode.imageUrl ?? '');
          final publishedChanged = !_samePublishedAt(
            existing.publishedAt,
            episode.publishedAt,
          );
          final dirty =
              existing.title != episode.title ||
              existing.description != episode.description ||
              existing.audioUrl != episode.audioUrl ||
              (existing.mimeType ?? '') != (episode.mimeType ?? '') ||
              existing.durationSeconds != episode.durationSeconds ||
              publishedChanged ||
              imageChanged ||
              chaptersUrlChanged;
          if (!dirty) continue;
          changed.add((
            id: existing.id,
            episode: episode,
            imageChanged: imageChanged,
          ));
        }
      }

      if (fresh.isNotEmpty || changed.isNotEmpty) {
        await batch((statement) {
          if (fresh.isNotEmpty) statement.insertAll(episodes, fresh);
          for (final item in changed) {
            final chaptersChanged = chapterUrlChangedIds.contains(item.id);
            final hasInline = item.episode.chapters.isNotEmpty;
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
                chaptersUrl: Value(item.episode.chaptersUrl),
                chaptersFetched: hasInline
                    ? const Value(true)
                    : (chaptersChanged
                          ? const Value(false)
                          : const Value.absent()),
              ),
              where: (table) => table.id.equals(item.id),
            );
          }
        });
      }
      if (chapterUrlChangedIds.isNotEmpty) {
        await (delete(
          episodeChapters,
        )..where((row) => row.episodeId.isIn(chapterUrlChangedIds))).go();
      }

      // Chapitres inline : uniquement nouveaux épisodes ou URL chapitres changée.
      final inlineTargets = <String>{
        for (final episode in draft.episodes)
          if (episode.chapters.isNotEmpty &&
              (knownByGuid[episode.guid] == null ||
                  chapterUrlChangedIds.contains(
                    knownByGuid[episode.guid]!.id,
                  )))
            episode.guid,
      };
      if (inlineTargets.isNotEmpty) {
        final ids =
            await (selectOnly(episodes)
                  ..addColumns([episodes.id, episodes.guid])
                  ..where(episodes.podcastId.equals(podcastId)))
                .get();
        final idByGuid = {
          for (final row in ids) row.read(episodes.guid)!: row.read(episodes.id)!,
        };
        for (final episode in draft.episodes) {
          if (!inlineTargets.contains(episode.guid)) continue;
          final id = idByGuid[episode.guid];
          if (id == null) continue;
          await replaceChapters(id, [
            for (var i = 0; i < episode.chapters.length; i++)
              EpisodeChaptersCompanion.insert(
                episodeId: id,
                startMs: episode.chapters[i].startMs,
                title: Value(episode.chapters[i].title),
                link: Value(episode.chapters[i].link),
                toc: Value(episode.chapters[i].toc),
                sortIndex: Value(i),
              ),
          ]);
        }
      }
      return podcastId;
    });
  }

  static bool _samePublishedAt(DateTime? a, DateTime? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.toUtc().millisecondsSinceEpoch == b.toUtc().millisecondsSinceEpoch;
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

  Future<List<Podcast>> podcastsMissingCovers() {
    return (select(
      podcasts,
    )..where((table) => table.imageUrl.isNotNull() & table.imagePath.isNull()))
        .get();
  }

}
