import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:olaf_ffi/olaf_ffi.dart';
import 'package:podavio/data/envelope.dart';
import 'package:podavio/data/olaf_sting.dart';

void main() {
  test('a sting that moves beats a card fixed at the start', () {
    final found = findOlafContentSting([
      _episode(1, stingAt: 500),
      _episode(2, stingAt: 1000),
      _episode(3, stingAt: 1500),
    ]);
    expect(found, hasLength(3));
    final byId = {for (final hit in found) hit.episodeId: hit};
    expect(byId[1]!.startMs, 500 * olafStepMs);
    expect(byId[2]!.startMs, 1000 * olafStepMs);
    expect(byId[3]!.startMs, 1500 * olafStepMs);
    for (final hit in found) {
      expect(hit.endMs - hit.startMs, inInclusiveRange(1000, 6500));
      expect(hit.startMs, greaterThan(1000));
    }
  });

  test('two weak copies are not enough', () {
    final found = findOlafContentSting([
      _episode(1, stingAt: 400, stingHashes: 10),
      _episode(2, stingAt: 900, stingHashes: 10),
    ]);
    expect(found, isEmpty);
  });

  test('a repeated slice of a longer ad is not a sting', () {
    final found = findOlafContentSting(
      [
        _episode(1, stingAt: 200),
        _episode(2, stingAt: 800),
        _episode(3, stingAt: 1400),
      ],
      covered: const [
        (episodeId: 1, startMs: 0, endMs: 20000),
        (episodeId: 2, startMs: 0, endMs: 20000),
        (episodeId: 3, startMs: 0, endMs: 20000),
      ],
    );
    expect(found, isEmpty);
  });

  test('unrelated landmarks do not match', () {
    final found = findOlafContentSting([
      OlafEpisodePrints(
        episodeId: 1,
        prints: [
          for (var i = 0; i < 200; i++) OlafLandmark(hash: i + 1, t1: i),
        ],
      ),
      OlafEpisodePrints(
        episodeId: 2,
        prints: [
          for (var i = 0; i < 200; i++) OlafLandmark(hash: i + 5000, t1: i),
        ],
      ),
    ]);
    expect(found, isEmpty);
  });

  test('edges use the shared silence snap', () {
    final envelope = Uint8List(400);
    for (var i = 0; i < envelope.length; i++) {
      envelope[i] = 40;
    }
    for (var i = 170; i < 185; i++) {
      envelope[i] = 0;
    }
    for (var i = 290; i < 310; i++) {
      envelope[i] = 0;
    }
    final found = findOlafContentSting([
      _episode(1, stingAt: 500, envelope: envelope, durationMs: 8000),
      _episode(2, stingAt: 1000),
      _episode(3, stingAt: 1500),
    ]);
    final hit = found.singleWhere((item) => item.episodeId == 1);
    expect(hit.startMs, 185 * envelopeHopMs);
    expect(hit.endMs, 5812);
  });

  test('a re-encoded short motif still matches', () async {
    expect(await ensureOlafLibrary(), isTrue);
    const rate = 11025;
    final clean = _pcm(rate, stingAt: 4);
    final shifted = _pcm(rate, stingAt: 9, gain: 0.5);
    final encoded = _lossyCopy(shifted);
    final other = _pcm(rate, stingAt: 13, gain: 0.8);
    final prints = [
      fingerprintPcm(clean, sampleRate: rate),
      fingerprintPcm(encoded, sampleRate: rate),
      fingerprintPcm(other, sampleRate: rate),
    ];
    expect(prints.every((item) => item != null && item.length > 20), isTrue);
    final found = findOlafContentSting([
      for (var i = 0; i < prints.length; i++)
        OlafEpisodePrints(episodeId: i + 1, prints: prints[i]!),
    ]);
    expect(found, hasLength(3));
    final starts = [for (final hit in found) hit.startMs]..sort();
    expect(starts[0], inInclusiveRange(3000, 5500));
    expect(starts[1], inInclusiveRange(8000, 10500));
    expect(starts[2], inInclusiveRange(12000, 14500));
  });
}

OlafEpisodePrints _episode(
  int id, {
  required int stingAt,
  int stingHashes = 180,
  Uint8List? envelope,
  int durationMs = 0,
}) {
  return OlafEpisodePrints(
    episodeId: id,
    envelope: envelope,
    durationMs: durationMs,
    prints: [
      for (var i = 0; i < 180; i++) OlafLandmark(hash: 10000 + i, t1: i),
      for (var i = 0; i < stingHashes; i++)
        OlafLandmark(hash: 20000 + i, t1: stingAt + i),
    ],
  );
}

/// Sixteen seconds: a fixed opening, then the same two-second motif.
Uint8List _pcm(
  int rate, {
  required int stingAt,
  double gain = 1,
  double noise = 0,
  int seed = 1,
}) {
  final random = math.Random(seed);
  final samples = rate * 16;
  final data = Int16List(samples);
  for (var i = 0; i < samples; i++) {
    final t = i / rate;
    var value = noise == 0 ? 0.0 : (random.nextDouble() * 2 - 1) * noise;
    if (t < 2) value += _notes(t, const [196, 247, 294, 247]);
    final local = t - stingAt;
    if (local >= 0 && local < 2) {
      value += _notes(local, const [523, 659, 784, 880, 784, 659, 523, 392]);
    }
    final scaled = (value * gain * 16000).round().clamp(-32767, 32767);
    data[i] = scaled;
  }
  return data.buffer.asUint8List();
}

/// Gain is already applied. A one-pole lowpass and a coarse quantizer
/// change the samples the way a low-bitrate encode does, without ffmpeg.
Uint8List _lossyCopy(Uint8List pcm) {
  final samples = Int16List.view(Uint8List.fromList(pcm).buffer);
  final out = Int16List(samples.length);
  var state = 0.0;
  for (var i = 0; i < samples.length; i++) {
    state += 0.8 * (samples[i] - state);
    final quantized = (state / 32).round() * 32;
    out[i] = quantized.clamp(-32767, 32767);
  }
  return out.buffer.asUint8List();
}

double _notes(double t, List<int> freqs) {
  final note = (t * 4).floor().clamp(0, freqs.length - 1);
  final local = t % 0.25;
  final edge = local < 0.02
      ? local / 0.02
      : (local > 0.2 ? (0.25 - local) / 0.05 : 1.0);
  final f = freqs[note].toDouble();
  return edge *
      (math.sin(2 * math.pi * f * t) + 0.35 * math.sin(4 * math.pi * f * t));
}
