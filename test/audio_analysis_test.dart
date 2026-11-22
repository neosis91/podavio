import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/audio_analysis.dart';
import 'package:olaf_ffi/olaf_ffi.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/olaf_ads.dart';
import 'package:podavio/data/pcm_decoder.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/data/segment_match.dart';
import 'package:podavio/data/skip_segments.dart';
import 'package:podavio/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  test(
    'analysis is idempotent and keeps an ignored or confirmed template',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final podcastId = (await database.saveFeed(
        _draft([_episodeDraft('a', 'Un'), _episodeDraft('b', 'Deux')]),
      )).podcastId;
      final episodes = await database.watchEpisodes(podcastId: podcastId).first;
      final first = episodes
          .singleWhere((row) => row.episode.guid == 'a')
          .episode
          .id;
      final second = episodes
          .singleWhere((row) => row.episode.guid == 'b')
          .episode
          .id;
      await _ready(database, first, 10000);
      await _ready(database, second, 80000);

      await syncPodcastAnalysis(database, podcastId);
      await syncPodcastAnalysis(database, podcastId);

      final templates = await database.listSegmentTemplates(podcastId);
      expect(templates, hasLength(1));
      expect(templates.single.kind, SkipSegmentKind.ad);
      final before = [
        ...await database.listSkipSegments(first),
        ...await database.listSkipSegments(second),
      ];
      expect(before, hasLength(2));
      expect(before.every((row) => row.confirmed == null), isTrue);
      final ids = before.map((row) => row.id).toList();

      await database.setTemplateReview(templates.single.id, confirmed: false);
      await database.setTemplateKind(
        templates.single.id,
        SkipSegmentKind.sponsor,
      );

      final thirdId = await _addEpisode(database, podcastId, 'c', 'Trois');
      await _ready(database, thirdId, 140000);
      await syncPodcastAnalysis(database, podcastId);
      await syncPodcastAnalysis(database, podcastId);

      expect(await database.listSegmentTemplates(podcastId), hasLength(1));
      final again = await database.listSegmentTemplates(podcastId);
      expect(again.single.kind, SkipSegmentKind.sponsor);
      expect(again.single.occurrences, 3);
      final kept = [
        ...await database.listSkipSegments(first),
        ...await database.listSkipSegments(second),
      ];
      expect(kept.map((row) => row.id).toList(), ids);
      expect(kept.every((row) => row.confirmed == false), isTrue);
      expect(kept.every((row) => row.kind == SkipSegmentKind.sponsor), isTrue);
      final added = await database.listSkipSegments(thirdId);
      expect(added, hasLength(1));
      expect(added.single.confirmed, isFalse);
      expect(added.single.kind, SkipSegmentKind.sponsor);
      expect(added.single.source, SkipSegmentSource.fingerprint);
    },
  );

  test('a confirmed template is inherited by the next episode', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final podcastId = (await database.saveFeed(
      _draft([_episodeDraft('a', 'Un'), _episodeDraft('b', 'Deux')]),
    )).podcastId;
    final episodes = await database.watchEpisodes(podcastId: podcastId).first;
    await _ready(
      database,
      episodes.singleWhere((row) => row.episode.guid == 'a').episode.id,
      12000,
    );
    await _ready(
      database,
      episodes.singleWhere((row) => row.episode.guid == 'b').episode.id,
      90000,
    );
    await syncPodcastAnalysis(database, podcastId);
    final template = (await database.listSegmentTemplates(podcastId)).single;
    await database.setTemplateReview(template.id, confirmed: true);

    final thirdId = await _addEpisode(database, podcastId, 'c', 'Trois');
    await _ready(database, thirdId, 150000);
    await syncPodcastAnalysis(database, podcastId);

    final added = await database.listSkipSegments(thirdId);
    expect(added, hasLength(1));
    expect(added.single.confirmed, isTrue);
    expect(added.single.kind, SkipSegmentKind.ad);
    expect(added.single.templateId, template.id);
  });

  test(
    'deleting a download drops its fingerprint and fingerprint segments',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final podcastId = (await database.saveFeed(
        _draft([_episodeDraft('a', 'Un'), _episodeDraft('b', 'Deux')]),
      )).podcastId;
      final episodes = await database.watchEpisodes(podcastId: podcastId).first;
      final first = episodes
          .singleWhere((row) => row.episode.guid == 'a')
          .episode
          .id;
      final second = episodes
          .singleWhere((row) => row.episode.guid == 'b')
          .episode
          .id;
      await _ready(database, first, 20000);
      await _ready(database, second, 70000);
      await syncPodcastAnalysis(database, podcastId);
      await database.insertSkipSegment(
        episodeId: first,
        startMs: 1000,
        endMs: 2000,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.chapter,
      );

      await database.setDownloadPath(first, null);

      expect(await database.fingerprintForEpisode(first), isNull);
      final left = await database.listSkipSegments(first);
      expect(left, hasLength(1));
      expect(left.single.source, SkipSegmentSource.chapter);
      expect(await database.fingerprintForEpisode(second), isNotNull);
      final templates = await database.listSegmentTemplates(podcastId);
      expect(templates, hasLength(1));
      expect(templates.single.occurrences, 1);

      await database.setDownloadPath(second, null);
      final kept = await database.listSegmentTemplates(podcastId);
      expect(kept, hasLength(1));
      expect(kept.single.occurrences, 0);
      expect(await database.fingerprintSegmentsForPodcast(podcastId), isEmpty);
    },
  );

  test(
    'the queue fingerprints two downloads and finds the shared passage',
    () async {
      expect(await ensureOlafLibrary(), isTrue);
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final ad = _sweep(chromaprintSampleRate * 20, 220);
      final podcastId = (await database.saveFeed(
        _draft([_episodeDraft('a', 'Un'), _episodeDraft('b', 'Deux')]),
      )).podcastId;
      final episodes = await database.watchEpisodes(podcastId: podcastId).first;
      final first = episodes[0].episode;
      final second = episodes[1].episode;
      // 441 source samples is five Olaf hops after 11025 → 16000,
      // so both copies land on the same FFT grid.
      final atA = 441 * 40;
      final atB = 441 * 200;
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
      await container
          .read(audioAnalysisProvider.notifier)
          .analyzeDownloaded(podcastId);

      expect(await database.fingerprintForEpisode(first.id), isNotNull);
      expect(await database.fingerprintForEpisode(second.id), isNotNull);
      final segments = [
        ...await database.listSkipSegments(first.id),
        ...await database.listSkipSegments(second.id),
      ];
      expect(segments, isNotEmpty);
      expect(
        segments.every((row) => row.source == SkipSegmentSource.fingerprint),
        isTrue,
      );
      expect(segments.any((row) => row.endMs - row.startMs >= 8000), isTrue);
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
      data: encodeOlafAdPrints(const []),
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

Future<void> _ready(AppDatabase database, int episodeId, int startMs) async {
  await database.setDownloadPath(episodeId, '/tmp/episode-$episodeId.mp3');
  await database.upsertEpisodeFingerprint(
    episodeId: episodeId,
    data: _adAt(startMs),
    hopMicros: chromaprintStoredHopMicros,
  );
}

/// 80 landmarks over about 12.6 s, the same hashes in every episode.
Uint8List _adAt(int startMs) {
  final start = startMs ~/ olafStepMs;
  return encodeOlafAdPrints([
    for (var i = 0; i < 80; i++)
      OlafLandmark(hash: 900000 + i, t1: start + i * 20),
  ]);
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
    final sample =
        0.55 * math.sin(2 * math.pi * freq * t) +
        0.25 * math.sin(2 * math.pi * freq * 1.5 * t);
    out[i] = (sample * 32767).round().clamp(-32768, 32767);
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
