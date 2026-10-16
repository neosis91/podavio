import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/search.dart';
import '../sync/sync_hooks.dart';
import 'models.dart';

part 'app_database.g.dart';
part 'db/chapter_queries.dart';
part 'db/episode_queries.dart';
part 'db/playlist_queries.dart';
part 'db/podcast_queries.dart';
part 'db/stats_queries.dart';

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
  BoolColumn get autoDownload => boolean().withDefault(const Constant(false))();
  BoolColumn get keepUpdated => boolean().withDefault(const Constant(true))();

  /// Prévient quand un épisode paraît. Coupé au départ, comme AntennaPod.
  BoolColumn get episodeNotification =>
      boolean().withDefault(const Constant(false))();

  /// false = aperçu (Explorer) : épisodes utilisables, hors bibliothèque.
  BoolColumn get subscribed => boolean().withDefault(const Constant(true))();

  /// Vitesse de lecture propre au podcast ; `null` = défaut global des réglages.
  RealColumn get playbackSpeed => real().nullable()();

  /// Secondes ignorées au début de chaque épisode (0 = désactivé).
  IntColumn get skipIntroSeconds => integer().withDefault(const Constant(0))();

  /// Secondes ignorées à la fin de chaque épisode (0 = désactivé).
  IntColumn get skipOutroSeconds => integer().withDefault(const Constant(0))();

  /// Identifiant HTTP Basic du flux. `null` = pas d’authentification.
  TextColumn get authUsername => text().nullable()();

  /// Mot de passe HTTP Basic du flux. `null` = pas d’authentification.
  TextColumn get authPassword => text().nullable()();
}

@TableIndex(name: 'episodes_podcast_id', columns: {#podcastId})
@TableIndex(name: 'episodes_published_at', columns: {#publishedAt})
@TableIndex(name: 'episodes_played', columns: {#played})
@TableIndex(name: 'episodes_queue_index', columns: {#queueIndex})
@TableIndex(name: 'episodes_last_played_at', columns: {#lastPlayedAt})
@TableIndex(name: 'episodes_favorite', columns: {#favorite})
@TableIndex(name: 'episodes_download_path', columns: {#downloadPath})
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
  TextColumn get chaptersUrl => text().nullable()();
  BoolColumn get chaptersFetched =>
      boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {podcastId, guid},
  ];
}

/// Chapitres Podcast Index (JSON) liés à un épisode.
class EpisodeChapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get episodeId =>
      integer().references(Episodes, #id, onDelete: KeyAction.cascade)();
  IntColumn get startMs => integer()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get link => text().nullable()();
  BoolColumn get toc => boolean().withDefault(const Constant(true))();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
}

/// Position de lecture découplée de `episodes` (évite de pulser les streams listes).
class PlaybackPositions extends Table {
  IntColumn get episodeId =>
      integer().references(Episodes, #id, onDelete: KeyAction.cascade)();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {episodeId};
}

/// Listes d’épisodes. Une seule est marquée par défaut : la file de lecture.
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

@TableIndex(name: 'playlist_episodes_playlist_id', columns: {#playlistId})
class PlaylistEpisodes extends Table {
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get episodeId =>
      integer().references(Episodes, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {playlistId, episodeId};
}

class EpisodeEntry {
  const EpisodeEntry({required this.episode, required this.podcast});

  final Episode episode;
  final Podcast podcast;

  /// URL distante de la jaquette.
  ///
  /// Par défaut : épisode si présent, sinon podcast.
  /// Avec [preferPodcastCover] : podcast en priorité (économie réseau).
  String? imageUrl({bool preferPodcastCover = false}) {
    final episodeImage = episode.imageUrl?.trim();
    final podcastImage = podcast.imageUrl?.trim();
    final hasEpisode = episodeImage != null && episodeImage.isNotEmpty;
    final hasPodcast = podcastImage != null && podcastImage.isNotEmpty;
    if (preferPodcastCover) {
      if (hasPodcast) return podcastImage;
      return hasEpisode ? episodeImage : null;
    }
    if (hasEpisode) return episodeImage;
    return hasPodcast ? podcastImage : null;
  }

  /// Fichier local de la jaquette, s’il a déjà été téléchargé.
  String? imagePath({bool preferPodcastCover = false}) {
    final episodeImage = episode.imageUrl?.trim();
    final podcastImage = podcast.imageUrl?.trim();
    final hasEpisode = episodeImage != null && episodeImage.isNotEmpty;
    final hasPodcast = podcastImage != null && podcastImage.isNotEmpty;
    if (preferPodcastCover) {
      if (hasPodcast) return podcast.imagePath;
      return hasEpisode ? episode.imagePath : null;
    }
    if (hasEpisode) return episode.imagePath;
    return hasPodcast ? podcast.imagePath : null;
  }
}

@DriftDatabase(
  tables: [
    Podcasts,
    Episodes,
    EpisodeChapters,
    PlaybackPositions,
    Playlists,
    PlaylistEpisodes,
  ],
)
class AppDatabase extends _$AppDatabase
    with
        _ChapterQueries,
        _EpisodeQueries,
        _PlaylistQueries,
        _PodcastQueries,
        _StatsQueries {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(driftDatabase(name: 'podavio'));

  @override
  int get schemaVersion => 14;

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
      if (from < 4) {
        await migrator.addColumn(podcasts, podcasts.autoDownload);
        await migrator.addColumn(podcasts, podcasts.keepUpdated);
      }
      if (from < 5) {
        await migrator.addColumn(episodes, episodes.chaptersUrl);
        await migrator.addColumn(episodes, episodes.chaptersFetched);
        await migrator.createTable(episodeChapters);
      }
      if (from < 6) {
        // Nouveau client HTTP (User-Agent) : retenter les URLs déjà marquées.
        await customStatement(
          "UPDATE episodes SET chapters_fetched = 0 "
          "WHERE chapters_url IS NOT NULL AND length(chapters_url) > 0",
        );
      }
      if (from < 7) {
        await migrator.addColumn(podcasts, podcasts.subscribed);
      }
      if (from < 8) {
        await migrator.createTable(playbackPositions);
        await _createEpisodeIndexes();
      }
      if (from < 9) {
        await customStatement(
          "UPDATE episodes SET chapters_fetched = 0 "
          "WHERE chapters_fetched = 1 "
          "AND chapters_url IS NOT NULL AND length(chapters_url) > 0 "
          "AND id NOT IN (SELECT DISTINCT episode_id FROM episode_chapters)",
        );
      }
      if (from < 10) {
        await migrator.addColumn(podcasts, podcasts.playbackSpeed);
      }
      if (from < 11) {
        await migrator.addColumn(podcasts, podcasts.skipIntroSeconds);
        await migrator.addColumn(podcasts, podcasts.skipOutroSeconds);
      }
      if (from < 12) {
        await migrator.addColumn(podcasts, podcasts.authUsername);
        await migrator.addColumn(podcasts, podcasts.authPassword);
      }
      if (from < 13) {
        await migrator.createTable(playlists);
        await migrator.createTable(playlistEpisodes);
      }
      if (from < 14) {
        await migrator.addColumn(podcasts, podcasts.episodeNotification);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Idempotent : v8 a pu être appliqué avant l’ajout des indexes.
      await _createEpisodeIndexes();
      await _ensureDefaultPlaylist();
    },
  );

  /// La file de lecture existe toujours, et ne se supprime pas.
  Future<void> _ensureDefaultPlaylist() async {
    final existing = await (select(
      playlists,
    )..where((table) => table.isDefault.equals(true))).get();
    if (existing.isNotEmpty) return;
    await into(playlists).insert(
      PlaylistsCompanion.insert(
        name: 'Playlist',
        isDefault: const Value(true),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Indexes listes / filtres (`_episodeWindow`). IF NOT EXISTS pour upgrades partiels.
  Future<void> _createEpisodeIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS episodes_podcast_id ON episodes (podcast_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS episodes_published_at '
      'ON episodes (published_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS episodes_played ON episodes (played)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS episodes_queue_index '
      'ON episodes (queue_index)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS episodes_last_played_at '
      'ON episodes (last_played_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS episodes_favorite ON episodes (favorite)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS episodes_download_path '
      'ON episodes (download_path)',
    );
  }
}
