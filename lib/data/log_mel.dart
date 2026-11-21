import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'chromaprint.dart';
import 'segment_match.dart';
import 'speech_music.dart';

/// Fenêtre d’analyse : 32 ms à 8 kHz, puissance de 2 pour la FFT.
const logMelFrameSize = 256;

/// Un passage log-mel déjà normalisé, trame par trame.
class LogMelClip {
  const LogMelClip(this.frames);

  final List<Float64List> frames;

  int get durationMs => frames.length * logMelHopMs;

  bool get isEmpty => frames.isEmpty;
}

/// Empreinte, log-mel des 180 premières secondes et chronologie parole,
/// lus sur le même PCM.
({List<int> fingerprint, Uint8List? logMel, Uint8List speech})
analyzePcmFileSync(String path) {
  final bytes = File(path).readAsBytesSync();
  final view = ByteData.sublistView(bytes);
  final count = bytes.lengthInBytes ~/ 2;
  final samples = Int16List(count);
  for (var i = 0; i < count; i++) {
    samples[i] = view.getInt16(i * 2, Endian.little);
  }
  final fingerprint = chromaprintFingerprint(samples);
  final clip = computeLogMel(
    resampleToLogMelRate(samples, chromaprintSampleRate),
  );
  return (
    fingerprint: fingerprint,
    logMel: clip.isEmpty
        ? null
        : encodeLogMel(clip.frames.cast<List<double>>()),
    speech: speechMusicTimeline(samples),
  );
}

/// Rééchantillonne [input] (entiers 16 bits, [fromRate]) vers 8 kHz.
///
/// [maxMs] borne la durée gardée : la recherche ne couvre que les
/// 180 premières secondes.
Float64List resampleToLogMelRate(
  Int16List input,
  int fromRate, {
  int maxMs = logMelSearchWindowMs,
}) {
  if (input.isEmpty || fromRate <= 0) return Float64List(0);
  final outCount = math.min(
    (maxMs * logMelSampleRate) ~/ 1000,
    (input.length * logMelSampleRate) ~/ fromRate,
  );
  if (outCount <= 0) return Float64List(0);
  final out = Float64List(outCount);
  final step = fromRate / logMelSampleRate;
  for (var i = 0; i < outCount; i++) {
    final position = i * step;
    final index = position.floor();
    final frac = position - index;
    final left = index < input.length ? input[index].toDouble() : 0.0;
    final right = index + 1 < input.length ? input[index + 1].toDouble() : left;
    out[i] = left + (right - left) * frac;
  }
  return out;
}

/// Spectrogramme log-mel normalisé par trame (norme euclidienne).
LogMelClip computeLogMel(Float64List samples) {
  if (samples.length < logMelFrameSize) return const LogMelClip([]);
  final filters = _melFilters;
  final window = _hann;
  final frameCount = 1 + (samples.length - logMelFrameSize) ~/ _hopSamples;
  final frames = <Float64List>[];
  final re = Float64List(logMelFrameSize);
  final im = Float64List(logMelFrameSize);
  for (var frame = 0; frame < frameCount; frame++) {
    final offset = frame * _hopSamples;
    for (var i = 0; i < logMelFrameSize; i++) {
      re[i] = samples[offset + i] * window[i];
      im[i] = 0;
    }
    _fft(re, im);
    final bands = Float64List(logMelBandCount);
    var total = 0.0;
    final powers = Float64List(logMelFrameSize ~/ 2 + 1);
    for (var bin = 0; bin < powers.length; bin++) {
      powers[bin] = re[bin] * re[bin] + im[bin] * im[bin];
      total += powers[bin];
    }
    if (total > 1e-8) {
      for (var band = 0; band < logMelBandCount; band++) {
        var energy = 0.0;
        final weights = filters[band];
        for (var bin = 0; bin < weights.length; bin++) {
          final weight = weights[bin];
          if (weight == 0) continue;
          energy += weight * powers[bin];
        }
        bands[band] = math.log(energy + 1e-10);
      }
      _normalize(bands);
    }
    frames.add(bands);
  }
  return LogMelClip(frames);
}

/// Corrélation croisée normalisée. Les trames sont déjà normalisées.
///
/// Le score vaut 1 quand le gabarit est relu tel quel, et tombe sous
/// [logMelMatchThreshold] sur un autre son.
List<LogMelMatch> searchLogMel(
  LogMelClip needle,
  LogMelClip haystack, {
  double threshold = logMelMatchThreshold,
  int minSeparationMs = 500,
}) {
  final width = needle.frames.length;
  if (width < 8 || haystack.frames.length < width) return const [];
  final needleNorm = _frobenius(needle.frames);
  if (needleNorm <= 1e-8) return const [];
  final hits = <LogMelMatch>[];
  LogMelMatch? pending;
  final limit = haystack.frames.length - width;
  for (var start = 0; start <= limit; start++) {
    var dot = 0.0;
    var energy = 0.0;
    for (var frame = 0; frame < width; frame++) {
      final a = needle.frames[frame];
      final b = haystack.frames[start + frame];
      for (var band = 0; band < logMelBandCount; band++) {
        final value = b[band];
        dot += a[band] * value;
        energy += value * value;
      }
    }
    final denom = needleNorm * math.sqrt(energy);
    if (denom <= 1e-8) continue;
    final score = dot / denom;
    if (score < threshold) continue;
    final startMs = start * logMelHopMs;
    final match = LogMelMatch(
      startMs: startMs,
      endMs: startMs + width * logMelHopMs,
      score: score,
    );
    if (pending == null || startMs - pending.startMs > minSeparationMs) {
      if (pending != null) hits.add(pending);
      pending = match;
    } else if (score > pending.score) {
      pending = match;
    }
  }
  if (pending != null) hits.add(pending);
  return hits;
}

class LogMelMatch {
  const LogMelMatch({
    required this.startMs,
    required this.endMs,
    required this.score,
  });

  final int startMs;
  final int endMs;
  final double score;
}

/// Découpe [clip] entre [startMs] et [endMs].
LogMelClip sliceLogMel(LogMelClip clip, int startMs, int endMs) {
  final start = (startMs / logMelHopMs).floor().clamp(0, clip.frames.length);
  final end = (endMs / logMelHopMs).ceil().clamp(start, clip.frames.length);
  if (end - start < 8) return const LogMelClip([]);
  return LogMelClip(clip.frames.sublist(start, end));
}

const _hopSamples = logMelSampleRate * logMelHopMs ~/ 1000;

final List<Float64List> _melFilters = _buildMelFilters();

final Float64List _hann = _buildHann();

Float64List _buildHann() {
  final window = Float64List(logMelFrameSize);
  final last = logMelFrameSize - 1;
  for (var i = 0; i < logMelFrameSize; i++) {
    window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / last);
  }
  return window;
}

List<Float64List> _buildMelFilters() {
  const bins = logMelFrameSize ~/ 2 + 1;
  final low = _hzToMel(0);
  final high = _hzToMel(logMelSampleRate / 2);
  final points = List<double>.generate(logMelBandCount + 2, (i) {
    final mel = low + (high - low) * i / (logMelBandCount + 1);
    return _melToHz(mel);
  });
  final fftBins = [
    for (final hz in points) ((logMelFrameSize + 1) * hz / logMelSampleRate),
  ];
  final filters = <Float64List>[];
  for (var band = 1; band <= logMelBandCount; band++) {
    final weights = Float64List(bins);
    final left = fftBins[band - 1];
    final center = fftBins[band];
    final right = fftBins[band + 1];
    for (var bin = 0; bin < bins; bin++) {
      if (bin < left || bin > right || center == left || right == center) {
        continue;
      }
      weights[bin] = bin <= center
          ? (bin - left) / (center - left)
          : (right - bin) / (right - center);
    }
    filters.add(weights);
  }
  return filters;
}

double _hzToMel(double hz) => 2595 * math.log(1 + hz / 700) / math.ln10;

double _melToHz(double mel) => 700 * (math.pow(10, mel / 2595) - 1);

void _normalize(Float64List frame) {
  var squares = 0.0;
  for (final value in frame) {
    squares += value * value;
  }
  if (squares < 1e-12) return;
  final inverse = 1 / math.sqrt(squares);
  for (var i = 0; i < frame.length; i++) {
    frame[i] *= inverse;
  }
}

double _frobenius(List<Float64List> frames) {
  var squares = 0.0;
  for (final frame in frames) {
    for (final value in frame) {
      squares += value * value;
    }
  }
  return math.sqrt(squares);
}

void _fft(Float64List re, Float64List im) {
  final n = re.length;
  var j = 0;
  for (var i = 0; i < n; i++) {
    if (i < j) {
      final swapRe = re[i];
      re[i] = re[j];
      re[j] = swapRe;
      final swapIm = im[i];
      im[i] = im[j];
      im[j] = swapIm;
    }
    var bit = n >> 1;
    while ((j & bit) != 0) {
      j ^= bit;
      bit >>= 1;
    }
    j ^= bit;
  }
  for (var length = 2; length <= n; length <<= 1) {
    final half = length >> 1;
    final theta = -2 * math.pi / length;
    final stepRe = math.cos(theta);
    final stepIm = math.sin(theta);
    for (var start = 0; start < n; start += length) {
      var twiddleRe = 1.0;
      var twiddleIm = 0.0;
      for (var k = 0; k < half; k++) {
        final oddRe = re[start + k + half];
        final oddIm = im[start + k + half];
        final mixedRe = twiddleRe * oddRe - twiddleIm * oddIm;
        final mixedIm = twiddleRe * oddIm + twiddleIm * oddRe;
        final evenRe = re[start + k];
        final evenIm = im[start + k];
        re[start + k] = evenRe + mixedRe;
        im[start + k] = evenIm + mixedIm;
        re[start + k + half] = evenRe - mixedRe;
        im[start + k + half] = evenIm - mixedIm;
        final nextRe = twiddleRe * stepRe - twiddleIm * stepIm;
        twiddleIm = twiddleRe * stepIm + twiddleIm * stepRe;
        twiddleRe = nextRe;
      }
    }
  }
}
