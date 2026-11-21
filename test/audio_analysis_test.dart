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
import 'package:podavio/data/skip_segments.dart';

void main() {
  test(
    'analysis is idempotent and keeps an ignored or confirmed template',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final motif = _motif(100, 4);
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
      await _ready(database, first, _placed(1500, 1, 80, motif));
      await _ready(database, second, _placed(1500, 2, 600, motif));

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
      await _ready(database, thirdId, _placed(1500, 3, 900, motif));
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
    final motif = _motif(100, 6);
    final podcastId = (await database.saveFeed(
      _draft([_episodeDraft('a', 'Un'), _episodeDraft('b', 'Deux')]),
    )).podcastId;
    final episodes = await database.watchEpisodes(podcastId: podcastId).first;
    await _ready(
      database,
      episodes.singleWhere((row) => row.episode.guid == 'a').episode.id,
      _placed(1500, 1, 90, motif),
    );
    await _ready(
      database,
      episodes.singleWhere((row) => row.episode.guid == 'b').episode.id,
      _placed(1500, 2, 640, motif),
    );
    await syncPodcastAnalysis(database, podcastId);
    final template = (await database.listSegmentTemplates(podcastId)).single;
    await database.setTemplateReview(template.id, confirmed: true);

    final thirdId = await _addEpisode(database, podcastId, 'c', 'Trois');
    await _ready(database, thirdId, _placed(1500, 3, 1000, motif));
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
      final motif = _motif(100, 8);
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
      await _ready(database, first, _placed(1500, 1, 80, motif));
      await _ready(database, second, _placed(1500, 2, 500, motif));
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
      expect(await database.listSegmentTemplates(podcastId), isEmpty);
      expect(await database.fingerprintSegmentsForPodcast(podcastId), isEmpty);
    },
  );

  test(
    'the queue fingerprints two downloads and finds the shared passage',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final ad = _sweep(chromaprintSampleRate * 12, 220);
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

class _MapDecoder extends PcmDecoder {
  _MapDecoder(this.files);

  final Map<String, Int16List> files;

  @override
  Future<DecodedPcm?> decode(
    String path, {
    int sampleRate = chromaprintSampleRate,
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
