import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/envelope.dart';
import 'package:podavio/data/log_mel.dart';
import 'package:podavio/data/log_mel_match.dart';
import 'package:podavio/data/segment_finder.dart';
import 'package:podavio/data/segment_match.dart';

void main() {
  test('envelope snap lands within 40 ms of the shared ad', () {
    const trueStart = 5000;
    const trueEnd = 17000;
    const lead = 800;
    const otherAt = 20000;
    final shift = envelopeEdgeShift(
      anchor: _envelope(outside: 12, adStart: trueStart, adEnd: trueEnd),
      other: _envelope(
        outside: 220,
        adStart: otherAt,
        adEnd: otherAt + (trueEnd - trueStart),
      ),
      anchorStartMs: trueStart - lead,
      anchorEndMs: trueEnd + lead,
      otherStartMs: otherAt - lead,
      otherEndMs: otherAt + (trueEnd - trueStart) + lead,
    );
    expect(shift, isNotNull);
    expect(
      ((trueStart - lead) + shift!.startMs - trueStart).abs(),
      lessThanOrEqualTo(40),
    );
    expect(
      ((trueEnd + lead) + shift.endMs - trueEnd).abs(),
      lessThanOrEqualTo(40),
    );
  });

  test('a hash run that starts early is pulled back by the envelope', () {
    const at = 80;
    final motif = _motif(100, 9);
    final bleed = _motif(8, 3);
    final found = discoverPatterns([
      _withBleed(id: 1, seed: 1, at: at, motif: motif, bleed: bleed),
      _withBleed(id: 2, seed: 2, at: at + 400, motif: motif, bleed: bleed),
    ]);
    expect(found, hasLength(1));
    final starts = found.single.occurrences.map((hit) => hit.startMs).toList()
      ..sort();
    expect((starts[0] - _ms(at)).abs(), lessThanOrEqualTo(40));
    expect((starts[1] - _ms(at + 400)).abs(), lessThanOrEqualTo(40));
    final ends = found.single.occurrences.map((hit) => hit.endMs).toList()
      ..sort();
    expect((ends[0] - _ms(at + motif.length)).abs(), lessThanOrEqualTo(80));
    expect(
      (ends[1] - _ms(at + 400 + motif.length)).abs(),
      lessThanOrEqualTo(80),
    );
  });

  test('log-mel edges snap a wide window onto the chirp', () {
    final chirp = _chirp(milliseconds: 4000, f0: 320, f1: 1600);
    const atA = 5000;
    const atB = 12000;
    final left = computeLogMel(_bed(chirp, atMs: atA, tone: 180));
    final right = computeLogMel(_bed(chirp, atMs: atB, tone: 420));
    final refined = refinePairedLogMelEdges(
      left: left,
      leftStartMs: atA - 600,
      leftEndMs: atA + 4000 + 600,
      right: right,
      rightStartMs: atB - 600,
      rightEndMs: atB + 4000 + 600,
    );
    expect(refined, isNotNull);
    expect((refined!.startMs - atA).abs(), lessThanOrEqualTo(40));
    expect((refined.endMs - (atA + 4000)).abs(), lessThanOrEqualTo(80));
    expect(refined.score, greaterThanOrEqualTo(logMelMatchThreshold));
  });

  test('an ad end walks past a short dip to the next silence', () {
    final envelope = Uint8List(40000 ~/ envelopeHopMs);
    for (var i = 0; i < envelope.length; i++) {
      envelope[i] = 80;
    }
    void quiet(int from, int to) {
      for (var t = from; t < to; t += envelopeHopMs) {
        envelope[t ~/ envelopeHopMs] = 2;
      }
    }

    quiet(27000, 27160);
    quiet(29300, 30000);
    expect(extendEndToSilence(envelope, 27000), 29300);
    expect(extendEndToSilence(envelope, 29400), 29400);

    final loud = Uint8List(20000 ~/ envelopeHopMs)
      ..fillRange(0, 20000 ~/ envelopeHopMs, 80);
    expect(extendEndToSilence(loud, 10000), 10000);
  });

  test('the same clip just after three ads becomes a sting', () {
    final found = findPostAdStings(
      episodes: [
        for (final row in <(int, int, int)>[
          (1, 30000, 1),
          (2, 42000, 9),
          (3, 18000, 4),
        ])
          EpisodeMel(
            episodeId: row.$1,
            podcastId: 1,
            clip: _bedMel(stingAt: row.$2, salt: row.$3),
            durationMs: 60000,
          ),
      ],
      adEnds: [
        (episodeId: 1, endMs: 30000),
        (episodeId: 2, endMs: 42000),
        (episodeId: 3, endMs: 18000),
      ],
    );
    expect(found.map((hit) => hit.episodeId).toSet(), {1, 2, 3});
    expect(
      found.every(
        (hit) =>
            hit.startMs ==
            (hit.episodeId == 1
                ? 30000
                : hit.episodeId == 2
                ? 42000
                : 18000),
      ),
      isTrue,
    );
    expect(found.every((hit) => hit.endMs - hit.startMs >= 2000), isTrue);

    final unlike = findPostAdStings(
      episodes: [
        for (final row in <(int, int, int)>[
          (1, 30000, 1),
          (2, 42000, 9),
          (3, 18000, 4),
        ])
          EpisodeMel(
            episodeId: row.$1,
            podcastId: 1,
            clip: _bedMel(stingAt: row.$2, salt: row.$3, stingSalt: row.$1 + 2),
            durationMs: 60000,
          ),
      ],
      adEnds: [
        (episodeId: 1, endMs: 30000),
        (episodeId: 2, endMs: 42000),
        (episodeId: 3, endMs: 18000),
      ],
    );
    expect(unlike, isEmpty);
  });

  test('a flat spectrum after two ads is not a sting', () {
    LogMelClip flat() {
      return LogMelClip([
        for (var i = 0; i < 6000; i++)
          Float64List(logMelBandCount)..fillRange(0, logMelBandCount, 0.16),
      ]);
    }

    final found = findPostAdStings(
      episodes: [
        EpisodeMel(episodeId: 1, podcastId: 1, clip: flat(), durationMs: 60000),
        EpisodeMel(episodeId: 2, podcastId: 1, clip: flat(), durationMs: 60000),
      ],
      adEnds: [(episodeId: 1, endMs: 30000), (episodeId: 2, endMs: 42000)],
    );
    expect(found, isEmpty);
  });
}

Uint8List _envelope({
  required int outside,
  required int adStart,
  required int adEnd,
  int totalMs = 250000,
}) {
  final count = totalMs ~/ envelopeHopMs;
  final out = Uint8List(count);
  for (var i = 0; i < count; i++) {
    final ms = i * envelopeHopMs;
    if (ms < adStart || ms >= adEnd) {
      out[i] = outside;
    } else {
      out[i] = 40 + ((ms - adStart) ~/ envelopeHopMs) % 50;
    }
  }
  return out;
}

int _ms(int index) => index * chromaprintStoredHopMicros ~/ 1000;

List<int> _motif(int length, int salt) {
  return [for (var i = 0; i < length; i++) 0xC0000000 + salt * 1000 + i];
}

FingerprintEpisode _withBleed({
  required int id,
  required int seed,
  required int at,
  required List<int> motif,
  required List<int> bleed,
}) {
  var state = seed;
  final values = List<int>.generate(1600, (_) {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    return state == 0 ? 1 : state;
  });
  for (var i = 0; i < bleed.length; i++) {
    values[at - bleed.length + i] = bleed[i];
  }
  for (var i = 0; i < motif.length; i++) {
    values[at + i] = motif[i];
  }
  final start = _ms(at);
  final end = _ms(at + motif.length);
  return FingerprintEpisode(
    episodeId: id,
    values: values,
    hopMicros: chromaprintStoredHopMicros,
    durationMs: 400000,
    envelope: _envelope(outside: 20 + id * 80, adStart: start, adEnd: end),
  );
}

Float64List _bed(Float64List chirp, {required int atMs, required double tone}) {
  const totalMs = 20000;
  final count = totalMs * logMelSampleRate ~/ 1000;
  final out = Float64List(count);
  for (var i = 0; i < count; i++) {
    final t = i / logMelSampleRate;
    out[i] = 0.25 * 32767 * math.sin(2 * math.pi * tone * t);
  }
  final at = atMs * logMelSampleRate ~/ 1000;
  for (var i = 0; i < chirp.length && at + i < out.length; i++) {
    out[at + i] = chirp[i];
  }
  return out;
}

LogMelClip _bedMel({
  required int stingAt,
  required int salt,
  int stingSalt = 0,
}) {
  final frames = <Float64List>[];
  for (var ms = 0; ms < 60000; ms += logMelHopMs) {
    final row = Float64List(logMelBandCount);
    final inSting = ms >= stingAt && ms < stingAt + postAdStingMs;
    final step = inSting ? (ms - stingAt) ~/ logMelHopMs : ms ~/ logMelHopMs;
    // stingSalt 0 is the shared sting. Another salt is a different melody,
    // not a rotation of the same one-hot sequence.
    final band = inSting
        ? (stingSalt == 0 ? step : step * stingSalt + 1) % logMelBandCount
        : (step * 3 + salt + 7) % logMelBandCount;
    row[band] = 1;
    frames.add(row);
  }
  return LogMelClip(frames);
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
    out[i] = 0.7 * 32767 * math.sin(2 * math.pi * f * t);
  }
  return out;
}
