import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Chromaprint, algorithme 2 (celui de `fpcalc`).
///
/// Portage en Dart de l’algorithme publié par Lukáš Lalinský
/// (Chromaprint 1.5, licence MIT). Les coefficients sont ceux de
/// `FingerprinterConfigurationTest2`. Le PCM doit être mono, 16 bits,
/// à [chromaprintSampleRate].
const chromaprintSampleRate = 11025;

const chromaprintFrameSize = 4096;

/// Pas entre deux trames : `frameSize / 3` échantillons.
const chromaprintHopSamples = chromaprintFrameSize ~/ 3;

/// Écart stocké dans `episode_fingerprints.hop_micros`.
///
/// `1365 / 11025` s, soit environ 0,12381 s et 8,08 valeurs par seconde.
/// [chromaprintHopMicros] reste l’approximation 125000 µs du premier jet.
const chromaprintStoredHopMicros =
    chromaprintHopSamples * 1000000 ~/ chromaprintSampleRate;

const _overlap = chromaprintFrameSize - chromaprintHopSamples;
const _bands = 12;
const _minFreq = 28;
const _maxFreq = 3520;
const _filterCoefficients = <double>[0.25, 0.75, 1.0, 0.75, 0.25];
const _gray = <int>[0, 1, 3, 2];

/// Classifieur : type, bande de départ, hauteur, largeur, trois seuils.
const _classifiers = <_Classifier>[
  _Classifier(0, 4, 3, 15, 1.98215, 2.35817, 2.63523),
  _Classifier(4, 4, 6, 15, -1.03809, -0.651211, -0.282167),
  _Classifier(1, 0, 4, 16, -0.298702, 0.119262, 0.558497),
  _Classifier(3, 8, 2, 12, -0.105439, 0.0153946, 0.135898),
  _Classifier(3, 4, 4, 8, -0.142891, 0.0258736, 0.200632),
  _Classifier(4, 0, 3, 5, -0.826319, -0.590612, -0.368214),
  _Classifier(1, 2, 2, 9, -0.557409, -0.233035, 0.0534525),
  _Classifier(2, 7, 3, 4, -0.0646826, 0.00620476, 0.0784847),
  _Classifier(2, 6, 2, 16, -0.192387, -0.029699, 0.215855),
  _Classifier(2, 1, 3, 2, -0.0397818, -0.00568076, 0.0292026),
  _Classifier(5, 10, 1, 15, -0.53823, -0.369934, -0.190235),
  _Classifier(3, 6, 2, 10, -0.124877, 0.0296483, 0.139239),
  _Classifier(2, 1, 1, 14, -0.101475, 0.0225617, 0.231971),
  _Classifier(3, 5, 6, 4, -0.0799915, -0.00729616, 0.063262),
  _Classifier(1, 9, 2, 12, -0.272556, 0.019424, 0.302559),
  _Classifier(3, 4, 2, 14, -0.164292, -0.0321188, 0.0846339),
];

/// Lit un fichier PCM 16 bits little-endian et renvoie l’empreinte.
///
/// Fonction de premier niveau pour l’isolate : le chemin est le seul
/// argument, le fichier n’est pas chargé d’un bloc.
List<int> fingerprintPcmFileSync(String path) {
  final bytes = File(path).readAsBytesSync();
  final view = ByteData.sublistView(bytes);
  final count = bytes.lengthInBytes ~/ 2;
  final hasher = ChromaprintHasher();
  const chunk = 16384;
  final piece = Int16List(chunk);
  var offset = 0;
  while (offset < count) {
    final take = math.min(chunk, count - offset);
    for (var i = 0; i < take; i++) {
      piece[i] = view.getInt16((offset + i) * 2, Endian.little);
    }
    if (take == chunk) {
      hasher.add(piece);
    } else {
      hasher.add(Int16List.sublistView(piece, 0, take));
    }
    offset += take;
  }
  return hasher.finish();
}

/// Empreinte brute (uint32), la même suite que `fpcalc -raw` pour ce PCM.
List<int> chromaprintFingerprint(Int16List samples) {
  final hasher = ChromaprintHasher();
  hasher.add(samples);
  return hasher.finish();
}

/// Nombre de trames FFT complètes dans [sampleCount] échantillons.
int chromaprintFrameCount(int sampleCount) {
  if (sampleCount < chromaprintFrameSize) return 0;
  return ((sampleCount - chromaprintFrameSize) ~/ chromaprintHopSamples) + 1;
}

/// Nombre de valeurs d’empreinte pour [sampleCount] échantillons.
///
/// Le filtre chroma (5) et la largeur max des classifieurs (16) mangent
/// 19 trames avant la première valeur.
int chromaprintExpectedLength(int sampleCount) {
  final frames = chromaprintFrameCount(sampleCount);
  if (frames < 19) return 0;
  return frames - 19;
}

/// Calcule l’empreinte par morceaux, sans garder tout le fichier.
class ChromaprintHasher {
  ChromaprintHasher() {
    _notes = _noteTable();
    _window = _hammingWindow();
  }

  final _pending = Int16List(chromaprintFrameSize);
  var _pendingCount = 0;
  final _fingerprint = <int>[];

  late final List<int> _notes;
  late final Float64List _window;
  final _chromaBuffer = List<Float64List>.generate(
    8,
    (_) => Float64List(_bands),
  );
  var _chromaOffset = 0;
  var _chromaSize = 1;
  final _integral = <Float64List>[];
  final _power = Float64List(chromaprintFrameSize ~/ 2);
  final _re = Float64List(chromaprintFrameSize);
  final _im = Float64List(chromaprintFrameSize);
  final _features = Float64List(_bands);
  final _filtered = Float64List(_bands);

  void add(Int16List samples) {
    var offset = 0;
    while (offset < samples.length) {
      final need = chromaprintFrameSize - _pendingCount;
      final take = math.min(need, samples.length - offset);
      _pending.setRange(_pendingCount, _pendingCount + take, samples, offset);
      _pendingCount += take;
      offset += take;
      if (_pendingCount == chromaprintFrameSize) {
        _consumeFrame(_pending);
        _pending.setRange(0, _overlap, _pending, chromaprintHopSamples);
        _pendingCount = _overlap;
      }
    }
  }

  List<int> finish() => List<int>.unmodifiable(_fingerprint);

  void _consumeFrame(Int16List frame) {
    for (var i = 0; i < chromaprintFrameSize; i++) {
      _re[i] = frame[i] * _window[i];
      _im[i] = 0;
    }
    _fft(_re, _im);
    _power[0] = _re[0] * _re[0];
    final nyquist = chromaprintFrameSize ~/ 2;
    for (var k = 1; k < nyquist; k++) {
      final real = _re[k];
      final imag = _im[k];
      _power[k] = real * real + imag * imag;
    }
    for (var band = 0; band < _bands; band++) {
      _features[band] = 0;
    }
    for (var bin = 0; bin < _notes.length; bin++) {
      final note = _notes[bin];
      if (note < 0) continue;
      _features[note] += _power[bin];
    }
    _pushChroma(_features);
  }

  void _pushChroma(Float64List features) {
    _chromaBuffer[_chromaOffset].setAll(0, features);
    _chromaOffset = (_chromaOffset + 1) % 8;
    if (_chromaSize < _filterCoefficients.length) {
      _chromaSize++;
      return;
    }
    final start = (_chromaOffset + 8 - _filterCoefficients.length) % 8;
    for (var band = 0; band < _bands; band++) {
      var sum = 0.0;
      for (var tap = 0; tap < _filterCoefficients.length; tap++) {
        sum +=
            _chromaBuffer[(start + tap) % 8][band] * _filterCoefficients[tap];
      }
      _filtered[band] = sum;
    }
    var squares = 0.0;
    for (var band = 0; band < _bands; band++) {
      squares += _filtered[band] * _filtered[band];
    }
    final norm = squares > 0 ? math.sqrt(squares) : 0.0;
    if (norm < 0.01) {
      for (var band = 0; band < _bands; band++) {
        _filtered[band] = 0;
      }
    } else {
      for (var band = 0; band < _bands; band++) {
        _filtered[band] /= norm;
      }
    }
    _addIntegral(_filtered);
    if (_integral.length >= 16) {
      _fingerprint.add(_subfingerprint(_integral.length - 16));
    }
  }

  void _addIntegral(Float64List features) {
    final row = Float64List(_bands);
    var sum = 0.0;
    for (var band = 0; band < _bands; band++) {
      sum += features[band];
      row[band] = sum;
    }
    if (_integral.isNotEmpty) {
      final previous = _integral.last;
      for (var band = 0; band < _bands; band++) {
        row[band] += previous[band];
      }
    }
    _integral.add(row);
  }

  int _subfingerprint(int offset) {
    var bits = 0;
    for (final classifier in _classifiers) {
      final value = _applyFilter(classifier, offset);
      bits = (bits << 2) | _gray[_quantize(value, classifier)];
    }
    return bits.toUnsigned(32);
  }

  double _applyFilter(_Classifier classifier, int x) {
    final y = classifier.y;
    final width = classifier.width;
    final height = classifier.height;
    switch (classifier.type) {
      case 0:
        return _subtractLog(_area(x, y, x + width, y + height), 0);
      case 1:
        final half = height ~/ 2;
        return _subtractLog(
          _area(x, y + half, x + width, y + height),
          _area(x, y, x + width, y + half),
        );
      case 2:
        final half = width ~/ 2;
        return _subtractLog(
          _area(x + half, y, x + width, y + height),
          _area(x, y, x + half, y + height),
        );
      case 3:
        final halfW = width ~/ 2;
        final halfH = height ~/ 2;
        final a =
            _area(x, y + halfH, x + halfW, y + height) +
            _area(x + halfW, y, x + width, y + halfH);
        final b =
            _area(x, y, x + halfW, y + halfH) +
            _area(x + halfW, y + halfH, x + width, y + height);
        return _subtractLog(a, b);
      case 4:
        final third = height ~/ 3;
        return _subtractLog(
          _area(x, y + third, x + width, y + 2 * third),
          _area(x, y, x + width, y + third) +
              _area(x, y + 2 * third, x + width, y + height),
        );
      case 5:
        final third = width ~/ 3;
        return _subtractLog(
          _area(x + third, y, x + 2 * third, y + height),
          _area(x, y, x + third, y + height) +
              _area(x + 2 * third, y, x + width, y + height),
        );
      default:
        return 0;
    }
  }

  double _area(int r1, int c1, int r2, int c2) {
    if (r1 == r2 || c1 == c2) return 0;
    if (r1 == 0) {
      final row = _integral[r2 - 1];
      if (c1 == 0) return row[c2 - 1];
      return row[c2 - 1] - row[c1 - 1];
    }
    final top = _integral[r1 - 1];
    final bottom = _integral[r2 - 1];
    if (c1 == 0) return bottom[c2 - 1] - top[c2 - 1];
    return bottom[c2 - 1] - top[c2 - 1] - bottom[c1 - 1] + top[c1 - 1];
  }
}

class _Classifier {
  const _Classifier(
    this.type,
    this.y,
    this.height,
    this.width,
    this.t0,
    this.t1,
    this.t2,
  );

  final int type;
  final int y;
  final int height;
  final int width;
  final double t0;
  final double t1;
  final double t2;
}

int _quantize(double value, _Classifier classifier) {
  if (value < classifier.t1) {
    if (value < classifier.t0) return 0;
    return 1;
  }
  if (value < classifier.t2) return 2;
  return 3;
}

double _subtractLog(double a, double b) {
  return math.log((1.0 + a) / (1.0 + b));
}

Float64List _hammingWindow() {
  final window = Float64List(chromaprintFrameSize);
  final scale = 1.0 / 32767.0;
  final last = chromaprintFrameSize - 1;
  for (var i = 0; i < chromaprintFrameSize; i++) {
    window[i] = scale * (0.54 - 0.46 * math.cos(i * 2.0 * math.pi / last));
  }
  return window;
}

List<int> _noteTable() {
  final notes = List<int>.filled(chromaprintFrameSize ~/ 2, -1);
  final minIndex = math.max(1, _freqToIndex(_minFreq.toDouble()));
  final maxIndex = math.min(
    chromaprintFrameSize ~/ 2,
    _freqToIndex(_maxFreq.toDouble()),
  );
  const base = 440.0 / 16.0;
  for (var bin = minIndex; bin < maxIndex; bin++) {
    final freq = bin * chromaprintSampleRate / chromaprintFrameSize;
    final octave = math.log(freq / base) / math.ln2;
    final note = _bands * (octave - octave.floor());
    var index = note.floor();
    if (index >= _bands) index = _bands - 1;
    if (index < 0) index = 0;
    notes[bin] = index;
  }
  return notes;
}

int _freqToIndex(double freq) {
  return (chromaprintFrameSize * freq / chromaprintSampleRate).round();
}

/// FFT radix-2 sur place. [re] et [im] ont la même longueur, puissance de 2.
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
    final theta = -2.0 * math.pi / length;
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
