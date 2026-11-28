import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/skip_segments.dart';

Future<int> _userVersion(AppDatabase database) async {
  final row = await database.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

void main() {
  // Certaines versions ont déclaré les colonnes avant de monter schemaVersion.
  // Le fichier a déjà title_fold et auto_download_limit, avec un user_version
  // plus ancien. L’ouverture ne doit pas relancer l’ALTER.
  for (final staleVersion in [17, 18]) {
    test(
      'upgrades a v$staleVersion file that already has the columns',
      () async {
        final dir = await Directory.systemTemp.createTemp('podavio-migration');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/podavio.sqlite');

        final created = AppDatabase(NativeDatabase(file));
        await created.customSelect('SELECT 1').get();
        await created.customStatement('PRAGMA user_version = $staleVersion');
        await created.close();

        final reopened = AppDatabase(NativeDatabase(file));
        addTearDown(reopened.close);
        await reopened.customSelect('SELECT title_fold FROM podcasts').get();
        await reopened
            .customSelect('SELECT auto_download_limit FROM podcasts')
            .get();
        await reopened.customSelect('SELECT auto_skip_ads FROM podcasts').get();
        await reopened.customSelect('SELECT id FROM skip_segments').get();
        expect(await _userVersion(reopened), reopened.schemaVersion);
      },
    );
  }

  test('upgrades a v19 file that has no skip tables yet', () async {
    final dir = await Directory.systemTemp.createTemp('podavio-migration-v19');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/podavio.sqlite');

    final created = AppDatabase(NativeDatabase(file));
    await created.customSelect('SELECT 1').get();
    await created.customStatement('PRAGMA foreign_keys = OFF');
    await created.customStatement('DROP TABLE skip_segments');
    await created.customStatement('DROP TABLE segment_templates');
    await created.customStatement('DROP TABLE episode_fingerprints');
    await created.customStatement(
      'ALTER TABLE podcasts DROP COLUMN auto_skip_ads',
    );
    await created.customStatement(
      'ALTER TABLE podcasts DROP COLUMN auto_skip_kinds',
    );
    await created.customStatement('PRAGMA user_version = 19');
    await created.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    await reopened
        .customSelect('SELECT data, hop_micros FROM episode_fingerprints')
        .get();
    await reopened
        .customSelect(
          'SELECT kind, fingerprint, log_mel FROM segment_templates',
        )
        .get();
    await reopened
        .customSelect(
          'SELECT start_ms, end_ms, kind, source, matches, '
          'confidence, template_id FROM skip_segments',
        )
        .get();
    await reopened
        .customSelect('SELECT speech FROM episode_fingerprints')
        .get();
    await reopened
        .customSelect('SELECT status, envelope FROM episode_fingerprints')
        .get();
    await reopened
        .customSelect('SELECT confidence FROM segment_templates')
        .get();
    final columns = await reopened
        .customSelect('PRAGMA table_info(podcasts)')
        .get();
    final names = columns.map((row) => row.read<String>('name')).toSet();
    expect(names, containsAll(['auto_skip_ads', 'auto_skip_kinds']));
    expect(await _userVersion(reopened), reopened.schemaVersion);
  });

  test('upgrades a v21 file onto the speech timeline and confidence', () async {
    final dir = await Directory.systemTemp.createTemp('podavio-migration-v21');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/podavio.sqlite');

    final created = AppDatabase(NativeDatabase(file));
    await created.customSelect('SELECT 1').get();
    await created.customStatement(
      'ALTER TABLE episode_fingerprints DROP COLUMN speech',
    );
    await created.customStatement(
      'ALTER TABLE segment_templates DROP COLUMN confidence',
    );
    await created.customStatement(
      'ALTER TABLE skip_segments DROP COLUMN confidence',
    );
    await created.customStatement('PRAGMA user_version = 21');
    await created.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    await reopened
        .customSelect('SELECT speech FROM episode_fingerprints')
        .get();
    await reopened
        .customSelect('SELECT status, envelope FROM episode_fingerprints')
        .get();
    await reopened
        .customSelect('SELECT confidence FROM segment_templates')
        .get();
    await reopened.customSelect('SELECT confidence FROM skip_segments').get();
    expect(await _userVersion(reopened), reopened.schemaVersion);
  });

  test('drops the review column and keeps the other skip columns', () async {
    final dir = await Directory.systemTemp.createTemp('podavio-migration-v24');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/podavio.sqlite');

    final created = AppDatabase(NativeDatabase(file));
    await created.customSelect('SELECT 1').get();
    await created.customStatement(
      'ALTER TABLE skip_segments ADD COLUMN confirmed INTEGER',
    );
    final podcastId = (await created.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: 'Description',
        episodes: [
          EpisodeDraft(
            guid: 'a',
            title: 'Un',
            description: 'Notes',
            audioUrl: 'https://example.com/a.mp3',
          ),
        ],
      ),
    )).podcastId;
    final episodeId = (await created.watchEpisodes(podcastId: podcastId).first)
        .single
        .episode
        .id;
    final segmentId = await created.insertSkipSegment(
      episodeId: episodeId,
      startMs: 1000,
      endMs: 4000,
      kind: SkipSegmentKind.ad,
      source: SkipSegmentSource.manual,
    );
    await created.customStatement(
      'UPDATE skip_segments SET confirmed = 1 WHERE id = $segmentId',
    );
    await created.customStatement('PRAGMA user_version = 24');
    await created.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final columns = await reopened
        .customSelect('PRAGMA table_info(skip_segments)')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      isNot(contains('confirmed')),
    );
    final row = (await reopened.listSkipSegments(episodeId)).single;
    expect(row.id, segmentId);
    expect(row.startMs, 1000);
    expect(row.kind, SkipSegmentKind.ad);
    expect(await _userVersion(reopened), reopened.schemaVersion);
  });

  test('adds the dismissed-span table and keeps the skip row', () async {
    final dir = await Directory.systemTemp.createTemp('podavio-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/podavio.sqlite');

    final created = AppDatabase(NativeDatabase(file));
    final podcastId = (await created.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: 'Description',
        episodes: [
          EpisodeDraft(
            guid: 'a',
            title: 'Un',
            description: 'Notes',
            audioUrl: 'https://example.com/a.mp3',
          ),
        ],
      ),
    )).podcastId;
    final episodeId = (await created.watchEpisodes(podcastId: podcastId).first)
        .single
        .episode
        .id;
    final segmentId = await created.insertSkipSegment(
      episodeId: episodeId,
      startMs: 8000,
      endMs: 12000,
      kind: SkipSegmentKind.sting,
      source: SkipSegmentSource.fingerprint,
    );
    await created.customStatement('DROP TABLE dismissed_skip_spans');
    await created.customStatement('PRAGMA user_version = 25');
    await created.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final columns = await reopened
        .customSelect('PRAGMA table_info(dismissed_skip_spans)')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      containsAll(['episode_id', 'template_id', 'start_ms', 'end_ms']),
    );
    final row = (await reopened.listSkipSegments(episodeId)).single;
    expect(row.id, segmentId);
    expect(row.startMs, 8000);
    expect(row.kind, SkipSegmentKind.sting);
    expect(await _userVersion(reopened), reopened.schemaVersion);
  });
}
