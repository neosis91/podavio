import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'chromaprint.dart';
import 'envelope.dart';
import 'fft.dart';
import 'segment_match.dart';
import 'speech_music.dart';

/// Empreinte, log-mel et chronologie, lus sans garder l’épisode en RAM.
class PcmAnalysis {
  const PcmAnalysis({
    required this.fingerprint,
    required this.logMel,
    required this.speech,
    required this.envelope,
    required this.peakRss,
    required this.retainedBytes,
    required this.elapsedMs,
    required this.fingerprintMs,
    required this.logMelMs,
    required this.speechMs,
    this.olaf,
    this.olafAds,
  });

  final List<int> fingerprint;
  final Uint8List? logMel;
  final Uint8List speech;

  /// Énergie toutes les 20 ms. Vide si le fichier est trop court.
  final Uint8List envelope;
  final int peakRss;
  final int retainedBytes;
  final int elapsedMs;
  final int fingerprintMs;
  final int logMelMs;
  final int speechMs;

  /// Landmarks Olaf des trois premières minutes. Null si la bibliothèque
  /// native n’est pas là : la recherche log-mel reste alors le repli.
  final Uint8List? olaf;

  /// Landmarks Olaf de l’épisode entier, sous-échantillonnés, avec le
  /// magic `Olaf`. Null si la bibliothèque native n’est pas là.
  final Uint8List? olafAds;
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

/// Log-mel des 180 premières secondes et chronologie parole.
///
/// Le fichier est lu par blocs. La note parole avance au fil de l’eau.
/// Le log-mel ne garde que les 180 premières secondes, déjà
/// rééchantillonnées à 8 kHz. L’empreinte des pubs est Olaf, calculée
/// à côté, pas dans ce lecteur : [fingerprint] reste vide.
PcmAnalysis analyzePcmFileSync(String path) {
  final reader = _PcmReader(path);
  try {
    reader.drain();
    return reader.finish();
  } finally {
    reader.close();
  }
}

/// Comme [analyzePcmFileSync], en rendant la main entre les blocs.
///
/// [slow] renvoie `play`, `front` ou `fast`. Pendant la lecture, chaque
/// bloc est suivi de 12 ms de pause. Au premier plan, on cède seulement
/// l’ordonnancement. `fast` ne s’arrête presque pas.
Future<PcmAnalysis> analyzePcmFilePaced(
  String path,
  String Function() slow,
) async {
  final reader = _PcmReader(path);
  var chunks = 0;
  try {
    while (reader.pull()) {
      chunks++;
      final mode = slow();
      if (mode == 'play') {
        // ~8 ms de calcul par bloc sur un téléphone : 12 ms de pause
        // ramène le cœur sous la moitié, le temps que l’audio passe.
        await Future<void>.delayed(const Duration(milliseconds: 12));
      } else if (mode == 'front' && chunks % 8 == 0) {
        await Future<void>.delayed(Duration.zero);
      } else if (chunks % 32 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return reader.finish();
  } finally {
    reader.close();
  }
}

/// Lecteur de PCM par blocs. L’empreinte, la parole, l’enveloppe et le
/// rééchantillonnage avancent ensemble. Seules les 180 premières secondes
/// du log-mel sont gardées.
class _PcmReader {
  _PcmReader(String path)
    : _watch = Stopwatch()..start(),
      _input = File(path).openSync(),
      _resampler = LogMelResampler(
        maxSamples: _melCap(File(path).lengthSync()),
      ),
      _peakRss = _rss();

  static int _melCap(int fileBytes) {
    final window = (logMelSearchWindowMs * logMelSampleRate) ~/ 1000;
    if (fileBytes <= 1) return 0;
    final fromFile =
        (fileBytes ~/ 2 * logMelSampleRate) ~/ chromaprintSampleRate + 2;
    return math.min(window, fromFile);
  }

  final Stopwatch _watch;
  final RandomAccessFile _input;
  final SpeechTimelineBuilder _speech = SpeechTimelineBuilder();
  final EnergyEnvelopeBuilder _envelope = EnergyEnvelopeBuilder();
  final LogMelResampler _resampler;
  final Uint8List _raw = Uint8List(8192 * 2);
  final Int16List _piece = Int16List(8192);
  var _retained = 0;
  var _peakRss = 0;
  var _speechUs = 0;
  var _open = true;

  void drain() {
    while (pull()) {}
  }

  bool pull() {
    final read = _input.readIntoSync(_raw);
    if (read < 2) return false;
    final samples = read ~/ 2;
    final view = ByteData.sublistView(_raw, 0, samples * 2);
    for (var i = 0; i < samples; i++) {
      _piece[i] = view.getInt16(i * 2, Endian.little);
    }
    final slice = samples == _piece.length
        ? _piece
        : Int16List.sublistView(_piece, 0, samples);
    final spoken = Stopwatch()..start();
    _speech.add(slice);
    _speechUs += spoken.elapsedMicroseconds;
    _envelope.add(slice);
    _resampler.add(slice);
    final held =
        _raw.length +
        _speech.retainedBytes +
        _resampler.retainedBytes +
        _envelope.retainedBytes;
    if (held > _retained) _retained = held;
    final rss = _rss();
    if (rss > _peakRss) _peakRss = rss;
    return true;
  }

  PcmAnalysis finish() {
    final melWatch = Stopwatch()..start();
    final clip = computeLogMel(_resampler.output);
    final logMelMs = melWatch.elapsedMilliseconds;
    final logMel = clip.isEmpty
        ? null
        : encodeLogMel(clip.frames.cast<List<double>>());
    final speechBytes = _speech.finish();
    final envelope = _envelope.finish();
    final framesBytes = clip.frames.length * logMelBandCount * 8;
    final endHeld = (logMel?.length ?? 0) + framesBytes + envelope.length;
    if (endHeld > _retained) _retained = endHeld;
    final rss = _rss();
    if (rss > _peakRss) _peakRss = rss;
    return PcmAnalysis(
      fingerprint: const [],
      logMel: logMel,
      speech: speechBytes,
      envelope: envelope,
      peakRss: _peakRss,
      retainedBytes: _retained,
      elapsedMs: _watch.elapsedMilliseconds,
      fingerprintMs: 0,
      logMelMs: logMelMs,
      speechMs: _speechUs ~/ 1000,
    );
  }

  void close() {
    if (!_open) return;
    _open = false;
    _input.closeSync();
  }
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
  final starts = _melStart;
  final ends = _melEnd;
  final window = _hann;
  final frameCount = 1 + (samples.length - logMelFrameSize) ~/ _hopSamples;
  final flat = Float64List(frameCount * logMelBandCount);
  final frames = <Float64List>[];
  final fft = RealFft(logMelFrameSize);
  final frame = Float64List(logMelFrameSize);
  final powers = Float64List(logMelFrameSize ~/ 2 + 1);
  for (var index = 0; index < frameCount; index++) {
    final offset = index * _hopSamples;
    for (var i = 0; i < logMelFrameSize; i++) {
      frame[i] = samples[offset + i] * window[i];
    }
    fft.power(frame, powers);
    final bands = Float64List.sublistView(
      flat,
      index * logMelBandCount,
      (index + 1) * logMelBandCount,
    );
    var total = 0.0;
    for (var bin = 0; bin < powers.length; bin++) {
      total += powers[bin];
    }
    if (total > 1e-8) {
      for (var band = 0; band < logMelBandCount; band++) {
        var energy = 0.0;
        final weights = filters[band];
        final end = ends[band];
        for (var bin = starts[band]; bin < end; bin++) {
          energy += weights[bin] * powers[bin];
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
  final limit = haystack.frames.length - width;
  // Pas de 4 trames (40 ms), puis recalage au pas de 10 ms. Les trames
  // se recouvrent de 22 ms : un vrai pic reste visible sur le pas grossier.
  const stride = 4;
  const gateMargin = 0.12;
  final hits = <LogMelMatch>[];
  LogMelMatch? pending;
  var scannedTo = -1;

  void consider(int start, double score) {
    if (score < threshold) return;
    final startMs = start * logMelHopMs;
    final match = LogMelMatch(
      startMs: startMs,
      endMs: startMs + width * logMelHopMs,
      score: score,
    );
    final current = pending;
    if (current == null || startMs - current.startMs > minSeparationMs) {
      if (current != null) hits.add(current);
      pending = match;
    } else if (score > current.score) {
      pending = match;
    }
  }

  if (limit <= 48) {
    for (var start = 0; start <= limit; start++) {
      consider(
        start,
        _logMelScore(
          needle,
          haystack,
          start,
          width,
          needleNorm,
          threshold: threshold,
          abort: false,
        ),
      );
    }
  } else {
    final gate = threshold - gateMargin;
    for (var coarse = 0; coarse <= limit; coarse += stride) {
      final coarseScore = _logMelScore(
        needle,
        haystack,
        coarse,
        width,
        needleNorm,
        threshold: gate,
        abort: true,
      );
      if (coarseScore < gate) continue;
      final from = math.max(scannedTo + 1, coarse - stride);
      final to = math.min(limit, coarse + stride);
      for (var start = from; start <= to; start++) {
        consider(
          start,
          _logMelScore(
            needle,
            haystack,
            start,
            width,
            needleNorm,
            threshold: threshold,
            abort: false,
          ),
        );
      }
      scannedTo = to;
    }
  }
  final last = pending;
  if (last != null) hits.add(last);
  return hits;
}

double _logMelScore(
  LogMelClip needle,
  LogMelClip haystack,
  int start,
  int width,
  double needleNorm, {
  required double threshold,
  required bool abort,
}) {
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
    if (abort && frame % 16 == 15 && energy > 0) {
      final remain = width - frame - 1;
      final optimistic = (dot + remain) / (needleNorm * math.sqrt(energy));
      if (optimistic < threshold) return 0;
    }
  }
  final denom = needleNorm * math.sqrt(energy);
  if (denom <= 1e-8) return 0;
  return dot / denom;
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

final List<int> _melStart = [
  for (final weights in _melFilters) _firstNonZero(weights),
];

final List<int> _melEnd = [
  for (final weights in _melFilters) _lastNonZero(weights),
];

int _firstNonZero(Float64List weights) {
  for (var i = 0; i < weights.length; i++) {
    if (weights[i] != 0) return i;
  }
  return 0;
}

int _lastNonZero(Float64List weights) {
  for (var i = weights.length - 1; i >= 0; i--) {
    if (weights[i] != 0) return i + 1;
  }
  return 0;
}

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
