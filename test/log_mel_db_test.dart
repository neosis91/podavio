import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/audio_analysis.dart';
import 'package:podavio/data/log_mel.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/segment_match.dart';
import 'package:podavio/data/skip_segments.dart';

void main() {
  test('short jingles and sting pre-rolls are idempotent', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final podcastId = (await database.saveFeed(
      _draft([_episode('a'), _episode('b'), _episode('c')]),
    )).podcastId;
    final episodes = await database.watchEpisodes(podcastId: podcastId).first;
    final chirp = _chirp(milliseconds: 1500, f0: 500, f1: 1800);
    for (final entry in episodes) {
      await database.setDownloadPath(
        entry.episode.id,
        '/tmp/${entry.episode.guid}.mp3',
      );
      final bed = _silence(8000);
      bed.setRange(0, chirp.length, chirp);
      await database.upsertEpisodeLogMel(
        episodeId: entry.episode.id,
        data: encodeLogMel(computeLogMel(bed).frames.cast<List<double>>()),
      );
    }

    await applyLogMelFindings(database, podcastId);
    await applyLogMelFindings(database, podcastId);

    final templates = await database.listSegmentTemplates(podcastId);
    expect(
      templates.where((template) => template.kind == SkipSegmentKind.jingle),
      hasLength(1),
    );
    expect(templates.single.logMel, isNotNull);
    final ids = <int>[];
    for (final entry in episodes) {
      final segments = await database.listSkipSegments(entry.episode.id);
      expect(segments, hasLength(1));
      expect(segments.single.kind, SkipSegmentKind.jingle);
      expect(segments.single.startMs, lessThanOrEqualTo(40));
      ids.add(segments.single.id);
    }
    await applyLogMelFindings(database, podcastId);
    for (final entry in episodes) {
      final segments = await database.listSkipSegments(entry.episode.id);
      expect(segments.single.id, ids[episodes.indexOf(entry)]);
    }
  });

  test('a learned sting marks the pre-roll', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final podcastId = (await database.saveFeed(_draft([_episode('a')])))
        .podcastId;
    final episode = (await database.watchEpisodes(podcastId: podcastId).first)
        .single
        .episode;
    await database.setDownloadPath(episode.id, '/tmp/a.mp3');
    final sting = _chirp(milliseconds: 1300, f0: 1200, f1: 2400);
    final bed = _silence(20000);
    final at = 5300 * logMelSampleRate ~/ 1000;
    bed.setRange(at, at + sting.length, sting);
    await database.upsertEpisodeLogMel(
      episodeId: episode.id,
      data: encodeLogMel(computeLogMel(bed).frames.cast<List<double>>()),
    );
    await database.insertLearnedNetworkSting(
      logMel: encodeLogMel(computeLogMel(sting).frames.cast<List<double>>()),
      durationMs: 1300,
      name: 'Acast',
      podcastCount: 2,
      episodeCount: 4,
    );

    await applyLogMelFindings(database, podcastId);
    await applyLogMelFindings(database, podcastId);
    final segments = await database.listSkipSegments(episode.id);
    expect(segments, hasLength(1));
    expect(segments.single.source, SkipSegmentSource.network);
    expect(segments.single.kind, SkipSegmentKind.ad);
    expect(segments.single.startMs, 0);
    expect((segments.single.endMs - 6600).abs(), lessThanOrEqualTo(80));
    final id = segments.single.id;
    await applyLogMelFindings(database, podcastId);
    final again = await database.listSkipSegments(episode.id);
    expect(again.single.id, id);
  });

  test('deleting a download drops the stored log-mel', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final podcastId = (await database.saveFeed(_draft([_episode('a')])))
        .podcastId;
    final episode = (await database.watchEpisodes(podcastId: podcastId).first)
        .single
        .episode;
    await database.setDownloadPath(episode.id, '/tmp/a.mp3');
    await database.upsertEpisodeLogMel(
      episodeId: episode.id,
      data: encodeLogMel([List<double>.filled(logMelBandCount, 0)]),
    );
    await database.setDownloadPath(episode.id, null);
    expect(await database.logMelForEpisode(episode.id), isNull);
  });
}

FeedDraft _draft(List<EpisodeDraft> episodes) {
  return FeedDraft(
    feedUrl: 'https://example.com/mel.xml',
    title: 'Essai',
    author: 'Auteur',
    description: 'Description',
    episodes: episodes,
  );
}

EpisodeDraft _episode(String guid) {
  return EpisodeDraft(
    guid: guid,
    title: guid,
    description: 'Notes',
    audioUrl: 'https://example.com/$guid.mp3',
    durationSeconds: 400,
  );
}

Float64List _silence(int milliseconds) {
  return Float64List(milliseconds * logMelSampleRate ~/ 1000);
}

Float64List _chirp({
  required int milliseconds,
  required double f0,
  required double f1,
}) {
  final count = milliseconds * logMelSampleRate ~/ 1000;
  final out = Float64List(count);
  for (var i = 0; i < count; i++) {
    final t = i / logMelSampleRate;
    final freq = f0 + (f1 - f0) * i / count;
    out[i] = 0.6 * 32767 * math.sin(2 * math.pi * freq * t);
  }
  return out;
}
