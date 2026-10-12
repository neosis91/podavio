import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/core/cover_tone.dart';

void main() {
  test('the cover color keeps the artwork hue without turning black', () {
    const seed = Color(0xFF2E895D);
    final color = coverBackground(seed);
    final tone = HSLColor.fromColor(color);

    expect((tone.hue - HSLColor.fromColor(seed).hue).abs(), lessThan(1));
    expect(tone.lightness, greaterThan(0.4));
    expect(tone.lightness, lessThan(0.7));
    expect(tone.saturation, greaterThan(0.45));
    expect(tone.saturation, lessThan(0.85));
  });

  test('a gray artwork stays gray', () {
    final tone = HSLColor.fromColor(coverBackground(const Color(0xFF888888)));
    expect(tone.saturation, lessThan(0.12));
  });

  test('white and pale gray are left out of the cover color', () {
    expect(coverSampleCounts(Colors.white), isFalse);
    expect(coverSampleCounts(const Color(0xFFF3F3F3)), isFalse);
    expect(coverSampleCounts(const Color(0xFF2E895D)), isTrue);
    expect(coverSampleCounts(const Color(0xFFFFEB3B)), isTrue);
  });

  test('the player color fades out by the halfway mark', () {
    const seed = Color(0xFF2E895D);
    final gradient = coverPlayerGradient(coverBackground(seed));
    expect(gradient.colors, [
      gradient.colors.first,
      Colors.black,
      Colors.black,
    ]);
    expect(gradient.stops, [0, 0.5, 1]);
    expect(gradient.colors.first, isNot(Colors.black));
    expect(
      (HSLColor.fromColor(gradient.colors.first).hue -
              HSLColor.fromColor(seed).hue)
          .abs(),
      lessThan(1),
    );
  });

  test('ink stays readable on light and dark covers', () {
    expect(
      coverInk(const Color(0xFF163D28)).computeLuminance(),
      greaterThan(0.7),
    );
    expect(
      coverInk(const Color(0xFFE4EE8A)).computeLuminance(),
      lessThan(0.15),
    );
  });
}
