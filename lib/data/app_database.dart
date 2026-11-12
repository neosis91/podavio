import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/search.dart';
import 'feed_text.dart';
import '../sync/sync_hooks.dart';
import 'download_policy.dart';
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

  /// [title] plié par [foldForSearch], pour la recherche SQL.
  TextColumn get titleFold => text().withDefault(const Constant(''))();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get link => text().nullable()();
  DateTimeColumn get subscribedAt => dateTime()();
  DateTimeColumn get refreshedAt => dateTime().nullable()();
  BoolColumn get preferred => boolean().withDefault(const Constant(false))();
  BoolColumn get autoDownload => boolean().withDefault(const Constant(false))();

  /// Plafond d’épisodes de ce podcast. `null` = illimité. Défaut : 1.
  IntColumn get autoDownloadLimit =>
      integer().nullable().withDefault(const Constant(1))();
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

  /// Personnes du flux (`podcast:person`), JSON.
  TextColumn get personsJson => text().withDefault(const Constant('[]'))();

  /// Liens de financement (`podcast:funding`), JSON.
  TextColumn get fundingJson => text().withDefault(const Constant('[]'))();

  /// Genres du flux (`itunes:category`, `podcast:category`). `null` : pas encore lus.
  TextColumn get categoriesJson => text().nullable()();
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

  /// [title] plié par [foldForSearch], pour la recherche SQL.
  TextColumn get titleFold => text().withDefault(const Constant(''))();
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

  /// Fichier gardé pendant une lecture en streaming. Distinct d’un téléchargement.
  TextColumn get cachePath => text().nullable()();
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
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await _addColumnIfMissing(migrator, podcasts, podcasts.preferred);
        await _addColumnIfMissing(migrator, episodes, episodes.downloadedAt);
      }
      if (from < 3) {
        await _addColumnIfMissing(migrator, podcasts, podcasts.imagePath);
        await _addColumnIfMissing(migrator, episodes, episodes.imagePath);
      }
      if (from < 4) {
        await _addColumnIfMissing(migrator, podcasts, podcasts.autoDownload);
        await _addColumnIfMissing(migrator, podcasts, podcasts.keepUpdated);
      }
      if (from < 5) {
        await _addColumnIfMissing(migrator, episodes, episodes.chaptersUrl);
        await _addColumnIfMissing(migrator, episodes, episodes.chaptersFetched);
        await _createTableIfMissing(migrator, episodeChapters);
      }
      if (from < 6) {
        // Nouveau client HTTP (User-Agent) : retenter les URLs déjà marquées.
        await customStatement(
          "UPDATE episodes SET chapters_fetched = 0 "
          "WHERE chapters_url IS NOT NULL AND length(chapters_url) > 0",
        );
      }
      if (from < 7) {
        await _addColumnIfMissing(migrator, podcasts, podcasts.subscribed);
      }
      if (from < 8) {
        await _createTableIfMissing(migrator, playbackPositions);
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
        await _addColumnIfMissing(migrator, podcasts, podcasts.playbackSpeed);
      }
      if (from < 11) {
        await _addColumnIfMissing(
          migrator,
          podcasts,
          podcasts.skipIntroSeconds,
        );
        await _addColumnIfMissing(
          migrator,
          podcasts,
          podcasts.skipOutroSeconds,
        );
      }
      if (from < 12) {
        await _addColumnIfMissing(migrator, podcasts, podcasts.authUsername);
        await _addColumnIfMissing(migrator, podcasts, podcasts.authPassword);
      }
      if (from < 13) {
        await _createTableIfMissing(migrator, playlists);
        await _createTableIfMissing(migrator, playlistEpisodes);
      }
      if (from < 14) {
        await _addColumnIfMissing(
          migrator,
          podcasts,
          podcasts.episodeNotification,
        );
      }
      if (from < 15) {
        await _addColumnIfMissing(migrator, podcasts, podcasts.personsJson);
        await _addColumnIfMissing(migrator, podcasts, podcasts.fundingJson);
      }
      if (from < 16) {
        await _addColumnIfMissing(migrator, podcasts, podcasts.categoriesJson);
      }
      if (from < 17) {
        await _addColumnIfMissing(migrator, episodes, episodes.cachePath);
      }
      if (from < 18) {
        await _addColumnIfMissing(migrator, podcasts, podcasts.titleFold);
        await _addColumnIfMissing(migrator, episodes, episodes.titleFold);
        await _backfillTitleFolds();
      }
      if (from < 19) {
        await _addColumnIfMissing(
          migrator,
          podcasts,
          podcasts.autoDownloadLimit,
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Idempotent : v8 a pu être appliqué avant l’ajout des indexes.
      await _createEpisodeIndexes();
      await _ensureDefaultPlaylist();
    },
  );

  /// Certaines versions ont déclaré des colonnes avant de monter
  /// [schemaVersion]. Le fichier les a déjà, avec un `user_version` plus ancien.
  /// On saute la colonne pour que ces bases, et leurs sauvegardes, s’ouvrent.
  Future<void> _addColumnIfMissing(
    Migrator migrator,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final rows = await customSelect(
      'PRAGMA table_info("${table.actualTableName}")',
    ).get();
    if (rows.any((row) => row.read<String>('name') == column.name)) return;
    await migrator.addColumn(table, column);
  }

  /// Même garde que [_addColumnIfMissing], pour une table.
  Future<void> _createTableIfMissing(
    Migrator migrator,
    TableInfo<Table, dynamic> table,
  ) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(table.actualTableName)],
    ).get();
    if (rows.isNotEmpty) return;
    await migrator.createTable(table);
  }

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
    await customStatement(
      'CREATE INDEX IF NOT EXISTS episodes_podcast_published '
      'ON episodes (podcast_id, published_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS episodes_in_progress '
      'ON episodes (last_played_at) '
      'WHERE played = 0 AND position_ms > 0',
    );
  }

  Future<void> _backfillTitleFolds() async {
    final podcastRows = await (selectOnly(
      podcasts,
    )..addColumns([podcasts.id, podcasts.title])).get();
    final episodeRows = await (selectOnly(
      episodes,
    )..addColumns([episodes.id, episodes.title])).get();
    await batch((statement) {
      for (final row in podcastRows) {
        final id = row.read(podcasts.id);
        final title = row.read(podcasts.title);
        if (id == null || title == null) continue;
        statement.update(
          podcasts,
          PodcastsCompanion(titleFold: Value(foldForSearch(title))),
          where: (table) => table.id.equals(id),
        );
      }
      for (final row in episodeRows) {
        final id = row.read(episodes.id);
        final title = row.read(episodes.title);
        if (id == null || title == null) continue;
        statement.update(
          episodes,
          EpisodesCompanion(titleFold: Value(foldForSearch(title))),
          where: (table) => table.id.equals(id),
        );
      }
    });
  }
}

extension PodcastFeedMeta on Podcast {
  List<PodcastPerson> get persons => decodePodcastPersons(personsJson);

  List<PodcastFunding> get fundingLinks => decodePodcastFunding(fundingJson);
}
