import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/audio_analysis.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/segment_edit.dart';
import 'package:podavio/data/segment_finder.dart';
import 'package:podavio/data/skip_segments.dart';
import 'package:podavio/ui/podcast/segment_waveform_page.dart';

const _hop = 123809;

AnalysisPlan _plan(int episodeId, int templateId, List<(int, int)> spans) {
  return AnalysisPlan([
    PlannedPattern(
      templateId: templateId,
      kind: SkipSegmentKind.ad,
      fingerprint: const [1, 2, 3, 4, 5, 6, 7, 8],
      durationMs: 20000,
      confidence: 80,
      segments: [
        for (final span in spans)
          PlannedSegment(
            episodeId: episodeId,
            startMs: span.$1,
            endMs: span.$2,
            kind: SkipSegmentKind.ad,
            matches: spans.length,
            confidence: 80,
          ),
      ],
    ),
  ]);
}

void main() {
  group('bornes', () {
    test('clampBounds garde l’épisode et une seconde au moins', () {
      expect(clampBounds(-800, 5000, durationMs: 60000), (
        startMs: 0,
        endMs: 5000,
      ));
      expect(clampBounds(4800, 4500, durationMs: 60000), (
        startMs: 4800,
        endMs: 5800,
      ));
      expect(clampBounds(59500, 61000, durationMs: 60000), (
        startMs: 59000,
        endMs: 60000,
      ));
    });

    test('sliceChromaprint coupe aux bornes, au pas de l’empreinte', () {
      final values = List<int>.generate(500, (i) => i * 7919);
      final slice = sliceChromaprint(
        encodeFingerprint(values),
        _hop,
        startMs: 10000,
        endMs: 20000,
      )!;
      final decoded = decodeFingerprint(slice);
      final from = (10000 * 1000 / _hop).floor();
      expect(decoded.first, values[from]);
      expect(decoded.length, closeTo(10000 * 1000 / _hop, 2));
      expect(
        sliceChromaprint(
          encodeFingerprint(values),
          _hop,
          startMs: 1000,
          endMs: 1500,
        ),
        isNull,
      );
    });

    test('waveformColumns : crête et RMS par colonne, silence à zéro', () {
      final envelope = Uint8List(500);
      for (var i = 100; i < 200; i++) {
        envelope[i] = 200;
      }
      final columns = waveformColumns(
        envelope,
        startMs: 0,
        endMs: 10000,
        columns: 5,
      );
      expect(columns, hasLength(5));
      expect(columns[0].peak, 0);
      expect(columns[1].peak, greaterThan(0.9));
      expect(columns[1].rms, closeTo(columns[1].peak, 1e-9));
      expect(columns[4].rms, 0);
    });
  });

  group('enregistrement', () {
    late AppDatabase database;
    late int podcastId;
    late int episodeId;
    final values = List<int>.generate(
      2000,
      (i) => (i * 2654435761) & 0xffffffff,
    );

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      podcastId = (await database.saveFeed(
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
              durationSeconds: 240,
            ),
          ],
        ),
      )).podcastId;
      final episodes = await database.watchEpisodes(podcastId: podcastId).first;
      episodeId = episodes.single.episode.id;
      await database.upsertEpisodeFingerprint(
        episodeId: episodeId,
        data: encodeFingerprint(values),
        hopMicros: _hop,
      );
    });

    tearDown(() => database.close());

    test('retaille le gabarit, valide le passage, garde la vérité', () async {
      final templateId = await database.insertSegmentTemplate(
        podcastId: podcastId,
        kind: SkipSegmentKind.ad,
        fingerprint: encodeFingerprint(values.sublist(80, 240)),
        durationMs: 20000,
      );
      final segmentId = await database.insertSkipSegment(
        episodeId: episodeId,
        startMs: 10000,
        endMs: 30000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.fingerprint,
        templateId: templateId,
      );

      await saveSegmentBounds(
        database,
        segmentId: segmentId,
        startMs: 11500,
        endMs: 29000,
      );

      final row = (await database.skipSegmentById(segmentId))!;
      expect((row.startMs, row.endMs), (11500, 29000));
      expect(row.source, SkipSegmentSource.manual);
      final template = (await database.listSegmentTemplates(podcastId)).single;
      expect(template.durationMs, 17500);
      expect(
        decodeFingerprint(template.fingerprint),
        values.sublist(
          (11500 * 1000 / _hop).floor(),
          (29000 * 1000 / _hop).ceil(),
        ),
      );
      final truth = (await database.listSegmentAnnotations()).single;
      expect(truth.segmentId, segmentId);
      expect(truth.detectedSource, 'fingerprint');
      expect((truth.detectedStartMs, truth.detectedEndMs), (10000, 30000));
      expect((truth.correctedStartMs, truth.correctedEndMs), (11500, 29000));
    });

    test('crée un gabarit pour un passage qui n’en avait pas', () async {
      final segmentId = await database.insertSkipSegment(
        episodeId: episodeId,
        startMs: 40000,
        endMs: 50000,
        kind: SkipSegmentKind.jingle,
        source: SkipSegmentSource.network,
      );
      await saveSegmentBounds(
        database,
        segmentId: segmentId,
        startMs: 40500,
        endMs: 50000,
      );
      final row = (await database.skipSegmentById(segmentId))!;
      final template = (await database.listSegmentTemplates(podcastId)).single;
      expect(row.templateId, template.id);
      expect(template.kind, SkipSegmentKind.jingle);
      expect(template.durationMs, 9500);
    });

    test('une nouvelle analyse ne déplace ni ne double le passage', () async {
      final segmentId = await database.insertSkipSegment(
        episodeId: episodeId,
        startMs: 10000,
        endMs: 30000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.fingerprint,
      );
      await saveSegmentBounds(
        database,
        segmentId: segmentId,
        startMs: 12000,
        endMs: 28000,
      );
      final template = (await database.listSegmentTemplates(podcastId)).single;

      await applyAnalysisPlan(
        database,
        podcastId,
        AnalysisPlan([
          PlannedPattern(
            templateId: template.id,
            kind: SkipSegmentKind.ad,
            fingerprint: values.sublist(80, 240),
            durationMs: 20000,
            confidence: 80,
            segments: [
              PlannedSegment(
                episodeId: episodeId,
                startMs: 10000,
                endMs: 30000,
                kind: SkipSegmentKind.ad,
                matches: 2,
                confidence: 80,
              ),
            ],
          ),
        ]),
      );
      await database.updateFingerprintSegment(
        id: segmentId,
        startMs: 0,
        endMs: 5000,
        matches: 1,
        templateId: null,
      );

      final rows = await database.listSkipSegments(episodeId);
      expect(rows, hasLength(1));
      expect((rows.single.startMs, rows.single.endMs), (12000, 28000));
      expect(rows.single.source, SkipSegmentSource.manual);
    });

    test('un passage retiré n’est pas recréé, un autre oui', () async {
      final templateId = await database.insertSegmentTemplate(
        podcastId: podcastId,
        kind: SkipSegmentKind.ad,
        fingerprint: encodeFingerprint(values.sublist(80, 240)),
        durationMs: 20000,
      );
      final segmentId = await database.insertSkipSegment(
        episodeId: episodeId,
        startMs: 10000,
        endMs: 30000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.fingerprint,
        templateId: templateId,
      );
      await database.dismissSkipSegment(segmentId);
      expect(await database.listSkipSegments(episodeId), isEmpty);
      final trace = await database.dismissedSpansForEpisode(episodeId);
      expect(trace.single.templateId, templateId);
      expect((trace.single.startMs, trace.single.endMs), (10000, 30000));

      await applyAnalysisPlan(
        database,
        podcastId,
        _plan(episodeId, templateId, [(11000, 29000), (120000, 140000)]),
        searchedTemplates: {templateId},
      );
      final rows = await database.listSkipSegments(episodeId);
      expect(rows, hasLength(1));
      expect((rows.single.startMs, rows.single.endMs), (120000, 140000));
      expect(rows.single.source, SkipSegmentSource.fingerprint);
    });

    test('un type modifié n’est ni réécrit ni retiré', () async {
      final templateId = await database.insertSegmentTemplate(
        podcastId: podcastId,
        kind: SkipSegmentKind.ad,
        fingerprint: encodeFingerprint(values.sublist(80, 240)),
        durationMs: 20000,
      );
      final segmentId = await database.insertSkipSegment(
        episodeId: episodeId,
        startMs: 10000,
        endMs: 30000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.fingerprint,
        templateId: templateId,
      );
      await database.setSkipSegmentKind(segmentId, SkipSegmentKind.intro);
      await applyAnalysisPlan(
        database,
        podcastId,
        _plan(episodeId, templateId, [(9000, 31000)]),
        searchedTemplates: {templateId},
      );
      final rows = await database.listSkipSegments(episodeId);
      expect(rows, hasLength(1));
      expect(rows.single.id, segmentId);
      expect(rows.single.kind, SkipSegmentKind.intro);
      expect(rows.single.source, SkipSegmentSource.manual);
      expect((rows.single.startMs, rows.single.endMs), (10000, 30000));
    });

    test('un type plus étroit mémorise les autres podcasts', () async {
      final otherPodcastId = (await database.saveFeed(
        const FeedDraft(
          feedUrl: 'https://example.com/other.xml',
          title: 'Autre',
          author: 'Auteur',
          description: 'Description',
          episodes: [
            EpisodeDraft(
              guid: 'b',
              title: 'Deux',
              description: 'Notes',
              audioUrl: 'https://example.com/b.mp3',
            ),
          ],
        ),
      )).podcastId;
      final otherEpisodeId =
          (await database.watchEpisodes(podcastId: otherPodcastId).first)
              .single
              .episode
              .id;
      final templateId = await database.insertSegmentTemplate(
        podcastId: podcastId,
        kind: SkipSegmentKind.ad,
        fingerprint: encodeFingerprint(values.sublist(80, 240)),
        durationMs: 4000,
      );
      await database.insertSkipSegment(
        episodeId: episodeId,
        startMs: 1000,
        endMs: 5000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.fingerprint,
        templateId: templateId,
      );
      await database.insertSkipSegment(
        episodeId: otherEpisodeId,
        startMs: 5000,
        endMs: 9000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.fingerprint,
        templateId: templateId,
      );
      await database.setTemplateKind(templateId, SkipSegmentKind.intro);
      expect(await database.listSkipSegments(otherEpisodeId), isEmpty);
      final trace = await database.dismissedSpansForEpisode(otherEpisodeId);
      expect(trace.single.templateId, templateId);
      expect((trace.single.startMs, trace.single.endMs), (5000, 9000));
      expect(
        (await database.listSkipSegments(episodeId)).single.source,
        SkipSegmentSource.manual,
      );

      await database.setTemplateKind(templateId, SkipSegmentKind.ad);
      await applyAnalysisPlan(
        database,
        otherPodcastId,
        _plan(otherEpisodeId, templateId, [(4800, 9200)]),
        searchedTemplates: {templateId},
      );
      expect(await database.listSkipSegments(otherEpisodeId), isEmpty);
      final kept = (await database.listSkipSegments(episodeId)).single;
      expect(kept.source, SkipSegmentSource.manual);
      expect((kept.startMs, kept.endMs), (1000, 5000));
    });

    test('l’analyse n’efface pas un passage passé en manual', () async {
      final keptId = await database.insertSkipSegment(
        episodeId: episodeId,
        startMs: 1000,
        endMs: 4000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.fingerprint,
      );
      await database.setSkipSegmentKind(keptId, SkipSegmentKind.sting);
      await database.deleteDetectedSkipSegment(keptId);
      final kept = await database.skipSegmentById(keptId);
      expect(kept?.source, SkipSegmentSource.manual);
      expect((kept?.startMs, kept?.endMs), (1000, 4000));

      final detectedId = await database.insertSkipSegment(
        episodeId: episodeId,
        startMs: 60000,
        endMs: 70000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.fingerprint,
      );
      await database.deleteDetectedSkipSegment(detectedId);
      expect(await database.skipSegmentById(detectedId), isNull);
    });
  });

  group('forme d’onde', () {
    Future<List<(int, int)>> pump(
      WidgetTester tester, {
      List<(int, int)>? listened,
      ValueNotifier<int?>? playhead,
    }) async {
      final saved = <(int, int)>[];
      final envelope = Uint8List(60000 ~/ 20);
      for (var i = 0; i < envelope.length; i++) {
        envelope[i] = (i ~/ 25).isEven ? 120 : 30;
      }
      await tester.pumpWidget(
        MaterialApp(
          home: _WaveHost(
            envelope: envelope,
            playhead: playhead,
            onListen: (from, to) async => listened?.add((from, to)),
            onSave: (start, end) {
              saved.add((start, end));
            },
          ),
        ),
      );
      return saved;
    }

    testWidgets('±0,5 s déplace les bornes et Enregistrer les renvoie', (
      tester,
    ) async {
      final saved = await pump(tester);
      expect(find.byType(CustomPaint), findsWidgets);
      await tester.tap(find.byKey(const Key('start-minus')));
      await tester.tap(find.byKey(const Key('end-plus')));
      await tester.tap(find.byKey(const Key('end-plus')));
      await tester.pump();
      expect(find.text('0:19.5'), findsOneWidget);
      expect(find.text('0:31.0'), findsOneWidget);
      await tester.tap(find.text('Enregistrer'));
      await tester.pump();
      expect(saved, [(19500, 31000)]);
    });

    testWidgets('glisser hors des poignées déplace la vue', (tester) async {
      final saved = await pump(tester);
      final wave = find.byKey(const Key('waveform'));
      final box = tester.getRect(wave);
      await tester.dragFrom(
        Offset(box.left + box.width / 2, box.center.dy),
        Offset(box.width / 10, 0),
      );
      await tester.pump();
      expect(find.text('0:10.0'), findsOneWidget);
      await tester.tap(find.text('Enregistrer'));
      await tester.pump();
      expect(saved, [(20000, 30000)]);
    });

    testWidgets('glisser une poignée la déplace', (tester) async {
      final saved = await pump(tester);
      final wave = find.byKey(const Key('waveform'));
      final box = tester.getRect(wave);
      // Vue initiale 10–40 s : le début (20 s) est au tiers de la largeur.
      final from = Offset(box.left + box.width / 3, box.center.dy);
      await tester.dragFrom(from, Offset(box.width / 30, 0));
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await tester.pump();
      expect(saved.single.$1, greaterThan(20500));
      expect(saved.single.$1, lessThan(21500));
      expect(saved.single.$2, 30000);
    });

    testWidgets('écoute autour de la coupe et depuis le curseur', (
      tester,
    ) async {
      final listened = <(int, int)>[];
      await pump(tester, listened: listened);
      await tester.tap(find.byTooltip('Écouter autour de la coupe').first);
      await tester.tap(find.text('Lire depuis le curseur'));
      expect(listened, [(18000, 22000), (20000, 30000)]);
    });

    testWidgets('zoom, cursor and playhead keep working', (tester) async {
      final listened = <(int, int)>[];
      final playhead = ValueNotifier<int?>(12000);
      addTearDown(playhead.dispose);
      final saved = await pump(tester, listened: listened, playhead: playhead);
      // Durée du passage et début de vue : les deux affichent 0:10.0.
      expect(find.text('0:10.0'), findsNWidgets(2));

      playhead.value = 25000;
      await tester.pump();
      playhead.value = 26000;
      await tester.pump();
      await tester.tap(find.text('Lire depuis le curseur'));
      expect(listened, [(20000, 30000)]);

      await tester.tap(find.byTooltip('Zoomer'));
      await tester.pump();
      // La vue s’est resserrée : seul le libellé de durée reste à 0:10.0.
      expect(find.text('0:10.0'), findsOneWidget);

      final wave = find.byKey(const Key('waveform'));
      final box = tester.getRect(wave);
      // Après zoom, la vue 17,5–32,5 s place le début (20 s) au sixième.
      await tester.dragFrom(
        Offset(box.left + box.width / 6, box.center.dy),
        Offset(box.width / 30, 0),
      );
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await tester.pump();
      expect(saved.single.$1, greaterThan(20000));
      expect(saved.single.$2, 30000);
    });
  });
}

class _WaveHost extends StatefulWidget {
  const _WaveHost({
    required this.envelope,
    required this.onListen,
    required this.onSave,
    this.playhead,
  });

  final Uint8List envelope;
  final ValueNotifier<int?>? playhead;
  final Future<void> Function(int from, int to) onListen;
  final void Function(int start, int end) onSave;

  @override
  State<_WaveHost> createState() => _WaveHostState();
}

class _WaveHostState extends State<_WaveHost> {
  var _start = 20000;
  var _end = 30000;

  void _move({required bool start, required int ms}) {
    final bounds = start
        ? clampBounds(ms, _end, durationMs: 60000)
        : clampBounds(_start, ms, durationMs: 60000);
    setState(() {
      _start = bounds.startMs;
      _end = bounds.endMs;
    });
  }

  Future<void> _around(int cutMs) {
    return widget.onListen(
      math.max(0, cutMs - cutPreviewMs),
      math.min(60000, cutMs + cutPreviewMs),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => widget.onSave(_start, _end),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
      body: ListView(
        children: [
          SegmentWaveform(
            envelope: widget.envelope,
            durationMs: 60000,
            startMs: _start,
            endMs: _end,
            playhead: widget.playhead,
            onBounds: (start, end) => setState(() {
              _start = start;
              _end = end;
            }),
            onListen: widget.onListen,
          ),
          BoundControls(
            id: 'start',
            label: 'Début',
            valueMs: _start,
            onStep: (delta) => _move(start: true, ms: _start + delta),
            onListen: () => _around(_start),
          ),
          BoundControls(
            id: 'end',
            label: 'Fin',
            valueMs: _end,
            onStep: (delta) => _move(start: false, ms: _end + delta),
            onListen: () => _around(_end),
          ),
        ],
      ),
    );
  }
}
