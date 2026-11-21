import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/chapters_parser.dart';
import 'package:podavio/data/episode_audio_analyzer.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/skip_segments.dart';
import 'package:podavio/player/segment_skip.dart';

void main() {
  test('chapter titles that look like ads map to a skip kind', () {
    expect(skipKindForChapterTitle('Pub'), SkipSegmentKind.ad);
    expect(skipKindForChapterTitle('PUBLICITÉ'), SkipSegmentKind.ad);
    expect(skipKindForChapterTitle('publicite'), SkipSegmentKind.ad);
    expect(skipKindForChapterTitle('Page de pub'), SkipSegmentKind.ad);
    expect(skipKindForChapterTitle('Ad'), SkipSegmentKind.ad);
    expect(skipKindForChapterTitle('Advertisement'), SkipSegmentKind.ad);
    expect(skipKindForChapterTitle('pre-roll'), SkipSegmentKind.ad);
    expect(skipKindForChapterTitle('Werbung'), SkipSegmentKind.ad);
    expect(skipKindForChapterTitle('Publicidad'), SkipSegmentKind.ad);
    expect(skipKindForChapterTitle('Pubblicità'), SkipSegmentKind.ad);
    expect(skipKindForChapterTitle('広告'), SkipSegmentKind.ad);
    expect(skipKindForChapterTitle('Реклама'), SkipSegmentKind.ad);

    expect(skipKindForChapterTitle('Sponsorisé'), SkipSegmentKind.sponsor);
    expect(
      skipKindForChapterTitle('sponsorisé par Acme'),
      SkipSegmentKind.sponsor,
    );
    expect(
      skipKindForChapterTitle('Sponsored by Squarespace'),
      SkipSegmentKind.sponsor,
    );
    expect(skipKindForChapterTitle('Partenariat'), SkipSegmentKind.sponsor);
    expect(skipKindForChapterTitle('Спонсор'), SkipSegmentKind.sponsor);

    expect(skipKindForChapterTitle('Auto-promo'), SkipSegmentKind.selfPromo);
    expect(skipKindForChapterTitle('Self promo'), SkipSegmentKind.selfPromo);

    expect(skipKindForChapterTitle(''), isNull);
    expect(skipKindForChapterTitle('Interview'), isNull);
    expect(skipKindForChapterTitle('Adventure'), isNull);
    expect(skipKindForChapterTitle('Download'), isNull);
    expect(skipKindForChapterTitle('Publication'), isNull);
    expect(skipKindForChapterTitle('Read the show notes'), isNull);
    expect(skipKindForChapterTitle('Adaptation'), isNull);
  });

  test('auto-skip kinds and fingerprints round-trip', () {
    expect(decodeAutoSkipKinds('[]'), isEmpty);
    expect(decodeAutoSkipKinds('nope'), isEmpty);
    expect(decodeAutoSkipKinds('["ad","nope","sponsor","ad"]'), [
      SkipSegmentKind.ad,
      SkipSegmentKind.sponsor,
    ]);
    expect(
      encodeAutoSkipKinds(const [
        SkipSegmentKind.ad,
        SkipSegmentKind.ad,
        SkipSegmentKind.jingle,
      ]),
      '["ad","jingle"]',
    );

    final blob = encodeFingerprint(const [0x01020304, 0xffffffff]);
    expect(decodeFingerprint(blob), [0x01020304, 0xffffffff]);
    expect(chromaprintHopMicros, 125000);
  });

  test('placeholder analyzer does nothing', () async {
    const analyzer = PlaceholderEpisodeAudioAnalyzer();
    final file = File('${Directory.systemTemp.path}/podavio-missing-audio.bin');
    expect(await analyzer.computeFingerprint(file), isNull);
    await analyzer.findSegments(1);
  });

  test('queries store fingerprints, templates and reviews', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final podcastId = (await database.saveFeed(_draft())).podcastId;
    final episodeId = (await database.watchEpisodes(podcastId: podcastId).first)
        .single
        .episode
        .id;
    await database.setDownloadPath(episodeId, '/tmp/episode.mp3');

    final podcast = await database.getPodcast(podcastId);
    expect(podcast!.autoSkipAds, isFalse);
    expect(decodeAutoSkipKinds(podcast.autoSkipKinds), isEmpty);

    await database.setPodcastAutoSkip(
      podcastId,
      autoSkipAds: true,
      autoSkipKinds: const [SkipSegmentKind.ad, SkipSegmentKind.sponsor],
    );
    final updated = await database.getPodcast(podcastId);
    expect(updated!.autoSkipAds, isTrue);
    expect(decodeAutoSkipKinds(updated.autoSkipKinds), [
      SkipSegmentKind.ad,
      SkipSegmentKind.sponsor,
    ]);

    final bytes = encodeFingerprint(const [1, 2, 3, 4]);
    await database.upsertEpisodeFingerprint(
      episodeId: episodeId,
      data: bytes,
      hopMicros: chromaprintHopMicros,
    );
    await database.upsertEpisodeFingerprint(
      episodeId: episodeId,
      data: encodeFingerprint(const [9]),
      hopMicros: 100000,
    );
    final stored = await database.fingerprintForEpisode(episodeId);
    expect(decodeFingerprint(stored!.data), [9]);
    expect(stored.hopMicros, 100000);

    final templateId = await database.insertSegmentTemplate(
      podcastId: podcastId,
      kind: SkipSegmentKind.ad,
      label: 'Acme',
      fingerprint: bytes,
      durationMs: 20000,
      occurrences: 4,
    );
    final segmentId = await database.insertSkipSegment(
      episodeId: episodeId,
      startMs: 5000,
      endMs: 25000,
      kind: SkipSegmentKind.ad,
      source: SkipSegmentSource.fingerprint,
      matches: 4,
      templateId: templateId,
    );

    final preview = await database.previewTargetForTemplate(templateId);
    expect(preview?.episodeId, episodeId);
    expect(preview?.segmentId, segmentId);
    expect(preview?.startMs, 5000);

    var classification = await database
        .watchSkipClassification(podcastId)
        .first;
    expect(classification.templates.single.label, 'Acme');
    expect(classification.templates.single.occurrences, 4);
    expect(classification.segments, isEmpty);
    expect(classification.templateConfirmed[templateId], isNull);

    await database.setTemplateKind(templateId, SkipSegmentKind.sponsor);
    await database.setTemplateLabel(templateId, '  Squarespace  ');
    await database.setTemplateReview(templateId, confirmed: true);
    final segments = await database.listSkipSegments(episodeId);
    expect(segments.single.kind, SkipSegmentKind.sponsor);
    expect(segments.single.confirmed, isTrue);
    classification = await database.watchSkipClassification(podcastId).first;
    expect(classification.templates.single.label, 'Squarespace');
    expect(classification.templates.single.kind, SkipSegmentKind.sponsor);
    expect(classification.templateConfirmed[templateId], isTrue);

    await database.setTemplateReview(templateId, confirmed: false);
    classification = await database.watchSkipClassification(podcastId).first;
    expect(classification.templateConfirmed[templateId], isFalse);

    await database.setSkipSegmentReview(segmentId, confirmed: null);
    await database.deleteSegmentTemplate(templateId);
    expect(await database.listSkipSegments(episodeId), isEmpty);
    expect((await database.watchSegmentTemplates(podcastId).first), isEmpty);
  });

  test('chapter seeding creates and preserves skip segments', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final podcastId = (await database.saveFeed(_draft(seconds: 600))).podcastId;
    final episodeId = (await database.watchEpisodes(podcastId: podcastId).first)
        .single
        .episode
        .id;

    await database.replaceChapters(episodeId, [
      EpisodeChaptersCompanion.insert(
        episodeId: episodeId,
        startMs: 0,
        title: const Value('Introduction'),
        sortIndex: const Value(0),
      ),
      EpisodeChaptersCompanion.insert(
        episodeId: episodeId,
        startMs: 60000,
        title: const Value('Publicité'),
        sortIndex: const Value(1),
      ),
      EpisodeChaptersCompanion.insert(
        episodeId: episodeId,
        startMs: 90000,
        title: const Value('Interview'),
        sortIndex: const Value(2),
      ),
      EpisodeChaptersCompanion.insert(
        episodeId: episodeId,
        startMs: 500000,
        title: const Value('Sponsorisé'),
        sortIndex: const Value(3),
      ),
    ]);

    final seeded = await database.listSkipSegments(episodeId);
    expect(seeded, hasLength(2));
    expect(seeded[0].source, SkipSegmentSource.chapter);
    expect(seeded[0].kind, SkipSegmentKind.ad);
    expect(seeded[0].startMs, 60000);
    expect(seeded[0].endMs, 90000);
    expect(seeded[0].confirmed, isNull);
    expect(seeded[1].kind, SkipSegmentKind.sponsor);
    expect(seeded[1].startMs, 500000);
    expect(seeded[1].endMs, 600000);

    await database.setSkipSegmentReview(seeded[0].id, confirmed: false);
    await database.replaceChapters(episodeId, [
      EpisodeChaptersCompanion.insert(
        episodeId: episodeId,
        startMs: 60000,
        title: const Value('Pub'),
        sortIndex: const Value(0),
      ),
      EpisodeChaptersCompanion.insert(
        episodeId: episodeId,
        startMs: 90000,
        title: const Value('Suite'),
        sortIndex: const Value(1),
      ),
    ]);
    final again = await database.listSkipSegments(episodeId);
    expect(again, hasLength(1));
    expect(again.single.confirmed, isFalse);
    expect(again.single.kind, SkipSegmentKind.ad);

    final loose = await database.watchSkipClassification(podcastId).first;
    expect(loose.templates, isEmpty);
    expect(loose.segments.single.episodeTitle, 'Premier');
    expect(loose.segments.single.segment.id, again.single.id);
  });

  test('skip decision respects download, kinds, review and seek-back', () {
    final ad = SkipCandidate(
      id: 1,
      startMs: 10000,
      endMs: 30000,
      kind: SkipSegmentKind.ad,
      confirmed: null,
    );
    final sponsor = SkipCandidate(
      id: 2,
      startMs: 12000,
      endMs: 40000,
      kind: SkipSegmentKind.sponsor,
      confirmed: true,
    );
    final ignored = SkipCandidate(
      id: 3,
      startMs: 10000,
      endMs: 50000,
      kind: SkipSegmentKind.ad,
      confirmed: false,
    );
    const kinds = {SkipSegmentKind.ad, SkipSegmentKind.sponsor};
    final held = <int>{};

    expect(
      decideSkipSegment(
        positionMs: 15000,
        previousMs: 14000,
        playing: true,
        fromDownload: false,
        autoSkipAds: true,
        autoSkipKinds: kinds,
        segments: [ad],
        heldIds: held,
      ),
      isNull,
    );
    expect(
      decideSkipSegment(
        positionMs: 15000,
        previousMs: 14000,
        playing: true,
        fromDownload: true,
        autoSkipAds: false,
        autoSkipKinds: kinds,
        segments: [ad],
        heldIds: held,
      ),
      isNull,
    );
    expect(
      decideSkipSegment(
        positionMs: 15000,
        previousMs: 14000,
        playing: false,
        fromDownload: true,
        autoSkipAds: true,
        autoSkipKinds: kinds,
        segments: [ad],
        heldIds: held,
      ),
      isNull,
    );
    expect(
      decideSkipSegment(
        positionMs: 15000,
        previousMs: 14000,
        playing: true,
        fromDownload: true,
        autoSkipAds: true,
        autoSkipKinds: const {SkipSegmentKind.jingle},
        segments: [ad],
        heldIds: held,
      ),
      isNull,
    );
    expect(
      decideSkipSegment(
        positionMs: 15000,
        previousMs: 14000,
        playing: true,
        fromDownload: true,
        autoSkipAds: true,
        autoSkipKinds: kinds,
        segments: [ignored],
        heldIds: held,
      ),
      isNull,
    );
    expect(
      decideSkipSegment(
        positionMs: 30000,
        previousMs: 29000,
        playing: true,
        fromDownload: true,
        autoSkipAds: true,
        autoSkipKinds: kinds,
        segments: [ad],
        heldIds: held,
      ),
      isNull,
    );

    final chosen = decideSkipSegment(
      positionMs: 15000,
      previousMs: 14000,
      playing: true,
      fromDownload: true,
      autoSkipAds: true,
      autoSkipKinds: kinds,
      segments: [ad, sponsor, ignored],
      heldIds: held,
    );
    expect(chosen?.segmentId, sponsor.id);
    expect(chosen?.seekToMs, 40000);
    expect(chosen?.returnToMs, 15000);

    final unreviewed = decideSkipSegment(
      positionMs: 11000,
      previousMs: 10000,
      playing: true,
      fromDownload: true,
      autoSkipAds: true,
      autoSkipKinds: kinds,
      segments: [ad],
      heldIds: held,
    );
    expect(unreviewed?.seekToMs, 30000);

    final back = decideSkipSegment(
      positionMs: 15000,
      previousMs: 40000,
      playing: true,
      fromDownload: true,
      autoSkipAds: true,
      autoSkipKinds: kinds,
      segments: [ad, sponsor],
      heldIds: held,
    );
    expect(back, isNull);
    expect(held, containsAll([ad.id, sponsor.id]));

    final still = decideSkipSegment(
      positionMs: 16000,
      previousMs: 15000,
      playing: true,
      fromDownload: true,
      autoSkipAds: true,
      autoSkipKinds: kinds,
      segments: [ad, sponsor],
      heldIds: held,
    );
    expect(still, isNull);
  });

  test('an ad and the sting glued to it are one skip', () {
    final decision = decideSkipSegment(
      positionMs: 1000,
      previousMs: 0,
      playing: true,
      fromDownload: true,
      autoSkipAds: true,
      autoSkipKinds: const {SkipSegmentKind.ad},
      segments: [
        const SkipCandidate(
          id: 1,
          startMs: 0,
          endMs: 30000,
          kind: SkipSegmentKind.ad,
          confirmed: null,
        ),
        const SkipCandidate(
          id: 2,
          startMs: 30000,
          endMs: 33000,
          kind: SkipSegmentKind.jingle,
          confirmed: null,
        ),
        const SkipCandidate(
          id: 3,
          startMs: 33000,
          endMs: 40000,
          kind: SkipSegmentKind.intro,
          confirmed: null,
        ),
      ],
      heldIds: <int>{},
    );
    expect(decision?.seekToMs, 33000);

    final rejected = decideSkipSegment(
      positionMs: 1000,
      previousMs: 0,
      playing: true,
      fromDownload: true,
      autoSkipAds: true,
      autoSkipKinds: const {SkipSegmentKind.ad},
      segments: [
        const SkipCandidate(
          id: 1,
          startMs: 0,
          endMs: 30000,
          kind: SkipSegmentKind.ad,
          confirmed: null,
        ),
        const SkipCandidate(
          id: 2,
          startMs: 30000,
          endMs: 33000,
          kind: SkipSegmentKind.jingle,
          confirmed: false,
        ),
      ],
      heldIds: <int>{},
    );
    expect(rejected?.seekToMs, 30000);
  });
}

FeedDraft _draft({int seconds = 120}) {
  return FeedDraft(
    feedUrl: 'https://example.com/feed.xml',
    title: 'Essai',
    author: 'Auteur',
    description: 'Description',
    episodes: [
      EpisodeDraft(
        guid: 'ep-1',
        title: 'Premier',
        description: 'Notes',
        audioUrl: 'https://example.com/1.mp3',
        durationSeconds: seconds,
      ),
    ],
  );
}
