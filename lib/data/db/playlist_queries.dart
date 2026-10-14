part of '../app_database.dart';

class PlaylistSummary {
  const PlaylistSummary({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.episodeCount,
  });

  final int id;
  final String name;
  final bool isDefault;
  final int episodeCount;
}

mixin _PlaylistQueries on _$AppDatabase, _EpisodeQueries {
  Stream<List<PlaylistSummary>> watchPlaylists() {
    return customSelect(
      'SELECT p.id, p.name, p.is_default, '
      'CASE WHEN p.is_default = 1 '
      'THEN (SELECT COUNT(*) FROM episodes WHERE queue_index IS NOT NULL) '
      'ELSE (SELECT COUNT(*) FROM playlist_episodes WHERE playlist_id = p.id) '
      'END AS episode_count '
      'FROM playlists p '
      'ORDER BY p.is_default DESC, p.created_at ASC, p.id ASC',
      readsFrom: {playlists, playlistEpisodes, episodes},
    ).watch().map((rows) {
      return [
        for (final row in rows)
          PlaylistSummary(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
            isDefault: row.read<int>('is_default') != 0,
            episodeCount: row.read<int>('episode_count'),
          ),
      ];
    });
  }

  Stream<Set<int>> watchCustomPlaylistEpisodeIds() {
    return select(playlistEpisodes)
        .watch()
        .map((rows) => {for (final row in rows) row.episodeId});
  }

  Stream<Set<int>> watchCustomPlaylistIds(int episodeId) {
    final query = select(playlistEpisodes)
      ..where((table) => table.episodeId.equals(episodeId));
    return query.watch().map(
      (rows) => {for (final row in rows) row.playlistId},
    );
  }

  Stream<List<EpisodeEntry>> watchPlaylistEpisodes(int playlistId) {
    return _episodeWindow(playlistId: playlistId).watch();
  }

  Future<int> createPlaylist(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Nom de playlist vide');
    }
    return into(playlists).insert(
      PlaylistsCompanion.insert(name: trimmed, createdAt: DateTime.now()),
    );
  }

  Future<void> renamePlaylist(int id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Nom de playlist vide');
    }
    return (update(playlists)..where((table) => table.id.equals(id))).write(
      PlaylistsCompanion(name: Value(trimmed)),
    );
  }

  /// La playlist par défaut est la file de lecture : elle reste en place.
  Future<void> deletePlaylist(int id) async {
    final playlist = await (select(
      playlists,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (playlist == null || playlist.isDefault) return;
    await (delete(playlists)..where((table) => table.id.equals(id))).go();
  }

  Future<void> addToPlaylist(int playlistId, int episodeId) async {
    final playlist = await (select(
      playlists,
    )..where((table) => table.id.equals(playlistId))).getSingle();
    if (playlist.isDefault) {
      await addToQueue(episodeId);
      return;
    }
    final existing =
        await (select(playlistEpisodes)..where(
              (table) =>
                  table.playlistId.equals(playlistId) &
                  table.episodeId.equals(episodeId),
            ))
            .getSingleOrNull();
    if (existing != null) return;
    final max = playlistEpisodes.position.max();
    final row =
        await (selectOnly(playlistEpisodes)
              ..addColumns([max])
              ..where(playlistEpisodes.playlistId.equals(playlistId)))
            .getSingle();
    final next = (row.read(max) ?? -1) + 1;
    await into(playlistEpisodes).insert(
      PlaylistEpisodesCompanion.insert(
        playlistId: playlistId,
        episodeId: episodeId,
        position: next,
      ),
    );
  }

  Future<void> removeFromPlaylist(int playlistId, int episodeId) async {
    final playlist = await (select(
      playlists,
    )..where((table) => table.id.equals(playlistId))).getSingle();
    if (playlist.isDefault) {
      await removeFromQueue(episodeId);
      return;
    }
    await (delete(playlistEpisodes)..where(
          (table) =>
              table.playlistId.equals(playlistId) &
              table.episodeId.equals(episodeId),
        ))
        .go();
  }

  Future<void> setPlaylistOrder(int playlistId, List<int> episodeIds) async {
    final playlist = await (select(
      playlists,
    )..where((table) => table.id.equals(playlistId))).getSingle();
    if (playlist.isDefault) {
      await setQueueOrder(episodeIds);
      return;
    }
    await transaction(() async {
      for (var index = 0; index < episodeIds.length; index++) {
        await (update(playlistEpisodes)..where(
              (table) =>
                  table.playlistId.equals(playlistId) &
                  table.episodeId.equals(episodeIds[index]),
            ))
            .write(PlaylistEpisodesCompanion(position: Value(index)));
      }
    });
  }
}
