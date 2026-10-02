part of '../app_database.dart';

mixin _ChapterQueries on _$AppDatabase {
  Stream<List<EpisodeChapter>> watchChapters(int episodeId) {
    final query = select(episodeChapters)
      ..where((row) => row.episodeId.equals(episodeId) & row.toc.equals(true))
      ..orderBy([
        (row) => OrderingTerm.asc(row.startMs),
        (row) => OrderingTerm.asc(row.sortIndex),
      ]);
    return query.watch();
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
    });
  }

  Future<void> markChaptersFetched(int episodeId) {
    return (update(episodes)..where((table) => table.id.equals(episodeId)))
        .write(const EpisodesCompanion(chaptersFetched: Value(true)));
  }

}
