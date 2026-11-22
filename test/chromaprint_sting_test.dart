import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/chromaprint_sting.dart';

void main() {
  test('a 3 s sting at a different time in each opening is hinted', () {
    final found = findChromaprintStingHint([
      _episode(1, stingAtMs: 20000, seed: 3),
      _episode(2, stingAtMs: 47000, seed: 5),
      _episode(3, stingAtMs: 33000, seed: 8),
    ]);
    final byId = {for (final hit in found) hit.episodeId: hit};
    expect(byId.keys.toSet(), {1, 2, 3});
    for (final entry in {1: 20000, 2: 47000, 3: 33000}.entries) {
      final hit = byId[entry.key]!;
      expect(
        hit.startMs,
        inInclusiveRange(entry.value - 2500, entry.value + 3000),
      );
      expect(hit.endMs - hit.startMs, lessThanOrEqualTo(chromaprintStingMaxMs));
    }
  });

  test('openings without a shared sting give no hint', () {
    final found = findChromaprintStingHint([
      _episode(1, seed: 3),
      _episode(2, seed: 5),
      _episode(3, seed: 8),
    ]);
    expect(found, isEmpty);
  });

  test('a sting inside an ad already found is not hinted', () {
    final found = findChromaprintStingHint(
      [
        _episode(1, stingAtMs: 20000, seed: 3),
        _episode(2, stingAtMs: 47000, seed: 5),
      ],
      covered: const [
        (episodeId: 1, startMs: 10000, endMs: 30000),
        (episodeId: 2, startMs: 40000, endMs: 60000),
      ],
    );
    expect(found, isEmpty);
  });
}

ChromaprintStingEpisode _episode(int id, {int? stingAtMs, required int seed}) {
  const rate = chromaprintSampleRate;
  final samples = Int16List(rate * 70);
  var state = seed;
  double next() {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    return state / 0x3fffffff - 1;
  }

  final period = rate ~/ 4;
  var pitch = 120.0;
  for (var i = 0; i < samples.length; i++) {
    if (i % period == 0) pitch = 100 + (next() + 1) * 50;
    final phase = i % period;
    final t = i / rate;
    final value = phase < period * 0.6
        ? 0.5 * math.sin(2 * math.pi * pitch * t) +
              0.2 * math.sin(4 * math.pi * pitch * t)
        : 0.05 * next();
    samples[i] = (value * 9000).round();
  }
  if (stingAtMs != null) {
    const chords = [
      [261.6, 329.6, 392.0],
      [349.2, 440.0, 523.3],
      [392.0, 493.9, 587.3],
    ];
    final start = stingAtMs * rate ~/ 1000;
    for (var i = 0; i < rate * 3; i++) {
      final chord = chords[i ~/ rate];
      final t = i / rate;
      var value = 0.0;
      for (final hz in chord) {
        value += math.sin(2 * math.pi * hz * t) / 3;
      }
      samples[start + i] = (value * 14000).round();
    }
  }
  return ChromaprintStingEpisode(
    episodeId: id,
    values: chromaprintFingerprint(samples),
    hopMicros: chromaprintStoredHopMicros,
  );
}
