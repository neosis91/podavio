import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/analysis_overview.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/audio_analysis.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/segment_edit.dart';
import 'package:podavio/data/segment_finder.dart';
import 'package:podavio/data/skip_segments.dart';
import 'package:podavio/ui/podcast/passage_creation.dart';
import 'package:podavio/ui/podcast/segment_waveform_page.dart';

const _hop = 123809;

void main() {
  test('initialCreatedBounds part de la position, dans l’épisode', () {
    expect(initialCreatedBounds(10000, durationMs: 240000), (
      startMs: 10000,
      endMs: 10000 + createdSegmentDefaultMs,
    ));
    expect(initialCreatedBounds(235000, durationMs: 240000), (
      startMs: 235000,
      endMs: 240000,
    ));
    expect(initialCreatedBounds(240000, durationMs: 240000), (
      startMs: 239000,
      endMs: 240000,
    ));
  });

  group('création', () {
    late AppDatabase database;
    late int podcastId;
    late int first;
    late int second;
    final values = List<int>.generate(
      2000,
      (i) => (i * 2654435761) & 0xffffffff,
    );

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      podcastId = (await database.saveFeed(
        FeedDraft(
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
              durationSeconds: 240,
              publishedAt: DateTime.utc(2026, 1, 1),
            ),
            EpisodeDraft(
              guid: 'b',
              title: 'Deux',
              description: 'Notes',
              audioUrl: 'https://example.com/b.mp3',
              durationSeconds: 240,
              publishedAt: DateTime.utc(2026, 2, 1),
            ),
          ],
        ),
      )).podcastId;
      final episodes = await database.watchEpisodes(podcastId: podcastId).first;
      first = episodes.firstWhere((e) => e.episode.guid == 'a').episode.id;
      second = episodes.firstWhere((e) => e.episode.guid == 'b').episode.id;
      await database.upsertEpisodeFingerprint(
        episodeId: first,
        data: encodeFingerprint(values),
        hopMicros: _hop,
      );
    });

    tearDown(() => database.close());

    test('gabarit coupé et nommé, passage manuel confirmé, vérité sans '
        'bornes détectées', () async {
      final created = await createManualSegment(
        database,
        episodeId: first,
        startMs: 20000,
        endMs: 50000,
        kind: SkipSegmentKind.selfPromo,
        label: '  Autopromo du réseau ',
      );
      final row = (await database.skipSegmentById(created.segmentId!))!;
      expect(row.source, SkipSegmentSource.manual);
      expect(row.confirmed, isTrue);
      expect(row.kind, SkipSegmentKind.selfPromo);
      final template = (await database.listSegmentTemplates(podcastId)).single;
      expect(row.templateId, template.id);
      expect(template.label, 'Autopromo du réseau');
      expect(template.durationMs, 30000);
      expect(
        decodeFingerprint(template.fingerprint),
        values.sublist(
          (20000 * 1000 / _hop).floor(),
          (50000 * 1000 / _hop).ceil(),
        ),
      );
      final truth = (await database.listSegmentAnnotations()).single;
      expect(truth.segmentId, row.id);
      expect(truth.detectedSource, isNull);
      expect(truth.detectedStartMs, isNull);
      expect(truth.detectedEndMs, isNull);
      expect((truth.correctedStartMs, truth.correctedEndMs), (20000, 50000));
      expect(await database.isCreatedSegment(row.id), isTrue);
    });

    test('chevauchements : refusé sur un manuel, remplace un détecté '
        'couvert, garde chapitres et recouvrements faibles', () async {
      final detected = await database.insertSkipSegment(
        episodeId: first,
        startMs: 21000,
        endMs: 45000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.fingerprint,
      );
      final edge = await database.insertSkipSegment(
        episodeId: first,
        startMs: 48000,
        endMs: 90000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.fingerprint,
      );
      final chapter = await database.insertSkipSegment(
        episodeId: first,
        startMs: 20000,
        endMs: 40000,
        kind: SkipSegmentKind.sponsor,
        source: SkipSegmentSource.chapter,
      );
      final created = await createManualSegment(
        database,
        episodeId: first,
        startMs: 20000,
        endMs: 50000,
        kind: SkipSegmentKind.ad,
      );
      expect(created.segmentId, isNotNull);
      final ids = {
        for (final row in await database.listSkipSegments(first)) row.id,
      };
      expect(ids, {created.segmentId, edge, chapter});
      expect(ids.contains(detected), isFalse);

      final refused = await createManualSegment(
        database,
        episodeId: first,
        startMs: 49000,
        endMs: 60000,
        kind: SkipSegmentKind.jingle,
      );
      expect(refused.segmentId, isNull);
      expect(refused.overlap?.id, created.segmentId);
      expect(await database.listSegmentTemplates(podcastId), hasLength(1));
    });

    test('retrouvé dans un autre épisode, jamais réécrit chez lui', () async {
      final created = await createManualSegment(
        database,
        episodeId: first,
        startMs: 20000,
        endMs: 50000,
        kind: SkipSegmentKind.ad,
      );
      final template = (await database.listSegmentTemplates(podcastId)).single;
      await applyAnalysisPlan(
        database,
        podcastId,
        AnalysisPlan([
          PlannedPattern(
            templateId: template.id,
            kind: SkipSegmentKind.ad,
            confirmed: true,
            fingerprint: decodeFingerprint(template.fingerprint),
            durationMs: 30000,
            confidence: 90,
            segments: [
              PlannedSegment(
                episodeId: first,
                startMs: 19000,
                endMs: 51000,
                kind: SkipSegmentKind.ad,
                confirmed: true,
                matches: 2,
                confidence: 90,
              ),
              PlannedSegment(
                episodeId: second,
                startMs: 70000,
                endMs: 100000,
                kind: SkipSegmentKind.ad,
                confirmed: true,
                matches: 2,
                confidence: 90,
              ),
            ],
          ),
        ]),
      );
      final own = await database.listSkipSegments(first);
      expect(own.single.id, created.segmentId);
      expect((own.single.startMs, own.single.endMs), (20000, 50000));
      final found = (await database.listSkipSegments(second)).single;
      expect(found.templateId, template.id);
      expect(found.source, SkipSegmentSource.fingerprint);
      expect(found.confirmed, isTrue);
    });

    test(
      'sans empreinte, le gabarit garde le nom et attend l’analyse',
      () async {
        final created = await createManualSegment(
          database,
          episodeId: second,
          startMs: 5000,
          endMs: 15000,
          kind: SkipSegmentKind.intro,
          label: 'Générique',
        );
        expect(created.segmentId, isNotNull);
        final template = (await database.listSegmentTemplates(podcastId))
            .single;
        expect(template.label, 'Générique');
        expect(template.fingerprint, isEmpty);
      },
    );

    test('supprimer une portion créée retire son gabarit et ses '
        'occurrences, garde la vérité', () async {
      final created = await createManualSegment(
        database,
        episodeId: first,
        startMs: 20000,
        endMs: 50000,
        kind: SkipSegmentKind.ad,
      );
      final template = (await database.listSegmentTemplates(podcastId)).single;
      await database.insertSkipSegment(
        episodeId: second,
        startMs: 70000,
        endMs: 100000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.fingerprint,
        templateId: template.id,
      );
      await deleteManualSegment(database, created.segmentId!);
      expect(await database.listSkipSegments(first), isEmpty);
      expect(await database.listSkipSegments(second), isEmpty);
      expect(await database.listSegmentTemplates(podcastId), isEmpty);
      expect(await database.listSegmentAnnotations(), hasLength(1));
    });

    test(
      'supprimer un passage corrigé ne touche pas au gabarit détecté',
      () async {
        final templateId = await database.insertSegmentTemplate(
          podcastId: podcastId,
          kind: SkipSegmentKind.ad,
          fingerprint: encodeFingerprint(values.sublist(80, 240)),
          durationMs: 20000,
        );
        final segmentId = await database.insertSkipSegment(
          episodeId: first,
          startMs: 10000,
          endMs: 30000,
          kind: SkipSegmentKind.ad,
          source: SkipSegmentSource.fingerprint,
          templateId: templateId,
        );
        await saveSegmentBounds(
          database,
          segmentId: segmentId,
          startMs: 11000,
          endMs: 30000,
        );
        await deleteManualSegment(database, segmentId);
        expect(await database.skipSegmentById(segmentId), isNull);
        expect(await database.listSegmentTemplates(podcastId), hasLength(1));
      },
    );

    test('choix d’épisode : analysés d’abord, puis téléchargés', () async {
      await database.setDownloadPath(first, '/tmp/a.mp3');
      await database.setDownloadPath(second, '/tmp/b.mp3');
      await database.setFingerprintEnvelope(
        first,
        Uint8List.fromList(List.filled(100, 60)),
      );
      final choices = await database.passageEpisodeChoices(podcastId);
      expect([for (final c in choices) c.episodeId], [first, second]);
      expect(choices.first.analysed, isTrue);
      expect(choices.last.analysed, isFalse);
      expect(choices.last.downloaded, isTrue);
    });

    test('la page des analyses compte les portions posées à la main', () async {
      await database.setDownloadPath(first, '/tmp/a.mp3');
      await createManualSegment(
        database,
        episodeId: first,
        startMs: 20000,
        endMs: 50000,
        kind: SkipSegmentKind.other,
      );
      final facts = await database.watchAnalysisFacts().first;
      expect(facts.manual, {podcastId: 1});
      final rows = buildAnalysisOverview(
        catalog: [
          for (final row in facts.catalog)
            AnalysisCatalogPodcast(id: row.id, title: row.title),
        ],
        downloads: [
          for (final row in facts.downloads)
            AnalysisDownloadFact(
              podcastId: row.podcastId,
              audioUrl: row.audioUrl,
              fingerprintStatus: row.status,
            ),
        ],
        segments: const [],
        manualSegments: facts.manual,
      );
      expect(rows.single.manualSegments, 1);
    });
  });

  test('segment_annotations : l’ancienne table stricte est recopiée', () async {
    final dir = await Directory.systemTemp.createTemp('podavio-annotations');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/podavio.sqlite');
    final created = AppDatabase(NativeDatabase(file));
    await created.customStatement('DROP TABLE segment_annotations');
    await created.customStatement(
      'CREATE TABLE segment_annotations ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'segment_id INTEGER NOT NULL, episode_id INTEGER NOT NULL, '
      'kind TEXT NOT NULL, detected_source TEXT NOT NULL, '
      'detected_start_ms INTEGER NOT NULL, detected_end_ms INTEGER NOT NULL, '
      'corrected_start_ms INTEGER NOT NULL, '
      'corrected_end_ms INTEGER NOT NULL, created_at INTEGER NOT NULL)',
    );
    await created.customStatement(
      'INSERT INTO segment_annotations VALUES '
      "(1, 7, 3, 'ad', 'fingerprint', 1000, 9000, 1500, 9000, 0)",
    );
    await created.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    await reopened.insertSegmentAnnotation(
      segmentId: 8,
      episodeId: 3,
      kind: SkipSegmentKind.jingle,
      correctedStartMs: 0,
      correctedEndMs: 2000,
    );
    final rows = await reopened.listSegmentAnnotations();
    expect(rows, hasLength(2));
    expect(rows.first.detectedSource, 'fingerprint');
    expect(rows.first.detectedStartMs, 1000);
    expect(rows.last.detectedSource, isNull);
    expect(await reopened.isCreatedSegment(8), isTrue);
    expect(await reopened.isCreatedSegment(7), isFalse);
  });

  testWidgets('placer une borne à la position de lecture', (tester) async {
    var here = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BoundControls(
                id: 'start',
                label: 'Début',
                valueMs: 0,
                onStep: (_) {},
                onListen: () {},
                onHere: () => here++,
              ),
              BoundControls(
                id: 'end',
                label: 'Fin',
                valueMs: 0,
                onStep: (_) {},
                onListen: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('end-here')), findsNothing);
    await tester.tap(find.byKey(const Key('start-here')));
    expect(here, 1);
  });

  testWidgets('le choix d’épisode affiche l’état et renvoie l’id', (
    tester,
  ) async {
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => const Scaffold(
                    body: PassageEpisodePicker(
                      choices: [
                        PassageEpisodeChoice(
                          episodeId: 4,
                          title: 'Analysé',
                          downloaded: true,
                          analysed: true,
                        ),
                        PassageEpisodeChoice(
                          episodeId: 5,
                          title: 'Distant',
                          downloaded: false,
                          analysed: false,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Non téléchargé'), findsOneWidget);
    await tester.tap(find.text('Analysé').first);
    await tester.pumpAndSettle();
    expect(picked, 4);
  });
}
