part of '../app_database.dart';

mixin _PodcastQueries on _$AppDatabase, _ChapterQueries {
  Stream<List<Podcast>> watchPodcasts() {
    // Plus récent dernier épisode en tête ; sans épisode → en bas.
    final latestEpisode = episodes.publishedAt.max();
    final latestOrEpoch = coalesce([
      latestEpisode,
      Constant(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
    ]);
    final query =
        select(podcasts).join([
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

  /// Accueil « Abonnements préférés » : préférés d’abord, puis les plus
  /// écoutés (temps sur les épisodes commencés non terminés), puis le titre.
  Stream<List<Podcast>> watchPodcastsByPreference() {
    final unfinishedListen = CustomExpression<int>(
      'COALESCE(SUM(CASE WHEN episodes.played = 0 AND episodes.position_ms > 0 '
      'THEN episodes.position_ms ELSE 0 END), 0)',
    );
    final query =
        select(podcasts).join([
            leftOuterJoin(episodes, episodes.podcastId.equalsExp(podcasts.id)),
          ])
          ..where(podcasts.subscribed.equals(true))
          ..addColumns([unfinishedListen])
          ..groupBy([podcasts.id])
          ..orderBy([
            OrderingTerm.desc(podcasts.preferred),
            OrderingTerm.desc(unfinishedListen),
            OrderingTerm.asc(podcasts.title),
          ]);
    return query.map((row) => row.readTable(podcasts)).watch();
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

  /// Les identifiants vides ne changent rien.
  Future<void> setPodcastsAutoDownload(
    Iterable<int> ids, {
    required bool autoDownload,
  }) {
    final wanted = ids.toList();
    if (wanted.isEmpty) return Future.value();
    return (update(podcasts)..where((table) => table.id.isIn(wanted))).write(
      PodcastsCompanion(autoDownload: Value(autoDownload)),
    );
  }

  /// `null` = illimité. Les identifiants vides ne changent rien.
  Future<void> setPodcastsAutoDownloadLimit(Iterable<int> ids, int? limit) {
    final wanted = ids.toList();
    if (wanted.isEmpty) return Future.value();
    return (update(podcasts)..where((table) => table.id.isIn(wanted))).write(
      PodcastsCompanion(autoDownloadLimit: Value(limit)),
    );
  }

  /// Inclut chaque abonnement dans les alertes de nouveaux épisodes.
  /// Un aperçu non suivi n’est pas modifié.
  Future<void> enableEpisodeNotificationForSubscriptions() {
    return (update(podcasts)..where((table) => table.subscribed.equals(true)))
        .write(const PodcastsCompanion(episodeNotification: Value(true)));
  }

  Future<void> setPodcastEpisodeNotification(int id, {required bool enabled}) {
    return (update(podcasts)..where((table) => table.id.equals(id))).write(
      PodcastsCompanion(episodeNotification: Value(enabled)),
    );
  }

  Future<void> setPodcastKeepUpdated(int id, {required bool keepUpdated}) {
    return (update(podcasts)..where((table) => table.id.equals(id))).write(
      PodcastsCompanion(keepUpdated: Value(keepUpdated)),
    );
  }

  /// Mémorise les genres seulement si le flux n’a pas encore été classé.
  Future<void> setPodcastCategoriesIfMissing(int id, List<String> genres) {
    return (update(podcasts)..where(
          (table) => table.id.equals(id) & table.categoriesJson.isNull(),
        ))
        .write(
          PodcastsCompanion(
            categoriesJson: Value(encodePodcastCategories(genres)),
          ),
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

  Future<void> setPodcastSkipBounds(
    int id, {
    int? skipIntroSeconds,
    int? skipOutroSeconds,
  }) {
    return (update(podcasts)..where((table) => table.id.equals(id))).write(
      PodcastsCompanion(
        skipIntroSeconds: skipIntroSeconds == null
            ? const Value.absent()
            : Value(skipIntroSeconds),
        skipOutroSeconds: skipOutroSeconds == null
            ? const Value.absent()
            : Value(skipOutroSeconds),
      ),
    );
  }

  /// `null` = utiliser le défaut global des réglages.
  Future<void> setPodcastPlaybackSpeed(int id, double? speed) {
    return (update(podcasts)..where((table) => table.id.equals(id))).write(
      PodcastsCompanion(playbackSpeed: Value(speed)),
    );
  }

  /// Identifiants HTTP Basic. Une chaîne vide efface la valeur.
  Future<void> setPodcastCredentials(
    int id, {
    required String? username,
    required String? password,
  }) {
    final user = username?.trim() ?? '';
    final pass = password ?? '';
    return (update(podcasts)..where((table) => table.id.equals(id))).write(
      PodcastsCompanion(
        authUsername: Value(user.isEmpty ? null : user),
        authPassword: Value(pass.isEmpty ? null : pass),
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

  Future<List<Podcast>> listSubscribed() {
    return (select(
      podcasts,
    )..where((table) => table.subscribed.equals(true))).get();
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

  /// Enregistre le flux et renvoie les épisodes vraiment nouveaux.
  ///
  /// Un guid inconnu n’est signalé que si le podcast était déjà un abonnement :
  /// le premier ajout ne doit pas traiter l’archive comme des nouveautés.
  Future<SavedFeed> saveFeed(
    FeedDraft draft, {
    bool? subscribed,
    bool? keepUpdated,
  }) {
    return transaction(() async {
      final existing = await findByFeedUrl(draft.feedUrl);
      final alreadyFollowed = existing?.subscribed ?? false;
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
            personsJson: Value(encodePodcastPersons(draft.persons)),
            fundingJson: Value(encodePodcastFunding(draft.funding)),
            categoriesJson: Value(encodePodcastCategories(draft.categories)),
            subscribedAt: DateTime.now(),
            refreshedAt: Value(DateTime.now()),
            subscribed: Value(subscribed ?? true),
            keepUpdated: Value(keepUpdated ?? subscribed ?? true),
          ),
        );
      } else {
        podcastId = existing.id;
        final imageChanged =
            (existing.imageUrl ?? '') != (draft.imageUrl ?? '');
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
            personsJson: Value(encodePodcastPersons(draft.persons)),
            fundingJson: Value(encodePodcastFunding(draft.funding)),
            categoriesJson: Value(encodePodcastCategories(draft.categories)),
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
      final knownByGuid =
          <
            String,
            ({
              int id,
              String title,
              String description,
              String audioUrl,
              String? mimeType,
              int? durationSeconds,
              DateTime? publishedAt,
              String? imageUrl,
              String? chaptersUrl,
            })
          >{
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
      final freshGuids = <String>[];
      final changed = <({int id, EpisodeDraft episode, bool imageChanged})>[];
      final chapterUrlChangedIds = <int>[];
      final seen = <String>{};
      for (final episode in draft.episodes) {
        if (!seen.add(episode.guid)) continue;
        final existing = knownByGuid[episode.guid];
        if (existing == null) {
          freshGuids.add(episode.guid);
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
                  chapterUrlChangedIds.contains(knownByGuid[episode.guid]!.id)))
            episode.guid,
      };
      if (inlineTargets.isNotEmpty) {
        final ids =
            await (selectOnly(episodes)
                  ..addColumns([episodes.id, episodes.guid])
                  ..where(episodes.podcastId.equals(podcastId)))
                .get();
        final idByGuid = {
          for (final row in ids)
            row.read(episodes.guid)!: row.read(episodes.id)!,
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

      final newEpisodeIds = alreadyFollowed && freshGuids.isNotEmpty
          ? await _episodeIdsForGuids(podcastId, freshGuids)
          : const <int>[];
      return SavedFeed(podcastId: podcastId, newEpisodeIds: newEpisodeIds);
    });
  }

  /// Identifiants des [guids], dans l’ordre donné.
  Future<List<int>> _episodeIdsForGuids(
    int podcastId,
    List<String> guids,
  ) async {
    final rows =
        await (selectOnly(episodes)
              ..addColumns([episodes.id, episodes.guid])
              ..where(
                episodes.podcastId.equals(podcastId) &
                    episodes.guid.isIn(guids),
              ))
            .get();
    final idByGuid = {
      for (final row in rows) row.read(episodes.guid)!: row.read(episodes.id)!,
    };
    return [
      for (final guid in guids)
        if (idByGuid[guid] != null) idByGuid[guid]!,
    ];
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
    if (podcast != null && podcast.subscribed) {
      SyncHooks.reportUnsubscribed(podcast.feedUrl);
    }
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

  Future<List<({int id, String path})>> podcastImageFiles() async {
    final query = selectOnly(podcasts)
      ..addColumns([podcasts.id, podcasts.imagePath])
      ..where(podcasts.imagePath.isNotNull());
    final rows = await query.get();
    return [
      for (final row in rows)
        if (row.read(podcasts.imagePath) case final path?)
          (id: row.read(podcasts.id)!, path: path),
    ];
  }

  Future<void> clearPodcastImagePaths(List<int> ids) async {
    const size = 400;
    for (var start = 0; start < ids.length; start += size) {
      final end = start + size < ids.length ? start + size : ids.length;
      await (update(podcasts)
            ..where((table) => table.id.isIn(ids.sublist(start, end))))
          .write(const PodcastsCompanion(imagePath: Value(null)));
    }
  }

  Future<void> setPodcastImagePaths(List<({int id, String path})> updates) {
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
    return (select(podcasts)..where(
          (table) => table.imageUrl.isNotNull() & table.imagePath.isNull(),
        ))
        .get();
  }

  /// Répare les titres lus en Latin-1 (« é » stocké « Ã© »).
  Future<void> repairMojibakeText() async {
    final broken = const ['%Ã%', '%Â%'];
    final podcastRows =
        await (select(podcasts)..where(
              (table) =>
                  table.title.like(broken[0]) |
                  table.title.like(broken[1]) |
                  table.author.like(broken[0]) |
                  table.author.like(broken[1]) |
                  table.description.like(broken[0]) |
                  table.description.like(broken[1]),
            ))
            .get();
    if (podcastRows.isNotEmpty) {
      await batch((statement) {
        for (final row in podcastRows) {
          final title = repairMojibake(row.title);
          final author = repairMojibake(row.author);
          final description = repairMojibake(row.description);
          if (title == row.title &&
              author == row.author &&
              description == row.description) {
            continue;
          }
          statement.update(
            podcasts,
            PodcastsCompanion(
              title: Value(title),
              author: Value(author),
              description: Value(description),
            ),
            where: (table) => table.id.equals(row.id),
          );
        }
      });
    }

    final episodeRows =
        await (selectOnly(episodes)
              ..addColumns([episodes.id, episodes.title, episodes.description])
              ..where(
                episodes.title.like(broken[0]) |
                    episodes.title.like(broken[1]) |
                    episodes.description.like(broken[0]) |
                    episodes.description.like(broken[1]),
              ))
            .get();
    if (episodeRows.isNotEmpty) {
      await batch((statement) {
        for (final row in episodeRows) {
          final id = row.read(episodes.id);
          if (id == null) continue;
          final title = repairMojibake(row.read(episodes.title) ?? '');
          final description = repairMojibake(
            row.read(episodes.description) ?? '',
          );
          if (title == (row.read(episodes.title) ?? '') &&
              description == (row.read(episodes.description) ?? '')) {
            continue;
          }
          statement.update(
            episodes,
            EpisodesCompanion(
              title: Value(title),
              description: Value(description),
            ),
            where: (table) => table.id.equals(id),
          );
        }
      });
    }

    final chapterRows =
        await (selectOnly(episodeChapters)
              ..addColumns([episodeChapters.id, episodeChapters.title])
              ..where(
                episodeChapters.title.like(broken[0]) |
                    episodeChapters.title.like(broken[1]),
              ))
            .get();
    if (chapterRows.isEmpty) return;
    await batch((statement) {
      for (final row in chapterRows) {
        final id = row.read(episodeChapters.id);
        if (id == null) continue;
        final title = repairMojibake(row.read(episodeChapters.title) ?? '');
        if (title == (row.read(episodeChapters.title) ?? '')) continue;
        statement.update(
          episodeChapters,
          EpisodeChaptersCompanion(title: Value(title)),
          where: (table) => table.id.equals(id),
        );
      }
    });
  }
}
