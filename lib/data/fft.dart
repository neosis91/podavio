import 'dart:math' as math;
import 'dart:typed_data';

/// FFT directe (exposant négatif), mêmes conventions que le portage initial.
///
/// Les facteurs de rotation sont calculés une fois par taille. L’entrée
/// imaginaire nulle passe par [RealFft], environ deux fois moins de papillons.
void fftForward(Float64List re, Float64List im) {
  _plan(re.length).apply(re, im);
}

final _plans = <int, _FftPlan>{};

_FftPlan _plan(int n) => _plans[n] ??= _FftPlan(n);

class _FftPlan {
  _FftPlan(this.n)
    : bitrev = Int32List(n),
      twRe = Float64List(n ~/ 2),
      twIm = Float64List(n ~/ 2) {
    var j = 0;
    for (var i = 0; i < n; i++) {
      bitrev[i] = j;
      var bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
    }
    for (var t = 0; t < twRe.length; t++) {
      final theta = -2 * math.pi * t / n;
      twRe[t] = math.cos(theta);
      twIm[t] = math.sin(theta);
    }
  }

  final int n;
  final Int32List bitrev;
  final Float64List twRe;
  final Float64List twIm;

  void apply(Float64List re, Float64List im) {
    final n = this.n;
    final reverse = bitrev;
    for (var i = 0; i < n; i++) {
      final j = reverse[i];
      if (i < j) {
        final swapRe = re[i];
        re[i] = re[j];
        re[j] = swapRe;
        final swapIm = im[i];
        im[i] = im[j];
        im[j] = swapIm;
      }
    }
    final twiddleRe = twRe;
    final twiddleIm = twIm;
    for (var length = 2; length <= n; length <<= 1) {
      final half = length >> 1;
      final step = n ~/ length;
      for (var start = 0; start < n; start += length) {
        for (var k = 0; k < half; k++) {
          final t = k * step;
          final wr = twiddleRe[t];
          final wi = twiddleIm[t];
          final oddIndex = start + k + half;
          final oddRe = re[oddIndex];
          final oddIm = im[oddIndex];
          final mixedRe = wr * oddRe - wi * oddIm;
          final mixedIm = wr * oddIm + wi * oddRe;
          final evenIndex = start + k;
          final evenRe = re[evenIndex];
          final evenIm = im[evenIndex];
          re[evenIndex] = evenRe + mixedRe;
          im[evenIndex] = evenIm + mixedIm;
          re[oddIndex] = evenRe - mixedRe;
          im[oddIndex] = evenIm - mixedIm;
        }
      }
    }
  }
}

/// Spectre de puissance d’un signal réel, longueur puissance de 2.
///
/// [power] reçoit `|X[k]|²` pour `k = 0 .. n/2` si la liste est assez longue,
/// sinon seulement jusqu’à son dernier indice (Chromaprint s’arrête à `n/2`).
class RealFft {
  RealFft(int length)
    : n = length,
      half = length >> 1,
      _re = Float64List(length >> 1),
      _im = Float64List(length >> 1),
      _twRe = Float64List(length >> 1),
      _twIm = Float64List(length >> 1) {
    for (var k = 0; k < half; k++) {
      final theta = -2 * math.pi * k / n;
      _twRe[k] = math.cos(theta);
      _twIm[k] = math.sin(theta);
    }
  }

  final int n;
  final int half;
  final Float64List _re;
  final Float64List _im;
  final Float64List _twRe;
  final Float64List _twIm;

  void power(Float64List input, Float64List power) {
    final h = half;
    final re = _re;
    final im = _im;
    for (var i = 0; i < h; i++) {
      final even = i * 2;
      re[i] = input[even];
      im[i] = input[even + 1];
    }
    fftForward(re, im);
    _unpack(power);
  }

  /// Fenêtre appliquée à des échantillons 16 bits, sans tableau intermédiaire.
  void powerWindowedInt16(
    Int16List frame,
    Float64List window,
    Float64List power,
  ) {
    final h = half;
    final re = _re;
    final im = _im;
    for (var i = 0; i < h; i++) {
      final even = i * 2;
      final odd = even + 1;
      re[i] = frame[even] * window[even];
      im[i] = frame[odd] * window[odd];
    }
    fftForward(re, im);
    _unpack(power);
  }

  void _unpack(Float64List power) {
    final h = half;
    final re = _re;
    final im = _im;
    final zr0 = re[0];
    final zi0 = im[0];
    final dc = zr0 + zi0;
    power[0] = dc * dc;
    if (power.length > h) {
      final nyquist = zr0 - zi0;
      power[h] = nyquist * nyquist;
    }
    final limit = power.length < h ? power.length : h;
    final twRe = _twRe;
    final twIm = _twIm;
    for (var k = 1; k < limit; k++) {
      final zr = re[k];
      final zi = im[k];
      final mirror = h - k;
      final zr2 = re[mirror];
      final zi2 = im[mirror];
      final evenR = 0.5 * (zr + zr2);
      final evenI = 0.5 * (zi - zi2);
      final oddR = 0.5 * (zr - zr2);
      final oddI = 0.5 * (zi + zi2);
      final wr = twRe[k];
      final wi = twIm[k];
      final rotR = wr * oddI + wi * oddR;
      final rotI = -wr * oddR + wi * oddI;
      final xr = evenR + rotR;
      final xi = evenI + rotI;
      power[k] = xr * xr + xi * xi;
    }
  }
}
