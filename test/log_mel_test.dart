import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/log_mel.dart';
import 'package:podavio/data/log_mel_match.dart';
import 'package:podavio/data/segment_match.dart';

void main() {
  test('an identical chirp scores above 0.96 and noise stays under 0.50', () {
    final chirp = _chirp(milliseconds: 2000, f0: 400, f1: 1800);
    final clip = computeLogMel(chirp);
    final same = searchLogMel(clip, clip, threshold: 0.5);
    expect(same, isNotEmpty);
    expect(same.first.score, greaterThanOrEqualTo(0.96));
    expect(same.first.startMs, 0);

    final other = computeLogMel(_chirp(milliseconds: 2000, f0: 900, f1: 300));
    final cross = searchLogMel(clip, other, threshold: 0.2);
    final best = cross.isEmpty ? 0.0 : cross.first.score;
    expect(best, lessThan(0.50));
    expect(logMelScoreMatches(same.first.score), isTrue);
    expect(logMelScoreMatches(best), isFalse);
  });

  test('a short chirp is found at several offsets', () {
    final chirp = _chirp(milliseconds: 1500, f0: 500, f1: 2200);
    final needle = computeLogMel(chirp);
    for (final at in [0, 4000, 12000, 27000]) {
      final bed = _silence(at + 3000);
      for (var i = 0; i < chirp.length; i++) {
        bed[at * logMelSampleRate ~/ 1000 + i] = chirp[i];
      }
      final found = searchLogMel(needle, computeLogMel(bed));
      expect(found, isNotEmpty, reason: 'offset $at');
      expect(found.first.score, greaterThanOrEqualTo(logMelMatchThreshold));
      expect((found.first.startMs - at).abs(), lessThanOrEqualTo(40));
    }
  });

  test('a short jingle at the start is kept across three episodes', () {
    final chirp = _chirp(milliseconds: 1500, f0: 600, f1: 2000);
    final episodes = [
      for (var id = 1; id <= 3; id++)
        EpisodeMel(
          episodeId: id,
          podcastId: 1,
          clip: computeLogMel(_bedWith(chirp, atMs: 0, totalMs: 8000)),
          durationMs: 8000,
        ),
    ];
    final found = discoverShortJingles(episodes);
    expect(found, hasLength(1));
    expect(found.single.hits, hasLength(3));
    expect(found.single.hits.first.durationMs, lessThan(jingleMinDurationMs));
    for (final hit in found.single.hits) {
      expect(hit.startMs, lessThanOrEqualTo(40));
    }
  });

  test('the same chirp after each pre-roll stays comparable', () {
    final chirp = _chirp(milliseconds: 1200, f0: 700, f1: 1600);
    final episodes = [
      for (final (id, at) in [(1, 2000), (2, 8000), (3, 14000)])
        EpisodeMel(
          episodeId: id,
          podcastId: 1,
          clip: computeLogMel(_bedWith(chirp, atMs: at, totalMs: 20000)),
          durationMs: 20000,
          preRollEndMs: at,
        ),
    ];
    final found = discoverShortJingles(episodes);
    expect(found, isNotEmpty);
    expect(found.first.hits.map((hit) => hit.episodeId).toSet(), {1, 2, 3});
  });

  test('log-mel snaps a rough boundary onto the chirp', () {
    final chirp = _chirp(milliseconds: 4000, f0: 300, f1: 1500);
    final episode = computeLogMel(_bedWith(chirp, atMs: 5000, totalMs: 12000));
    final refined = refineLogMelBoundary(
      episode: episode,
      roughStartMs: 4200,
      roughEndMs: 9800,
    );
    expect(refined, isNotNull);
    expect(refined!.score, greaterThanOrEqualTo(logMelMatchThreshold));
    expect((refined.startMs - 5000).abs(), lessThanOrEqualTo(80));
  });

  test('a sting in the opening marks the pre-roll up to its end', () {
    final sting = _chirp(milliseconds: 1300, f0: 1400, f1: 2200);
    final episode = EpisodeMel(
      episodeId: 4,
      podcastId: 2,
      clip: computeLogMel(_bedWith(sting, atMs: 5300, totalMs: 20000)),
      durationMs: 20000,
    );
    final spans = stingDelimitedSpans(
      episode: episode,
      stings: [NamedLogMel(name: 'Acast', clip: computeLogMel(sting))],
    );
    expect(spans, hasLength(1));
    expect(spans.single.startMs, 0);
    expect((spans.single.endMs - 6600).abs(), lessThanOrEqualTo(80));
    expect(spans.single.label, 'Acast');
  });

  test('the same sting at the end of ads from two podcasts is learned', () {
    final sting = _chirp(milliseconds: 1300, f0: 1000, f1: 2500);
    final other = _chirp(milliseconds: 1300, f0: 200, f1: 400);
    final learned = learnNetworkStings([
      EpisodeMelBoundary(
        podcastId: 1,
        episodeId: 1,
        clip: computeLogMel(sting),
      ),
      EpisodeMelBoundary(
        podcastId: 2,
        episodeId: 2,
        clip: computeLogMel(sting),
      ),
      EpisodeMelBoundary(
        podcastId: 3,
        episodeId: 3,
        clip: computeLogMel(other),
      ),
    ]);
    expect(learned, hasLength(1));
    expect(learned.single.podcasts, 2);
  });
}

Float64List _bedWith(
  Float64List chirp, {
  required int atMs,
  required int totalMs,
}) {
  final bed = _silence(totalMs);
  final at = atMs * logMelSampleRate ~/ 1000;
  for (var i = 0; i < chirp.length && at + i < bed.length; i++) {
    bed[at + i] = chirp[i];
  }
  return bed;
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
    final f = f0 + (f1 - f0) * i / count;
    out[i] = 0.6 * 32767 * math.sin(2 * math.pi * f * t);
  }
  return out;
}
