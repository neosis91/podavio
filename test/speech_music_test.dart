import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/segment_match.dart';
import 'package:podavio/data/speech_music.dart';

void main() {
  test('speech-like noise scores above tonal music and singing', () {
    final noise = measureSpeechMusic(_modulatedNoise(8));
    final voiced = measureSpeechMusic(_voicedSpeech(8));
    final overBed = measureSpeechMusic(_speechOverBed(8));
    final tonal = measureSpeechMusic(_tonalLoop(8));
    final sung = measureSpeechMusic(_sungRefrain(8));

    // Écart mesuré : chant 0,18, lit tonal 0,03, parole ≥ 0,78.
    expect(tonal.speech, lessThan(intraMusicRejectRatio));
    expect(sung.speech, lessThan(intraMusicRejectRatio));
    expect(noise.speech, greaterThan(0.7));
    expect(voiced.speech, greaterThan(0.7));
    expect(overBed.speech, greaterThan(0.7));
    expect(voiced.lowEnergyRatio, greaterThan(sung.lowEnergyRatio));
    expect(voiced.zcrVariance, greaterThan(tonal.zcrVariance));
    expect(voiced.modulation4Hz, greaterThan(tonal.modulation4Hz));
    expect(sung.harmonicity, greaterThan(voiced.harmonicity));

    final noiseBytes = speechMusicTimeline(_modulatedNoise(3));
    final musicBytes = speechMusicTimeline(_tonalLoop(3));
    expect(speechRatioIn(noiseBytes, 0, 3000), greaterThan(0.7));
    expect(speechRatioIn(musicBytes, 0, 3000), lessThan(intraMusicRejectRatio));
    expect(speechRatioIn(null, 0, 3000), isNull);
  });

  test('timeline cost stays under a few seconds per hour', () {
    final samples = _tonalLoop(20);
    final watch = Stopwatch()..start();
    final timeline = speechMusicTimeline(samples);
    watch.stop();
    final perHourMs = watch.elapsedMicroseconds / 20 * 3600 / 1000;
    expect(timeline, hasLength(20));
    // Mesuré ~0,7 s/h sur le CPU virtualisé de développement.
    // La borne laisse de la marge à une machine plus lente.
    expect(perHourMs, lessThan(8000));
  });
}

Int16List _modulatedNoise(int seconds, {int seed = 1}) {
  final rate = chromaprintSampleRate;
  final n = seconds * rate;
  final out = Int16List(n);
  var state = seed;
  double next() {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    return state / 0x3fffffff - 1;
  }

  final period = rate ~/ 4;
  final burst = (rate * 0.13).round();
  var smooth = 0.0;
  for (var i = 0; i < n; i++) {
    final phase = i % period;
    if (phase >= burst) {
      out[i] = (next() * 400).round();
      continue;
    }
    final noise = next();
    final syllable = (i ~/ period).isEven;
    if (syllable) {
      out[i] = (noise * 14000).round();
    } else {
      smooth += 0.15 * (noise - smooth);
      out[i] = (smooth * 18000).round().clamp(-32768, 32767);
    }
  }
  return out;
}

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
  const pitches = [120.0, 140.0, 110.0, 160.0, 130.0];
  for (var i = 0; i < n; i++) {
    final phase = i % period;
    if (phase >= vowel + consonant) {
      out[i] = (next() * 250).round();
      continue;
    }
    final t = i / rate;
    if (phase < consonant) {
      out[i] = (next() * 11000).round();
      continue;
    }
    final pitch = pitches[(i ~/ period) % pitches.length];
    final sample =
        0.62 * math.sin(2 * math.pi * pitch * t) +
        0.22 * math.sin(2 * math.pi * pitch * 2 * t) +
        0.08 * next();
    out[i] = (sample * 12000).round().clamp(-32768, 32767);
  }
  return out;
}

Int16List _tonalLoop(int seconds) {
  final rate = chromaprintSampleRate;
  final n = seconds * rate;
  final out = Int16List(n);
  for (var i = 0; i < n; i++) {
    final t = i / rate;
    final sample =
        0.42 * math.sin(2 * math.pi * 220 * t) +
        0.26 * math.sin(2 * math.pi * 277.18 * t) +
        0.18 * math.sin(2 * math.pi * 329.63 * t) +
        0.10 * math.sin(2 * math.pi * 440 * t);
    out[i] = (sample * 16000).round();
  }
  return out;
}

Int16List _sungRefrain(int seconds) {
  final rate = chromaprintSampleRate;
  final n = seconds * rate;
  final out = Int16List(n);
  const notes = [196.0, 220.0, 246.94, 261.63, 246.94, 220.0, 196.0, 174.61];
  final noteLen = (0.28 * rate).round();
  for (var i = 0; i < n; i++) {
    final note = notes[(i ~/ noteLen) % notes.length];
    final t = i / rate;
    final pos = (i % noteLen) / noteLen;
    final env = 0.65 + 0.35 * math.sin(math.pi * pos);
    final sample =
        env *
        (0.55 * math.sin(2 * math.pi * note * t) +
            0.28 * math.sin(2 * math.pi * note * 2 * t) +
            0.12 * math.sin(2 * math.pi * note * 3 * t));
    out[i] = (sample * 14000).round().clamp(-32768, 32767);
  }
  return out;
}

Int16List _speechOverBed(int seconds) {
  final speech = _voicedSpeech(seconds, seed: 9);
  final bed = _tonalLoop(seconds);
  final out = Int16List(speech.length);
  for (var i = 0; i < out.length; i++) {
    final mixed = speech[i] + bed[i] * 0.22;
    out[i] = mixed.round().clamp(-32768, 32767);
  }
  return out;
}
