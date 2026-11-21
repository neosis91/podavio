import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'chromaprint.dart';
import 'segment_match.dart';
import 'speech_music.dart';

/// Empreinte, log-mel et chronologie, lus sans garder l’épisode en RAM.
class PcmAnalysis {
  const PcmAnalysis({
    required this.fingerprint,
    required this.logMel,
    required this.speech,
    required this.peakRss,
    required this.retainedBytes,
    required this.elapsedMs,
    required this.fingerprintMs,
    required this.logMelMs,
    required this.speechMs,
  });

  final List<int> fingerprint;
  final Uint8List? logMel;
  final Uint8List speech;
  final int peakRss;
  final int retainedBytes;
  final int elapsedMs;
  final int fingerprintMs;
  final int logMelMs;
  final int speechMs;
}

/// Fenêtre d’analyse : 32 ms à 8 kHz, puissance de 2 pour la FFT.
const logMelFrameSize = 256;

/// Un passage log-mel déjà normalisé, trame par trame.
class LogMelClip {
  const LogMelClip(this.frames);

  final List<Float64List> frames;

  int get durationMs => frames.length * logMelHopMs;

  bool get isEmpty => frames.isEmpty;
}

/// Empreinte, log-mel des 180 premières secondes et chronologie parole.
///
/// Le fichier est lu par blocs. Chromaprint et la note parole avancent
/// au fil de l’eau. Le log-mel ne garde que les 180 premières secondes,
/// déjà rééchantillonnées à 8 kHz.
PcmAnalysis analyzePcmFileSync(String path) {
  final watch = Stopwatch()..start();
  final file = File(path);
  final input = file.openSync();
  final hasher = ChromaprintHasher();
  final speech = SpeechTimelineBuilder();
  final totalSamples = file.lengthSync() ~/ 2;
  final resampler = LogMelResampler(
    maxSamples: math.min(
      (logMelSearchWindowMs * logMelSampleRate) ~/ 1000,
      totalSamples <= 0
          ? 0
          : (totalSamples * logMelSampleRate) ~/ chromaprintSampleRate + 2,
    ),
  );
  const chunkSamples = 8192;
  final raw = Uint8List(chunkSamples * 2);
  final piece = Int16List(chunkSamples);
  var retained = 0;
  var peakRss = _rss();
  var fingerprintUs = 0;
  var speechUs = 0;
  try {
    while (true) {
      final read = input.readIntoSync(raw);
      if (read < 2) break;
      final samples = read ~/ 2;
      final view = ByteData.sublistView(raw, 0, samples * 2);
      for (var i = 0; i < samples; i++) {
        piece[i] = view.getInt16(i * 2, Endian.little);
      }
      final slice = samples == chunkSamples
          ? piece
          : Int16List.sublistView(piece, 0, samples);
      final finger = Stopwatch()..start();
      hasher.add(slice);
      fingerprintUs += finger.elapsedMicroseconds;
      final spoken = Stopwatch()..start();
      speech.add(slice);
      speechUs += spoken.elapsedMicroseconds;
      resampler.add(slice);
      final held =
          raw.length +
          speech.retainedBytes +
          resampler.retainedBytes +
          hasher.valueCount * 8;
      if (held > retained) retained = held;
      final rss = _rss();
      if (rss > peakRss) peakRss = rss;
    }
  } finally {
    input.closeSync();
  }
  final fingerprint = hasher.finish();
  final melWatch = Stopwatch()..start();
  final clip = computeLogMel(resampler.output);
  final logMelMs = melWatch.elapsedMilliseconds;
  final fingerprintMs = fingerprintUs ~/ 1000;
  final speechMs = speechUs ~/ 1000;
  final logMel = clip.isEmpty
      ? null
      : encodeLogMel(clip.frames.cast<List<double>>());
  final speechBytes = speech.finish();
  final framesBytes = clip.frames.length * logMelBandCount * 8;
  final endHeld = fingerprint.length * 8 + (logMel?.length ?? 0) + framesBytes;
  if (endHeld > retained) retained = endHeld;
  final rss = _rss();
  if (rss > peakRss) peakRss = rss;
  return PcmAnalysis(
    fingerprint: fingerprint,
    logMel: logMel,
    speech: speechBytes,
    peakRss: peakRss,
    retainedBytes: retained,
    elapsedMs: watch.elapsedMilliseconds,
    fingerprintMs: fingerprintMs,
    logMelMs: logMelMs,
    speechMs: speechMs,
  );
}

int _rss() {
  try {
    return ProcessInfo.currentRss;
  } catch (_) {
    return 0;
  }
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

/// Rééchantillonnage linéaire vers 8 kHz, borné à [maxSamples].
///
/// Ne garde que le dernier échantillon source déjà vu, plus la sortie.
/// Le résultat est celui de [resampleToLogMelRate] sur la même suite.
class LogMelResampler {
  LogMelResampler({required this.maxSamples})
    : _buffer = Float64List(maxSamples < 0 ? 0 : maxSamples);

  final int maxSamples;
  final Float64List _buffer;
  var produced = 0;
  var consumed = 0;
  int? _previous;

  int get retainedBytes => _buffer.lengthInBytes;

  void add(Int16List chunk) {
    if (chunk.isEmpty || produced >= _buffer.length) return;
    while (produced < _buffer.length) {
      final position = produced * chromaprintSampleRate / logMelSampleRate;
      final index = position.floor();
      final local = index - consumed;
      final next = local + 1;
      if (next >= chunk.length) break;
      final left = local >= 0
          ? chunk[local].toDouble()
          : (_previous ?? chunk[0]).toDouble();
      final right = chunk[next].toDouble();
      final frac = position - index;
      _buffer[produced] = left + (right - left) * frac;
      produced++;
    }
    _previous = chunk[chunk.length - 1];
    consumed += chunk.length;
  }

  /// Termine les échantillons dont le voisin de droite n’existe pas.
  void finish() {
    if (_previous == null) return;
    while (produced < _buffer.length) {
      final position = produced * chromaprintSampleRate / logMelSampleRate;
      final index = position.floor();
      if (index + 1 < consumed) break;
      if (index >= consumed) break;
      _buffer[produced] = _previous!.toDouble();
      produced++;
    }
  }

  Float64List get output {
    finish();
    if (produced == _buffer.length) return _buffer;
    return Float64List.sublistView(_buffer, 0, produced);
  }
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
