import 'dart:math' as math;
import 'dart:typed_data';

import 'chromaprint.dart';
import 'fft.dart';

/// Une valeur de parole par seconde, alignée sur le PCM déjà décodé.
const speechMusicHopMs = 1000;

/// Trame courte pour le taux de passages par zéro et l’énergie.
const _subframeMs = 20;

/// Quatre spectres par seconde : flux, chroma, harmonicité.
const _fftSize = 512;

const _spectraPerSecond = 4;

/// Mesures moyennes d’un extrait. [speech] vaut 1 pour de la parole,
/// 0 pour un son tonal continu.
class SpeechMusicStats {
  const SpeechMusicStats({
    required this.speech,
    required this.zcrVariance,
    required this.lowEnergyRatio,
    required this.modulation4Hz,
    required this.spectralFlux,
    required this.harmonicity,
    required this.chromaStability,
  });

  final double speech;
  final double zcrVariance;
  final double lowEnergyRatio;
  final double modulation4Hz;
  final double spectralFlux;
  final double harmonicity;
  final double chromaStability;
}

/// Profil d’une seconde. Les rampes sont celles mesurées sur les signaux
/// synthétiques du test : bruit modulé à 4 Hz, parole voisée, lit musical,
/// refrain chanté.
class _Second {
  const _Second({
    required this.speech,
    required this.zcrVariance,
    required this.lowEnergyRatio,
    required this.modulation4Hz,
    required this.spectralFlux,
    required this.harmonicity,
    required this.chromaStability,
  });

  final double speech;
  final double zcrVariance;
  final double lowEnergyRatio;
  final double modulation4Hz;
  final double spectralFlux;
  final double harmonicity;
  final double chromaStability;
}

/// 0 = musique, 255 = parole. Un octet par seconde entière.
///
/// Le calcul reste dans l’isolate qui empreinte déjà ce PCM : pas de
/// second décodage, pas de modèle. Une heure tient en 3600 octets.
///
/// [SpeechTimelineBuilder] fait le même calcul en ne gardant qu’une
/// seconde de PCM à la fois.
Uint8List speechMusicTimeline(
  Int16List samples, {
  int sampleRate = chromaprintSampleRate,
}) {
  final builder = SpeechTimelineBuilder(sampleRate: sampleRate);
  const chunk = 4096;
  var offset = 0;
  while (offset < samples.length) {
    final end = math.min(samples.length, offset + chunk);
    builder.add(Int16List.sublistView(samples, offset, end));
    offset = end;
  }
  return builder.finish();
}

/// Chronologie parole/musique, une seconde à la fois.
///
/// Le tampon interne fait une seconde. Le PCM du reste de l’épisode
/// n’est pas retenu.
class SpeechTimelineBuilder {
  SpeechTimelineBuilder({int sampleRate = chromaprintSampleRate})
    : _sampleRate = sampleRate,
      _scratch = sampleRate > 0 ? _Scratch(sampleRate) : null,
      _hold = Int16List(sampleRate > 0 ? sampleRate : 0);

  final int _sampleRate;
  final _Scratch? _scratch;
  final Int16List _hold;
  var _held = 0;
  final _out = BytesBuilder(copy: false);

  /// Octets du tampon d’une seconde, pour la trace mémoire.
  int get retainedBytes => _hold.lengthInBytes;

  void add(Int16List samples) {
    final scratch = _scratch;
    if (scratch == null || samples.isEmpty) return;
    var offset = 0;
    while (offset < samples.length) {
      final room = _sampleRate - _held;
      final take = math.min(room, samples.length - offset);
      _hold.setRange(_held, _held + take, samples, offset);
      _held += take;
      offset += take;
      if (_held != _sampleRate) continue;
      final features = scratch.measure(_hold, 0);
      _out.addByte((features.speech * 255).round().clamp(0, 255));
      _held = 0;
    }
  }

  Uint8List finish() => _out.takeBytes();
}

/// Moyenne des descripteurs sur les secondes entières de [samples].
SpeechMusicStats measureSpeechMusic(
  Int16List samples, {
  int sampleRate = chromaprintSampleRate,
}) {
  final seconds = _wholeSeconds(samples, sampleRate);
  if (seconds <= 0) {
    return const SpeechMusicStats(
      speech: 0,
      zcrVariance: 0,
      lowEnergyRatio: 0,
      modulation4Hz: 0,
      spectralFlux: 0,
      harmonicity: 0,
      chromaStability: 0,
    );
  }
  final scratch = _Scratch(sampleRate);
  var speech = 0.0;
  var zcr = 0.0;
  var low = 0.0;
  var mod = 0.0;
  var flux = 0.0;
  var harm = 0.0;
  var chroma = 0.0;
  for (var second = 0; second < seconds; second++) {
    final features = scratch.measure(samples, second * sampleRate);
    speech += features.speech;
    zcr += features.zcrVariance;
    low += features.lowEnergyRatio;
    mod += features.modulation4Hz;
    flux += features.spectralFlux;
    harm += features.harmonicity;
    chroma += features.chromaStability;
  }
  final n = seconds.toDouble();
  return SpeechMusicStats(
    speech: speech / n,
    zcrVariance: zcr / n,
    lowEnergyRatio: low / n,
    modulation4Hz: mod / n,
    spectralFlux: flux / n,
    harmonicity: harm / n,
    chromaStability: chroma / n,
  );
}

/// Moyenne 0–1 des secondes que couvre [startMs, endMs[.
///
/// `null` si la chronologie est absente : l’épisode n’a pas encore été
/// noté. On ne décide alors pas « musique » sur ce seul critère.
double? speechRatioIn(Uint8List? timeline, int startMs, int endMs) {
  if (timeline == null || timeline.isEmpty || endMs <= startMs) return null;
  final first = startMs ~/ speechMusicHopMs;
  var last = (endMs + speechMusicHopMs - 1) ~/ speechMusicHopMs;
  if (first >= timeline.length) return null;
  if (last > timeline.length) last = timeline.length;
  if (last <= first) {
    return timeline[first.clamp(0, timeline.length - 1)] / 255.0;
  }
  var sum = 0;
  for (var i = first; i < last; i++) {
    sum += timeline[i];
  }
  return sum / (255.0 * (last - first));
}

int _wholeSeconds(Int16List samples, int sampleRate) {
  if (samples.isEmpty || sampleRate <= 0) return 0;
  return samples.length ~/ sampleRate;
}

double _ramp(double value, double low, double high) {
  if (value <= low) return 0;
  if (value >= high) return 1;
  return (value - low) / (high - low);
}

/// Parole : pauses, consonnes, enveloppe syllabique.
/// Musique : énergie continue, spectre stable, partiels qui tiennent.
///
/// Un son continu et au taux de passages par zéro stable (chant, lit tonal)
/// est rabattu : le flux spectral d’un changement de note ne suffit pas
/// à le faire passer pour de la parole.
double _speechLikelihood(_Second raw) {
  final zcr = _ramp(raw.zcrVariance, 0.004, 0.03);
  final pauses = _ramp(raw.lowEnergyRatio, 0.08, 0.42);
  final syllable = _ramp(raw.modulation4Hz, 0.05, 0.28);
  final flux = _ramp(raw.spectralFlux, 0.08, 0.35);
  final tonal = _ramp(raw.harmonicity, 0.35, 0.82);
  final steady = _ramp(raw.chromaStability, 0.72, 0.97);
  final mixed =
      0.22 * zcr +
      0.24 * pauses +
      0.22 * syllable +
      0.14 * flux +
      0.10 * (1 - tonal) +
      0.08 * (1 - steady);
  final continuous = (1 - pauses) * (1 - zcr);
  return (mixed * (1 - 0.55 * continuous)).clamp(0.0, 1.0);
}

class _Scratch {
  _Scratch(this.sampleRate)
    : frameSamples = math.max(1, sampleRate * _subframeMs ~/ 1000),
      window = _hann,
      windowed = Float64List(_fftSize),
      power = Float64List(_fftSize ~/ 2 + 1),
      mag = Float64List(_fftSize ~/ 2 + 1),
      previous = Float64List(_fftSize ~/ 2 + 1),
      chroma = Float64List(12),
      previousChroma = Float64List(12),
      timed = Float64List(_fftSize),
      zcr = Float64List(64),
      envelope = Float64List(64);

  final int sampleRate;
  final int frameSamples;
  final RealFft fft = RealFft(_fftSize);
  final Float64List window;
  final Float64List windowed;
  final Float64List power;
  final Float64List mag;
  final Float64List previous;
  final Float64List chroma;
  final Float64List previousChroma;
  final Float64List timed;
  final Float64List zcr;
  final Float64List envelope;

  _Second measure(Int16List samples, int origin) {
    final frames = math.min(zcr.length, sampleRate ~/ frameSamples);
    final zcrView = Float64List.sublistView(zcr, 0, frames);
    final envelopeView = Float64List.sublistView(envelope, 0, frames);
    for (var frame = 0; frame < frames; frame++) {
      final start = origin + frame * frameSamples;
      var crossings = 0;
      var sumSq = 0.0;
      var previous = samples[start];
      sumSq += previous * previous;
      var previousPositive = previous >= 0;
      for (var i = 1; i < frameSamples; i++) {
        final value = samples[start + i];
        sumSq += value * value;
        final positive = value >= 0;
        if (positive != previousPositive) crossings++;
        previousPositive = positive;
      }
      zcrView[frame] = crossings / (frameSamples - 1);
      envelopeView[frame] = math.sqrt(sumSq / frameSamples);
    }

    final zcrVariance = _variance(zcrView);
    final lowEnergy = _lowEnergyRatio(envelopeView);
    final modulation = _modulation4Hz(envelopeView);

    var fluxSum = 0.0;
    var fluxCount = 0;
    var harmSum = 0.0;
    var harmCount = 0;
    var chromaSum = 0.0;
    var chromaCount = 0;
    var haveSpectrum = false;
    var haveChroma = false;
    for (var index = 0; index < _spectraPerSecond; index++) {
      final at = origin + (sampleRate * index) ~/ _spectraPerSecond;
      if (at < 0 || at + _fftSize > samples.length) continue;
      _spectrum(samples, at);
      _harmonicityAt(samples, at);
      harmSum += _harmonicity(timed, sampleRate);
      harmCount++;
      if (haveSpectrum) {
        fluxSum += _flux(previous, mag);
        fluxCount++;
      }
      _copy(mag, previous);
      haveSpectrum = true;
      _foldChroma(mag, chroma, sampleRate);
      if (haveChroma) {
        chromaSum += _dot(previousChroma, chroma);
        chromaCount++;
      }
      _copy(chroma, previousChroma);
      haveChroma = true;
    }

    final raw = _Second(
      speech: 0,
      zcrVariance: zcrVariance,
      lowEnergyRatio: lowEnergy,
      modulation4Hz: modulation,
      spectralFlux: fluxCount == 0 ? 0 : fluxSum / fluxCount,
      harmonicity: harmCount == 0 ? 0 : harmSum / harmCount,
      chromaStability: chromaCount == 0 ? 0 : chromaSum / chromaCount,
    );
    return _Second(
      speech: _speechLikelihood(raw),
      zcrVariance: raw.zcrVariance,
      lowEnergyRatio: raw.lowEnergyRatio,
      modulation4Hz: raw.modulation4Hz,
      spectralFlux: raw.spectralFlux,
      harmonicity: raw.harmonicity,
      chromaStability: raw.chromaStability,
    );
  }

  void _spectrum(Int16List samples, int at) {
    for (var i = 0; i < _fftSize; i++) {
      windowed[i] = samples[at + i] * window[i];
    }
    fft.power(windowed, power);
    for (var bin = 0; bin < mag.length; bin++) {
      mag[bin] = math.sqrt(power[bin]);
    }
  }

  void _harmonicityAt(Int16List samples, int at) {
    for (var i = 0; i < _fftSize; i++) {
      timed[i] = samples[at + i].toDouble();
    }
  }
}

double _variance(Float64List values) {
  if (values.isEmpty) return 0;
  var mean = 0.0;
  for (final value in values) {
    mean += value;
  }
  mean /= values.length;
  var sum = 0.0;
  for (final value in values) {
    final delta = value - mean;
    sum += delta * delta;
  }
  return sum / values.length;
}

double _lowEnergyRatio(Float64List envelope) {
  if (envelope.isEmpty) return 0;
  var mean = 0.0;
  for (final value in envelope) {
    mean += value;
  }
  mean /= envelope.length;
  if (mean < 1e-6) return 0;
  final limit = mean * 0.5;
  var quiet = 0;
  for (final value in envelope) {
    if (value < limit) quiet++;
  }
  return quiet / envelope.length;
}

/// Part de l’énergie d’enveloppe située à 4 Hz (débit syllabique).
///
/// [envelope] est recentré sur place : l’appelant a déjà lu les niveaux.
double _modulation4Hz(Float64List envelope) {
  final n = envelope.length;
  if (n < 8) return 0;
  var mean = 0.0;
  for (final value in envelope) {
    mean += value;
  }
  mean /= n;
  var energy = 0.0;
  for (var i = 0; i < n; i++) {
    final value = envelope[i] - mean;
    envelope[i] = value;
    energy += value * value;
  }
  if (energy < 1e-8) return 0;
  final omega = 2 * math.pi * 4 / n;
  final coeff = 2 * math.cos(omega);
  var s0 = 0.0;
  var s1 = 0.0;
  var s2 = 0.0;
  for (var i = 0; i < n; i++) {
    s0 = envelope[i] + coeff * s1 - s2;
    s2 = s1;
    s1 = s0;
  }
  final power = s1 * s1 + s2 * s2 - coeff * s1 * s2;
  return (power / (energy * n)).clamp(0.0, 1.0);
}

double _flux(Float64List previous, Float64List current) {
  var numerator = 0.0;
  var denominator = 0.0;
  for (var i = 1; i < previous.length; i++) {
    numerator += (current[i] - previous[i]).abs();
    denominator += previous[i] + current[i];
  }
  if (denominator < 1e-8) return 0;
  return numerator / denominator;
}

void _foldChroma(Float64List mag, Float64List chroma, int sampleRate) {
  for (var i = 0; i < chroma.length; i++) {
    chroma[i] = 0;
  }
  for (var bin = 1; bin < mag.length; bin++) {
    final hz = bin * sampleRate / _fftSize;
    if (hz < 80 || hz > 4000) continue;
    final pitch = 12 * math.log(hz / 440) / math.ln2;
    var pc = pitch.round() % 12;
    if (pc < 0) pc += 12;
    chroma[pc] += mag[bin];
  }
  var squares = 0.0;
  for (final value in chroma) {
    squares += value * value;
  }
  if (squares < 1e-12) return;
  final scale = 1 / math.sqrt(squares);
  for (var i = 0; i < chroma.length; i++) {
    chroma[i] *= scale;
  }
}

double _dot(Float64List a, Float64List b) {
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }
  return sum.clamp(0.0, 1.0);
}

/// Pic d’autocorrélation dans la tessiture parlée ou chantée (80–500 Hz).
double _harmonicity(Float64List frame, int sampleRate) {
  const step = 2;
  final rate = sampleRate ~/ step;
  final lagMin = math.max(1, rate ~/ 500);
  final lagMax = math.min(frame.length ~/ step - 1, rate ~/ 80);
  if (lagMax <= lagMin) return 0;
  final n = frame.length ~/ step;
  var r0 = 0.0;
  for (var i = 0; i < n; i++) {
    final value = frame[i * step];
    r0 += value * value;
  }
  if (r0 < 1e-3) return 0;
  var best = 0.0;
  for (var lag = lagMin; lag <= lagMax; lag++) {
    var sum = 0.0;
    final limit = n - lag;
    for (var i = 0; i < limit; i++) {
      sum += frame[i * step] * frame[(i + lag) * step];
    }
    if (sum > best) best = sum;
  }
  return (best / r0).clamp(0.0, 1.0);
}

void _copy(Float64List from, Float64List to) {
  for (var i = 0; i < from.length; i++) {
    to[i] = from[i];
  }
}

final Float64List _hann = _buildHann();

Float64List _buildHann() {
  final window = Float64List(_fftSize);
  final last = _fftSize - 1;
  for (var i = 0; i < _fftSize; i++) {
    window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / last);
  }
  return window;
}
