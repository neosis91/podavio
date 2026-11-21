import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/segment_finder.dart';
import 'package:podavio/data/segment_match.dart';
import 'package:podavio/data/skip_segments.dart';
import 'package:podavio/data/speech_music.dart';

/// Signaux synthétiques passés par Chromaprint et le discriminateur.
///
/// Un refrain tonal répété dans une épisode disparaît. La même parole
/// insérée à des offsets différents, d’une épisode à l’autre, reste une
/// pub. Un jingle musical stable en ouverture reste une intro.
void main() {
  test('tonal refrain loops are rejected and spoken ads are kept', () {
    final refrain = _melody(14);
    final episode = _episode(
      id: 1,
      seconds: 90,
      clip: refrain,
      atSeconds: const [4, 28, 52],
    );
    // La même mélodie est bien retrouvée : un score de parole forcé la
    // garderait. Le score mesuré, lui, la rejette.
    expect(discoverPatterns([_forcedSpeech(episode)]), isNotEmpty);
    expect(discoverPatterns([episode]), isEmpty);

    final bed = _episode(
      id: 2,
      seconds: 80,
      clip: _melody(18),
      atSeconds: const [10, 49],
    );
    expect(discoverPatterns([_forcedSpeech(bed)]), isNotEmpty);
    expect(discoverPatterns([bed]), isEmpty);

    // 20 s : Chromaprint met ~2,5 s à oublier le lit, et une pub doit
    // durer au moins 10 s. Le clip est identique, donc son intérieur matche.
    final ad = _voicedSpeech(20, seed: 4);
    final dynamicAd = discoverPatterns([
      _episode(id: 1, seconds: 150, clip: ad, atSeconds: const [5]),
      _episode(id: 2, seconds: 150, clip: ad, atSeconds: const [40]),
      _episode(id: 3, seconds: 150, clip: ad, atSeconds: const [75]),
    ]);
    expect(dynamicAd, hasLength(1));
    expect(dynamicAd.single.classification.kind, SkipSegmentKind.ad);
    expect(dynamicAd.single.classification.autoSkip, isTrue);
    expect(dynamicAd.single.occurrences, hasLength(3));

    final sponsor = discoverPatterns([
      _episode(
        id: 1,
        seconds: 260,
        clip: ad,
        atSeconds: const [190],
        primer: true,
      ),
      _episode(
        id: 2,
        seconds: 260,
        clip: ad,
        atSeconds: const [190],
        primer: true,
      ),
    ]);
    expect(sponsor.single.classification.kind, SkipSegmentKind.sponsor);
    expect(sponsor.single.classification.autoSkip, isTrue);

    // 16 s : le démarrage Chromaprint mange ~2,5 s, et sous 10 s il
    // faudrait trois épisodes. Deux suffisent pour une intro longue.
    final jingle = _melody(16);
    final intro = discoverPatterns([
      _episode(id: 1, seconds: 90, clip: jingle, atSeconds: const [0]),
      _episode(id: 2, seconds: 90, clip: jingle, atSeconds: const [0]),
    ]);
    expect(intro.single.classification.kind, SkipSegmentKind.intro);
    expect(intro.single.classification.autoSkip, isTrue);

    final outroClip = _melody(18);
    final outro = discoverPatterns([
      _episode(id: 1, seconds: 120, clip: outroClip, atSeconds: const [100]),
      _episode(id: 2, seconds: 120, clip: outroClip, atSeconds: const [100]),
    ]);
    expect(outro.single.classification.kind, SkipSegmentKind.outro);
    expect(outro.single.classification.autoSkip, isTrue);

    final twice = discoverPatterns([
      _episode(id: 7, seconds: 120, clip: ad, atSeconds: const [8, 70]),
    ]);
    expect(twice, hasLength(1));
    expect(twice.single.classification.autoSkip, isFalse);
    expect(twice.single.classification.kind, isNull);
    expect(
      twice.single.classification.confidence,
      greaterThanOrEqualTo(lowConfidenceCutoff),
    );
  });
}

FingerprintEpisode _forcedSpeech(FingerprintEpisode episode) {
  final seconds = (episode.durationMs + 999) ~/ 1000;
  return FingerprintEpisode(
    episodeId: episode.episodeId,
    values: episode.values,
    hopMicros: episode.hopMicros,
    durationMs: episode.durationMs,
    speech: Uint8List(seconds)..fillRange(0, seconds, 255),
  );
}

FingerprintEpisode _episode({
  required int id,
  required int seconds,
  required Int16List clip,
  required List<int> atSeconds,
  bool primer = false,
}) {
  final rate = chromaprintSampleRate;
  // Suite de notes qui n’est pas un décalage de celle d’une autre
  // épisode (un cycle commun s’aligne sur toute la durée). Le bruit
  // noie le vrai décalage sous les collisions Chromaprint.
  final pcm = Int16List(seconds * rate);
  final step = rate ~/ 8;
  var phase = 0.0;
  var hz = 110.0;
  for (var i = 0; i < pcm.length; i++) {
    if (i % step == 0) {
      final k = i ~/ step;
      final residue = (k * k * 3 + k * id * 11 + id * 53) % 36;
      hz = 90.0 + residue * 18;
    }
    phase += 2 * math.pi * hz / rate;
    pcm[i] = (0.22 * math.sin(phase) * 32767).round();
  }
  for (final at in atSeconds) {
    final start = at * rate;
    // Même amorce avant le clip : Chromaprint oublie le lit au même
    // endroit, donc l’offset reste stable d’une épisode à l’autre.
    if (primer && start >= 4 * rate) {
      for (var i = start - 4 * rate; i < start; i++) {
        pcm[i] = 0;
      }
    }
    final end = math.min(pcm.length, start + clip.length);
    for (var i = start; i < end; i++) {
      pcm[i] = clip[i - start];
    }
  }
  return FingerprintEpisode(
    episodeId: id,
    values: chromaprintFingerprint(pcm),
    hopMicros: chromaprintStoredHopMicros,
    durationMs: seconds * 1000,
    speech: speechMusicTimeline(pcm),
  );
}

Int16List _melody(int seconds) {
  final rate = chromaprintSampleRate;
  final n = seconds * rate;
  final out = Int16List(n);
  const notes = [220.0, 247.0, 262.0, 294.0, 330.0, 294.0, 262.0, 247.0];
  final noteLen = (0.35 * rate).round();
  for (var i = 0; i < n; i++) {
    final note = notes[(i ~/ noteLen) % notes.length];
    final t = i / rate;
    final sample =
        0.55 * math.sin(2 * math.pi * note * t) +
        0.25 * math.sin(2 * math.pi * note * 2 * t) +
        0.12 * math.sin(2 * math.pi * note * 3 * t);
    out[i] = (sample * 14000).round();
  }
  return out;
}

/// Parole synthétique qui ne se répète pas à l’intérieur du clip :
/// un chirp, haché à 4 Hz, pour que Chromaprint n’aligne qu’un offset.
Int16List _voicedSpeech(int seconds, {int seed = 3}) {
  final rate = chromaprintSampleRate;
  final n = seconds * rate;
  final out = Int16List(n);
  var state = seed;
  double next() {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    return state / 0x3fffffff - 1;
  }

  final period = rate ~/ 4;
  final vowel = (rate * 0.09).round();
  final consonant = (rate * 0.035).round();
  for (var i = 0; i < n; i++) {
    final phase = i % period;
    if (phase >= vowel + consonant) {
      out[i] = (next() * 200).round();
      continue;
    }
    final t = i / rate;
    if (phase < consonant) {
      out[i] = (next() * 11000).round();
      continue;
    }
    final pitch = 110 + 280 * (i / n);
    final sample =
        0.62 * math.sin(2 * math.pi * pitch * t) +
        0.2 * math.sin(2 * math.pi * pitch * 2.5 * t) +
        0.08 * next();
    out[i] = (sample * 12000).round().clamp(-32768, 32767);
  }
  return out;
}
