import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/database_backup.dart';
import 'package:podavio/data/models.dart';

void main() {
  test('import forgets local files that are no longer on disk', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final dir = await Directory.systemTemp.createTemp('podavio-import');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final audio = File('${dir.path}/keep.mp3');
    final cover = File('${dir.path}/cover.jpg');
    await audio.writeAsBytes([1, 2, 3]);
    await cover.writeAsBytes([4, 5]);

    final saved = await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: 'Description',
        imageUrl: 'https://example.com/cover.jpg',
        episodes: [
          EpisodeDraft(
            guid: 'keep',
            title: 'Présent',
            description: 'Notes',
            audioUrl: 'https://example.com/keep.mp3',
          ),
          EpisodeDraft(
            guid: 'gone',
            title: 'Absent',
            description: 'Notes',
            audioUrl: 'https://example.com/gone.mp3',
          ),
        ],
      ),
    );
    final created = await database
        .watchEpisodes(podcastId: saved.podcastId)
        .first;
    final keep = created.singleWhere((row) => row.episode.guid == 'keep');
    final gone = created.singleWhere((row) => row.episode.guid == 'gone');

    await database.setDownloadPath(keep.episode.id, audio.path);
    await database.setDownloadPath(gone.episode.id, '${dir.path}/missing.mp3');
    await database.setEpisodeImagePath(keep.episode.id, cover.path);
    await database.setEpisodeImagePath(
      gone.episode.id,
      '${dir.path}/missing.jpg',
    );
    await database.setPosition(keep.episode.id, 15000);
    await database.setFavorite(keep.episode.id, favorite: true);

    final other = await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/other.xml',
        title: 'Autre',
        author: 'Auteur',
        description: 'Description',
        imageUrl: 'https://example.com/other.jpg',
        episodes: [],
      ),
    );
    await database.setPodcastImagePath(saved.podcastId, cover.path);
    await database.setPodcastImagePath(
      other.podcastId,
      '${dir.path}/missing-cover.jpg',
    );

    final saf = await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/saf.xml',
        title: 'Saf',
        author: 'Auteur',
        description: 'Description',
        episodes: [
          EpisodeDraft(
            guid: 'saf',
            title: 'Document',
            description: 'Notes',
            audioUrl: 'https://example.com/saf.mp3',
          ),
        ],
      ),
    );
    final safEpisode =
        (await database.watchEpisodes(podcastId: saf.podcastId).first)
            .single
            .episode;
    await database.setDownloadPath(
      safEpisode.id,
      'content://com.android.externalstorage/keep',
    );

    await forgetMissingLocalFiles(database);

    final after = await database
        .watchEpisodes(podcastId: saved.podcastId)
        .first;
    final kept = after.singleWhere((row) => row.episode.guid == 'keep').episode;
    final dropped = after
        .singleWhere((row) => row.episode.guid == 'gone')
        .episode;
    expect(kept.downloadPath, audio.path);
    expect(kept.downloadedAt, isNotNull);
    expect(kept.imagePath, cover.path);
    expect(kept.positionMs, 15000);
    expect(kept.favorite, isTrue);
    expect(dropped.downloadPath, isNull);
    expect(dropped.downloadedAt, isNull);
    expect(dropped.imagePath, isNull);

    final covers = await database.podcastImageFiles();
    expect(covers.map((file) => file.id), [saved.podcastId]);
    expect(covers.single.path, cover.path);
    final missing = await database.podcastsMissingCovers();
    expect(missing.map((podcast) => podcast.id), contains(other.podcastId));
    expect(
      missing.map((podcast) => podcast.id),
      isNot(contains(saved.podcastId)),
    );

    final safAfter =
        (await database.watchEpisodes(podcastId: saf.podcastId).first)
            .single
            .episode;
    expect(safAfter.downloadPath, 'content://com.android.externalstorage/keep');
  });

  test('backup names keep a manual export out of the automatic set', () {
    final when = DateTime(2026, 11, 19, 8, 5, 9);
    expect(
      databaseBackupFileName(when),
      'PodavioBackup-2026-11-19-080509.sqlite',
    );
    expect(
      automaticDatabaseBackupFileName(when),
      'PodavioAuto-2026-11-19-080509.sqlite',
    );
  });

  test(
    'replacing a database copies the file and rejects a non-sqlite',
    () async {
      final dir = await Directory.systemTemp.createTemp('podavio-replace');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final exported = await exportDatabaseFile(database, directory: dir);
      addTearDown(() => deleteExportFile(exported));

      final live = File('${dir.path}/live.sqlite');
      await replaceDatabaseFile(live, exported);
      final header = await live.openRead(0, 15).first;
      expect(String.fromCharCodes(header), 'SQLite format 3');
      expect(await live.length(), await exported.length());

      final junk = File('${dir.path}/notes.txt');
      await junk.writeAsString('pas une base');
      expect(() => replaceDatabaseFile(live, junk), throwsStateError);
      expect(await live.length(), await exported.length());
    },
  );

  test(
    'export writes a sqlite file without keeping it only in memory',
    () async {
      final dir = await Directory.systemTemp.createTemp('podavio-export');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveFeed(
        const FeedDraft(
          feedUrl: 'https://example.com/feed.xml',
          title: 'Essai',
          author: 'Auteur',
          description: 'Description',
          imageUrl: 'https://example.com/cover.jpg',
          episodes: [],
        ),
      );

      final exported = await exportDatabaseFile(database, directory: dir);
      addTearDown(() => deleteExportFile(exported));
      final header = await exported.openRead(0, 15).first;
      expect(String.fromCharCodes(header), 'SQLite format 3');

      final folder = Directory('${dir.path}/backups');
      await writeBackupFile(folder.path, exported, 'PodavioBackup-test.sqlite');
      final copy = File('${folder.path}/PodavioBackup-test.sqlite');
      expect(await copy.length(), await exported.length());
      final copyHeader = await copy.openRead(0, 15).first;
      expect(String.fromCharCodes(copyHeader), 'SQLite format 3');
    },
  );
}
