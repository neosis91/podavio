import 'dart:math' as math;
import 'dart:typed_data';

import 'package:olaf_ffi/olaf_ffi.dart';
import 'package:podavio/data/olaf_ads.dart';

/// Deterministic synthetic landmarks: random background, a few ads shared
/// by several episodes at different offsets (with one-frame jitter), hashes
/// frequent enough to be dropped, and a small background vocabulary so that
/// unrelated hashes collide across episodes.
class SyntheticOlaf {
  SyntheticOlaf({
    required int seed,
    int episodes = 6,
    int durationMs = 20 * 60000,
    double perSecond = 4,
    int ads = 4,
    int templates = 6,
    int vocabulary = 1 << 18,
  }) {
    final random = math.Random(seed);
    final frames = durationMs ~/ olafStepMs;
    int bigHash() => (random.nextInt(1 << 30) << 4) | random.nextInt(16);

    final patterns = <List<OlafLandmark>>[];
    for (var a = 0; a < ads; a++) {
      final lengthFrames = (12000 + random.nextInt(40000)) ~/ olafStepMs;
      final count = (lengthFrames * olafStepMs / 1000 * perSecond).round();
      patterns.add(
        [
          for (var i = 0; i < count; i++)
            OlafLandmark(hash: bigHash(), t1: random.nextInt(lengthFrames)),
        ]..sort((x, y) => x.t1.compareTo(y.t1)),
      );
    }
    final frequent = [for (var i = 0; i < 3; i++) bigHash()];

    for (var e = 0; e < episodes; e++) {
      final marks = <OlafLandmark>[];
      final count = (durationMs / 1000 * perSecond).round();
      for (var i = 0; i < count; i++) {
        marks.add(
          OlafLandmark(
            hash: random.nextInt(vocabulary),
            t1: random.nextInt(frames),
          ),
        );
      }
      for (final hash in frequent) {
        final repeats = 6 + random.nextInt(10);
        for (var i = 0; i < repeats; i++) {
          marks.add(OlafLandmark(hash: hash, t1: random.nextInt(frames)));
        }
      }
      for (var a = 0; a < patterns.length; a++) {
        if (random.nextInt(3) == 0) continue;
        final offset = random.nextInt(frames - 8000);
        for (final mark in patterns[a]) {
          if (random.nextInt(10) == 0) continue;
          final jitter = random.nextInt(3) - 1;
          final t1 = math.max(0, offset + mark.t1 + jitter);
          marks.add(OlafLandmark(hash: mark.hash, t1: t1));
        }
      }
      marks.sort((x, y) => x.t1.compareTo(y.t1));
      episodePrints.add(encodeOlafAdPrints(marks));
    }

    for (var t = 0; t < templates; t++) {
      final source = patterns[t % patterns.length];
      final from = random.nextInt(source.length ~/ 3);
      final slice = source.sublist(from);
      final origin = slice.first.t1;
      templatePrints.add(
        encodeOlafAdPrints([
          for (final mark in slice)
            OlafLandmark(hash: mark.hash, t1: mark.t1 - origin),
        ]),
      );
      templateDurationMs.add((slice.last.t1 - origin) * olafStepMs);
    }
  }

  final List<Uint8List> episodePrints = [];
  final List<Uint8List> templatePrints = [];
  final List<int> templateDurationMs = [];

  int get landmarks =>
      episodePrints.fold(0, (sum, bytes) => sum + (bytes.length - 4) ~/ 12);
}
