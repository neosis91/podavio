import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/audio_analysis.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/pcm_decoder.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/data/segment_edit.dart';
import 'package:podavio/data/segment_match.dart';
import 'package:podavio/data/skip_segments.dart';
import 'package:podavio/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a long episode is given more than six minutes to decode', () {
    expect(analysisBudgetFor(25 * 60), const Duration(minutes: 8, seconds: 15));
    expect(
      analysisBudgetFor(51 * 60 + 6),
      const Duration(seconds: (51 * 60 + 6) ~/ 4 + 120),
    );
    expect(
      analysisBudgetFor(95 * 60),
      greaterThan(const Duration(minutes: 20)),
    );
    expect(analysisBudgetFor(5 * 3600), audioAnalysisBudgetCeiling);
    expect(
      nativeDecodeBudgetFor(analysisBudgetFor(62 * 60)),
      greaterThan(const Duration(minutes: 12)),
    );
    expect(
      nativeDecodeBudgetFor(const Duration(milliseconds: 30)),
      const Duration(milliseconds: 30),
    );
  });

  test('remaining time follows the length of the audio', () {
    final now = DateTime.utc(2026, 11, 21, 16);
    final left = estimateAnalysisRemaining(
      podcastId: 16,
      runningPodcastId: 45,
      runningDurationSeconds: 321,
      runningSince: now.subtract(const Duration(seconds: 20)),
      now: now,
      pending: [(podcastId: 16, durationSeconds: 1172)],
      measuredMs: 0,
      measuredAudioSeconds: 0,
    );
    expect(left, const Duration(milliseconds: 321 * 150 - 20000 + 1172 * 150));

    final measured = estimateAnalysisRemaining(
      podcastId: 121,
      runningPodcastId: 121,
      runningDurationSeconds: 1512,
      runningSince: now,
      now: now,
      pending: const [],
      measuredMs: 216614,
      measuredAudioSeconds: 1447,
    );
    expect(measured, const Duration(milliseconds: 1512 * 216614 ~/ 1447));
  });

  test('without a hand-made passage, analysis detects nothing', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final motif = _motif(100, 4);
    final podcastId = (await database.saveFeed(
      _draft([_episodeDraft('a', 'Un'), _episodeDraft('b', 'Deux')]),
    )).podcastId;
    final ids = await _ids(database, podcastId);
    await _ready(database, ids.a, _placed(1500, 1, 80, motif));
    await _ready(database, ids.b, _placed(1500, 2, 600, motif));
    final old = await database.insertSkipSegment(
      episodeId: ids.a,
      startMs: 1000,
      endMs: 9000,
      kind: SkipSegmentKind.ad,
      source: SkipSegmentSource.fingerprint,
    );

    await syncPodcastAnalysis(database, podcastId);

    expect(await database.listSegmentTemplates(podcastId), isEmpty);
    final rows = [
      ...await database.listSkipSegments(ids.a),
      ...await database.listSkipSegments(ids.b),
    ];
    expect(rows.map((row) => row.id), [old]);
    expect(await database.listActiveSkipSegments(ids.a), isEmpty);
  });

  test('a publicité is searched in every podcast', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final ad = _motif(100, 11);
    final promo = _motif(100, 12);
    final firstId = (await database.saveFeed(
      _draft([_episodeDraft('a', 'Un')], url: 'https://a.example/feed.xml'),
    )).podcastId;
    final secondId = (await database.saveFeed(
      _draft([_episodeDraft('b', 'Deux')], url: 'https://b.example/feed.xml'),
    )).podcastId;
    final origin = (await database.watchEpisodes(podcastId: firstId).first)
        .single
        .episode
        .id;
    final elsewhere = (await database.watchEpisodes(podcastId: secondId).first)
        .single
        .episode
        .id;
    await _ready(database, origin, _placed(1500, 1, 80, ad));
    await _ready(database, elsewhere, _placed(1500, 2, 400, ad));
    await createManualSegment(
      database,
      episodeId: origin,
      startMs: _msAt(80, ceil: true),
      endMs: _msAt(180),
      kind: SkipSegmentKind.ad,
    );
    await createManualSegment(
      database,
      episodeId: origin,
      startMs: _msAt(300, ceil: true),
      endMs: _msAt(400),
      kind: SkipSegmentKind.selfPromo,
    );

    await syncPodcastAnalysis(database, secondId);

    final found = await database.listActiveSkipSegments(elsewhere);
    expect(found, hasLength(1));
    expect(found.single.kind, SkipSegmentKind.ad);
    expect(found.single.source, SkipSegmentSource.fingerprint);
    expect(found.single.startMs, closeTo(_msAt(400), 1500));
    expect(await database.listSegmentTemplates(secondId), isEmpty);
  });

  test(
    'a hand-made passage is searched in the other episodes, idempotently',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final motif = _motif(100, 6);
      final podcastId = (await database.saveFeed(
        _draft([_episodeDraft('a', 'Un'), _episodeDraft('b', 'Deux')]),
      )).podcastId;
      final ids = await _ids(database, podcastId);
      await _ready(database, ids.a, _placed(1500, 1, 90, motif));
      await _ready(database, ids.b, _placed(1500, 2, 640, motif));
      final created = await createManualSegment(
        database,
        episodeId: ids.a,
        startMs: _msAt(90, ceil: true),
        endMs: _msAt(190),
        kind: SkipSegmentKind.selfPromo,
      );

      await syncPodcastAnalysis(database, podcastId);
      await syncPodcastAnalysis(database, podcastId);

      final template = (await database.listSegmentTemplates(podcastId)).single;
      final own = await database.listSkipSegments(ids.a);
      expect(own.single.id, created.segmentId);
      expect(own.single.source, SkipSegmentSource.manual);
      final found = await database.listActiveSkipSegments(ids.b);
      expect(found, hasLength(1));
      expect(found.single.templateId, template.id);
      expect(found.single.source, SkipSegmentSource.fingerprint);
      expect(found.single.kind, SkipSegmentKind.selfPromo);
      expect(found.single.confirmed, isTrue);
      expect(found.single.startMs, closeTo(_msAt(640), 1500));

      final thirdId = await _addEpisode(database, podcastId, 'c', 'Trois');
      await _ready(database, thirdId, _placed(1500, 3, 1000, motif));
      await syncPodcastAnalysis(database, podcastId);
      expect(
        (await database.listActiveSkipSegments(ids.b)).single.id,
        found.single.id,
      );
      expect(await database.listActiveSkipSegments(thirdId), hasLength(1));
    },
  );

  test(
    'deleting a download drops its fingerprint and found occurrences',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final motif = _motif(100, 8);
      final podcastId = (await database.saveFeed(
        _draft([_episodeDraft('a', 'Un'), _episodeDraft('b', 'Deux')]),
      )).podcastId;
      final ids = await _ids(database, podcastId);
      await _ready(database, ids.a, _placed(1500, 1, 80, motif));
      await _ready(database, ids.b, _placed(1500, 2, 500, motif));
      await createManualSegment(
        database,
        episodeId: ids.a,
        startMs: _msAt(80, ceil: true),
        endMs: _msAt(180),
        kind: SkipSegmentKind.ad,
      );
      await syncPodcastAnalysis(database, podcastId);
      expect(
        await database.fingerprintSegmentsForPodcast(podcastId),
        hasLength(1),
      );

      await database.setDownloadPath(ids.b, null);

      expect(await database.fingerprintForEpisode(ids.b), isNull);
      expect(await database.fingerprintSegmentsForPodcast(podcastId), isEmpty);
      final left = await database.listSkipSegments(ids.a);
      expect(left.single.source, SkipSegmentSource.manual);
      expect(await database.listSegmentTemplates(podcastId), hasLength(1));
    },
  );

  test(
    'the queue fingerprints two downloads and finds a hand-made passage',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final ad = _sweep(chromaprintSampleRate * 20, 220);
      final podcastId = (await database.saveFeed(
        _draft([_episodeDraft('a', 'Un'), _episodeDraft('b', 'Deux')]),
      )).podcastId;
      final episodes = await database.watchEpisodes(podcastId: podcastId).first;
      final first = episodes[0].episode;
      final second = episodes[1].episode;
      final atA = chromaprintHopSamples * 20;
      final atB = chromaprintHopSamples * 80;
      final pcm = {
        '/tmp/a.pcm': _mix(_bed(30, 90), ad, atA),
        '/tmp/b.pcm': _mix(_bed(30, 140), ad, atB),
      };
      await database.setDownloadPath(first.id, '/tmp/a.pcm');
      await database.setDownloadPath(second.id, '/tmp/b.pcm');

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          pcmDecoderProvider.overrideWithValue(_MapDecoder(pcm)),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(audioAnalysisProvider.notifier);
      await notifier.analyzeDownloaded(podcastId);

      expect(await database.fingerprintForEpisode(first.id), isNotNull);
      expect(await database.fingerprintForEpisode(second.id), isNotNull);
      expect(await database.envelopeForEpisode(first.id), isNotNull);
      expect(await database.listSkipSegments(first.id), isEmpty);
      expect(await database.listSkipSegments(second.id), isEmpty);

      final adStartMs = atA * 1000 ~/ chromaprintSampleRate;
      await createManualSegment(
        database,
        episodeId: first.id,
        startMs: adStartMs,
        endMs: adStartMs + 20000,
        kind: SkipSegmentKind.ad,
      );
      await notifier.analyzeDownloaded(podcastId);

      final found = await database.listActiveSkipSegments(second.id);
      expect(found, hasLength(1));
      expect(found.single.source, SkipSegmentSource.fingerprint);
      final expected = atB * 1000 ~/ chromaprintSampleRate;
      expect(found.single.startMs, closeTo(expected, 1500));
      expect(found.single.endMs - found.single.startMs, greaterThan(15000));
      expect(container.read(audioAnalysisProvider).pendingFor(podcastId), 0);
    },
  );

  test('enqueueing the same episode twice decodes it once', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final podcastId = (await database.saveFeed(
      _draft([_episodeDraft('a', 'Un')]),
    )).podcastId;
    final episode = (await database.watchEpisodes(podcastId: podcastId).first)
        .single
        .episode;
    await database.setDownloadPath(episode.id, '/tmp/a.pcm');
    final pcm = Int16List(chromaprintSampleRate);
    final decoder = _CountingDecoder({
      '/tmp/a.pcm': pcm,
    }, delay: const Duration(milliseconds: 40));
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        pcmDecoderProvider.overrideWithValue(decoder),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(audioAnalysisProvider.notifier);
    await Future.wait([
      notifier.enqueueEpisode(episode.id),
      notifier.enqueueEpisode(episode.id),
    ]);
    expect(decoder.calls, 1);
  });

  test(
    'a hung decode is marked failed and is not resumed automatically',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final podcastId = (await database.saveFeed(
        _draft([_episodeDraft('a', 'Un'), _episodeDraft('b', 'Deux')]),
      )).podcastId;
      final episodes = await database.watchEpisodes(podcastId: podcastId).first;
      final first = episodes[0].episode;
      final second = episodes[1].episode;
      await database.setDownloadPath(first.id, '/tmp/a.pcm');
      await database.setDownloadPath(second.id, '/tmp/b.pcm');
      final decoder = _CountingDecoder(
        {
          '/tmp/a.pcm': Int16List(chromaprintSampleRate),
          '/tmp/b.pcm': Int16List(chromaprintSampleRate),
        },
        hang: {'/tmp/a.pcm'},
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          pcmDecoderProvider.overrideWithValue(decoder),
          audioAnalysisBudgetProvider.overrideWithValue(
            const Duration(milliseconds: 30),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(audioAnalysisProvider.notifier);
      await notifier.enqueueEpisode(first.id);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(await database.fingerprintStatus(first.id), 'failed');
      final before = decoder.callsFor('/tmp/a.pcm');
      await notifier.enqueueMissing();
      expect(decoder.callsFor('/tmp/a.pcm'), before);
      await notifier.enqueueEpisode(second.id);
      expect(await database.fingerprintForEpisode(second.id), isNotNull);
    },
  );

  test(
    'an interrupted analysis is failed at startup and not retried',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final podcastId = (await database.saveFeed(
        _draft([_episodeDraft('a', 'Un')]),
      )).podcastId;
      final episode = (await database.watchEpisodes(podcastId: podcastId).first)
          .single
          .episode;
      await database.setDownloadPath(episode.id, '/tmp/a.pcm');
      await database.markFingerprintRunning(episode.id);
      final decoder = _CountingDecoder({
        '/tmp/a.pcm': Int16List(chromaprintSampleRate),
      });
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          pcmDecoderProvider.overrideWithValue(decoder),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(audioAnalysisProvider.notifier);
      await notifier.recoverInterrupted();
      expect(await database.fingerprintStatus(episode.id), 'failed');
      await notifier.enqueueMissing();
      expect(decoder.calls, 0);
    },
  );

  test('the open podcast is analyzed before the rest of the backlog', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'automaticAudioAnalysis': true});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final podcastA = (await database.saveFeed(
      _draft([
        _episodeDraft('a1', 'Un'),
        _episodeDraft('a2', 'Deux'),
      ], url: 'https://example.com/a.xml'),
    )).podcastId;
    final podcastB = (await database.saveFeed(
      _draft([_episodeDraft('b', 'Trois')], url: 'https://example.com/b.xml'),
    )).podcastId;
    final episodesA = await database.watchEpisodes(podcastId: podcastA).first;
    final episodeB = (await database.watchEpisodes(podcastId: podcastB).first)
        .single
        .episode;
    final first = episodesA
        .singleWhere((row) => row.episode.guid == 'a1')
        .episode;
    final second = episodesA
        .singleWhere((row) => row.episode.guid == 'a2')
        .episode;
    await database.setDownloadPath(first.id, '/tmp/a1.pcm');
    await database.setDownloadPath(second.id, '/tmp/a2.pcm');
    await database.setDownloadPath(episodeB.id, '/tmp/b.pcm');
    final pcm = Int16List(chromaprintSampleRate);
    final decoder = _CountingDecoder({
      '/tmp/a1.pcm': pcm,
      '/tmp/a2.pcm': pcm,
      '/tmp/b.pcm': pcm,
    }, delay: const Duration(milliseconds: 250));
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        pcmDecoderProvider.overrideWithValue(decoder),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(audioAnalysisProvider.notifier);
    final firstJob = notifier.enqueueEpisode(first.id);
    await _until(
      container,
      (progress) => progress.runningEpisodeId == first.id,
    );
    final secondJob = notifier.enqueueEpisode(second.id);
    await _until(
      container,
      (progress) => progress.pending.any((job) => job.episodeId == second.id),
    );
    final thirdJob = notifier.enqueueEpisode(episodeB.id);
    await _until(container, (progress) => progress.pending.length == 2);
    await notifier.enqueueMissing(podcastId: podcastB);
    await Future.wait([firstJob, secondJob, thirdJob]);
    expect(decoder.order, ['/tmp/a1.pcm', '/tmp/b.pcm', '/tmp/a2.pcm']);
  });

  test('an episode already fingerprinted is not decoded again', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final podcastId = (await database.saveFeed(
      _draft([_episodeDraft('a', 'Un')]),
    )).podcastId;
    final episode = (await database.watchEpisodes(podcastId: podcastId).first)
        .single
        .episode;
    await database.setDownloadPath(episode.id, '/tmp/a.pcm');
    await database.upsertEpisodeFingerprint(
      episodeId: episode.id,
      data: encodeFingerprint(_motif(32, 1)),
      hopMicros: chromaprintStoredHopMicros,
      speech: Uint8List(4),
    );
    await database.upsertEpisodeLogMel(
      episodeId: episode.id,
      data: Uint8List(logMelBandCount * 4 * 8),
    );
    final decoder = _CountingDecoder({
      '/tmp/a.pcm': Int16List(chromaprintSampleRate),
    });
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        pcmDecoderProvider.overrideWithValue(decoder),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(audioAnalysisProvider.notifier)
        .enqueueEpisode(episode.id);
    expect(decoder.calls, 0);
    expect(await database.fingerprintStatus(episode.id), isNot('running'));
  });

  test('automatic analysis stays idle when the setting is off', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'automaticAudioAnalysis': false});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final podcastId = (await database.saveFeed(
      _draft([_episodeDraft('a', 'Un')]),
    )).podcastId;
    final episode = (await database.watchEpisodes(podcastId: podcastId).first)
        .single
        .episode;
    await database.setDownloadPath(episode.id, '/tmp/a.pcm');
    final decoder = _CountingDecoder({
      '/tmp/a.pcm': Int16List(chromaprintSampleRate),
    });
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        pcmDecoderProvider.overrideWithValue(decoder),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(audioAnalysisProvider.notifier);
    expect(container.read(settingsProvider).automaticAudioAnalysis, isFalse);
    expect(
      () => container.read(audioAnalysisBootstrapProvider),
      returnsNormally,
    );
    await notifier.enqueueMissing();
    expect(decoder.calls, 0);
  });
}

Future<void> _until(
  ProviderContainer container,
  bool Function(AudioAnalysisProgress progress) ready,
) async {
  final started = DateTime.now();
  while (!ready(container.read(audioAnalysisProvider))) {
    if (DateTime.now().difference(started) > const Duration(seconds: 2)) {
      final progress = container.read(audioAnalysisProvider);
      fail(
        'file non remplie: ${progress.runningEpisodeId} ${progress.pending}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<({int a, int b})> _ids(AppDatabase database, int podcastId) async {
  final episodes = await database.watchEpisodes(podcastId: podcastId).first;
  int id(String guid) =>
      episodes.singleWhere((row) => row.episode.guid == guid).episode.id;
  return (a: id('a'), b: id('b'));
}

int _msAt(int index, {bool ceil = false}) {
  final ms = index * chromaprintStoredHopMicros / 1000;
  return ceil ? ms.ceil() : ms.floor();
}

Future<void> _ready(
  AppDatabase database,
  int episodeId,
  List<int> values,
) async {
  await database.setDownloadPath(episodeId, '/tmp/episode-$episodeId.mp3');
  await database.upsertEpisodeFingerprint(
    episodeId: episodeId,
    data: encodeFingerprint(values),
    hopMicros: chromaprintStoredHopMicros,
  );
}

List<int> _motif(int length, int salt) {
  return [for (var i = 0; i < length; i++) 0xC0000000 + salt * 1000 + i];
}

List<int> _placed(int length, int seed, int at, List<int> motif) {
  var state = seed;
  final values = List<int>.generate(length, (_) {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    return state;
  });
  for (var i = 0; i < motif.length; i++) {
    values[at + i] = motif[i];
  }
  return values;
}

Future<int> _addEpisode(
  AppDatabase database,
  int podcastId,
  String guid,
  String title,
) async {
  final podcast = await database.getPodcast(podcastId);
  await database.saveFeed(
    _draft([
      _episodeDraft('a', 'Un'),
      _episodeDraft('b', 'Deux'),
      _episodeDraft(guid, title),
    ], url: podcast!.feedUrl),
  );
  final episodes = await database.watchEpisodes(podcastId: podcastId).first;
  return episodes.singleWhere((row) => row.episode.guid == guid).episode.id;
}

FeedDraft _draft(
  List<EpisodeDraft> episodes, {
  String url = 'https://example.com/feed.xml',
}) {
  return FeedDraft(
    feedUrl: url,
    title: 'Essai',
    author: 'Auteur',
    description: 'Description',
    episodes: episodes,
  );
}

EpisodeDraft _episodeDraft(String guid, String title) {
  return EpisodeDraft(
    guid: guid,
    title: title,
    description: 'Notes',
    audioUrl: 'https://example.com/$guid.mp3',
    durationSeconds: 400,
  );
}

Int16List _bed(int seconds, double freq) {
  final count = seconds * chromaprintSampleRate;
  final out = Int16List(count);
  for (var i = 0; i < count; i++) {
    final t = i / chromaprintSampleRate;
    out[i] = (0.25 * math.sin(2 * math.pi * freq * t) * 32767).round();
  }
  return out;
}

Int16List _sweep(int count, double base) {
  final out = Int16List(count);
  for (var i = 0; i < count; i++) {
    final t = i / chromaprintSampleRate;
    final freq = base + 80 * math.sin(2 * math.pi * 1.7 * t);
    // Niveau qui bouge comme une voix : une enveloppe plate ne prouve rien.
    final gain =
        0.6 +
        0.4 * math.sin(2 * math.pi * 2.3 * t) * math.sin(0.74 * math.pi * t);
    final sample =
        0.55 * math.sin(2 * math.pi * freq * t) +
        0.25 * math.sin(2 * math.pi * freq * 1.5 * t);
    out[i] = (sample * gain * 32767).round().clamp(-32768, 32767);
  }
  return out;
}

Int16List _mix(Int16List bed, Int16List ad, int at) {
  final out = Int16List.fromList(bed);
  final end = math.min(out.length, at + ad.length);
  for (var i = at; i < end; i++) {
    out[i] = ad[i - at];
  }
  return out;
}

class _CountingDecoder extends PcmDecoder {
  _CountingDecoder(
    this.files, {
    this.delay = Duration.zero,
    this.hang = const {},
  });

  final Map<String, Int16List> files;
  final Duration delay;
  final Set<String> hang;
  var calls = 0;
  final byPath = <String, int>{};
  final order = <String>[];

  int callsFor(String path) => byPath[path] ?? 0;

  @override
  Future<DecodedPcm?> decode(
    String path, {
    int sampleRate = chromaprintSampleRate,
    Duration? budget,
    void Function(int samples, int expected, int sampleRate)? onProgress,
  }) async {
    calls++;
    order.add(path);
    byPath[path] = (byPath[path] ?? 0) + 1;
    if (hang.contains(path)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return null;
    }
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return _MapDecoder(files).decode(path, sampleRate: sampleRate);
  }
}

class _MapDecoder extends PcmDecoder {
  _MapDecoder(this.files);

  final Map<String, Int16List> files;

  @override
  Future<DecodedPcm?> decode(
    String path, {
    int sampleRate = chromaprintSampleRate,
    Duration? budget,
    void Function(int samples, int expected, int sampleRate)? onProgress,
  }) async {
    final samples = files[path];
    if (samples == null) return null;
    final file = File(
      '${Directory.systemTemp.path}/podavio-pcm-${path.hashCode}.pcm',
    );
    final bytes = Uint8List(samples.length * 2);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < samples.length; i++) {
      view.setInt16(i * 2, samples[i], Endian.little);
    }
    await file.writeAsBytes(bytes);
    return DecodedPcm(
      path: file.path,
      sampleRate: sampleRate,
      samples: samples.length,
      durationMs: samples.length * 1000 ~/ sampleRate,
    );
  }
}
