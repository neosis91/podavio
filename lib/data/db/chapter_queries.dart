part of '../app_database.dart';

mixin _ChapterQueries on _$AppDatabase, _SkipSegmentQueries {
  Stream<List<EpisodeChapter>> watchChapters(int episodeId) {
    final query = select(episodeChapters)
      ..where((row) => row.episodeId.equals(episodeId) & row.toc.equals(true))
      ..orderBy([
        (row) => OrderingTerm.asc(row.startMs),
        (row) => OrderingTerm.asc(row.sortIndex),
      ]);
    return query.watch();
  }

  /// Titres de chapitres, dans l'ordre, pour poser le contexte des pubs.
  Future<Map<int, List<({int startMs, String title})>>> chapterMarksForEpisodes(
    List<int> episodeIds,
  ) async {
    if (episodeIds.isEmpty) return {};
    final rows =
        await (select(episodeChapters)
              ..where((row) => row.episodeId.isIn(episodeIds))
              ..orderBy([
                (row) => OrderingTerm.asc(row.episodeId),
                (row) => OrderingTerm.asc(row.startMs),
                (row) => OrderingTerm.asc(row.sortIndex),
              ]))
            .get();
    final grouped = <int, List<({int startMs, String title})>>{};
    for (final row in rows) {
      (grouped[row.episodeId] ??= []).add((
        startMs: row.startMs,
        title: row.title,
      ));
    }
    return grouped;
  }

  Future<Episode?> episodeById(int id) {
    return (select(
      episodes,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<void> replaceChapters(
    int episodeId,
    List<EpisodeChaptersCompanion> chapters,
  ) {
    return transaction(() async {
      await (delete(
        episodeChapters,
      )..where((row) => row.episodeId.equals(episodeId))).go();
      if (chapters.isNotEmpty) {
        await batch(
          (statement) => statement.insertAll(episodeChapters, chapters),
        );
      }
      await (update(episodes)..where((table) => table.id.equals(episodeId)))
          .write(const EpisodesCompanion(chaptersFetched: Value(true)));
      await seedChapterSkipSegments(episodeId);
    });
  }

  Future<void> markChaptersFetched(int episodeId) {
    return (update(episodes)..where((table) => table.id.equals(episodeId)))
        .write(const EpisodesCompanion(chaptersFetched: Value(true)));
  }
}
