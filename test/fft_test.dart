import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/fft.dart';

void main() {
  test('real power matches a full complex FFT', () {
    final input = Float64List.fromList([
      0,
      1,
      -2,
      0.5,
      3,
      -1,
      0.25,
      4,
      -3,
      2,
      1,
      -4,
      0.5,
      2,
      -1,
      3,
    ]);
    final real = RealFft(input.length);
    final power = Float64List(input.length ~/ 2 + 1);
    real.power(input, power);

    final re = Float64List.fromList(input);
    final im = Float64List(input.length);
    fftForward(re, im);
    for (var k = 0; k < power.length; k++) {
      final expected = re[k] * re[k] + im[k] * im[k];
      expect(power[k], closeTo(expected, 1e-8 * (expected.abs() + 1)));
    }
  });

  test('forward FFT matches a direct DFT', () {
    const n = 16;
    final re = Float64List(n);
    final im = Float64List(n);
    for (var i = 0; i < n; i++) {
      re[i] = math.cos(2 * math.pi * 3 * i / n) + 0.25 * i;
    }
    final expectedRe = Float64List(n);
    final expectedIm = Float64List(n);
    for (var k = 0; k < n; k++) {
      var sumRe = 0.0;
      var sumIm = 0.0;
      for (var i = 0; i < n; i++) {
        final angle = -2 * math.pi * k * i / n;
        sumRe += re[i] * math.cos(angle);
        sumIm += re[i] * math.sin(angle);
      }
      expectedRe[k] = sumRe;
      expectedIm[k] = sumIm;
    }
    fftForward(re, im);
    for (var k = 0; k < n; k++) {
      expect(re[k], closeTo(expectedRe[k], 1e-8));
      expect(im[k], closeTo(expectedIm[k], 1e-8));
    }
  });
}
