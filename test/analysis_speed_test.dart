import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/log_mel.dart';
import 'package:podavio/data/segment_finder.dart';
import 'package:podavio/data/segment_match.dart';

/// Mesure le pipeline sur de l’audio synthétique. Les durées sont
/// journalisées ; le test vérifie surtout que le résultat reste juste.
void main() {
  test('profiles decode-side analysis, matching and log-mel search', () {
    const seconds = 120;
    final samples = Int16List(chromaprintSampleRate * seconds);
    for (var i = 0; i < samples.length; i++) {
      final t = i / chromaprintSampleRate;
      final freq = 180 + 70 * math.sin(2 * math.pi * 0.7 * t);
      final sample =
          0.45 * math.sin(2 * math.pi * freq * t) +
          0.2 * math.sin(2 * math.pi * freq * 1.5 * t);
      samples[i] = (sample * 32767).round().clamp(-32768, 32767);
    }
    final file = File('${Directory.systemTemp.path}/podavio-pcm-bench.pcm');
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    final bytes = Uint8List(samples.length * 2);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < samples.length; i++) {
      view.setInt16(i * 2, samples[i], Endian.little);
    }
    file.writeAsBytesSync(bytes);

    final rssBefore = ProcessInfo.currentRss;
    final analyzed = analyzePcmFileSync(file.path);
    final rssAfter = ProcessInfo.currentRss;
    expect(analyzed.fingerprint, isEmpty);
    expect(analyzed.retainedBytes, lessThan(32 * 1024 * 1024));
    // ignore: avoid_print
    print(
      'BENCH pcm_${seconds}s total=${analyzed.elapsedMs} '
      'fingerprint=${analyzed.fingerprintMs} speech=${analyzed.speechMs} '
      'logmel=${analyzed.logMelMs} retained=${analyzed.retainedBytes} '
      'rssDelta=${rssAfter - rssBefore} peakRss=${analyzed.peakRss}',
    );

    final motif = List<int>.generate(100, (i) => 0xA0000000 + i * 17);
    final episodes = <FingerprintEpisode>[];
    for (var id = 0; id < 6; id++) {
      final values = _noise(20 * 60 * 8, 1000 + id);
      final at = 400 + id * 900;
      for (var i = 0; i < motif.length; i++) {
        values[at + i] = motif[i];
      }
      episodes.add(
        FingerprintEpisode(
          episodeId: id + 1,
          values: values,
          hopMicros: chromaprintStoredHopMicros,
          durationMs: 20 * 60 * 1000,
        ),
      );
    }
    final matchWatch = Stopwatch()..start();
    final found = discoverPatterns(episodes);
    matchWatch.stop();
    expect(found, isNotEmpty);
    // ignore: avoid_print
    print(
      'BENCH match_6x20min ms=${matchWatch.elapsedMilliseconds} '
      'patterns=${found.length}',
    );

    final denseMotif = List<int>.generate(80, (i) => 0xB0000000 + i);
    final dense = <FingerprintEpisode>[];
    for (var id = 0; id < 4; id++) {
      final values = List<int>.filled(30 * 60 * 8, 0);
      for (var at = 0; at + denseMotif.length < values.length; at += 200) {
        for (var i = 0; i < denseMotif.length; i++) {
          values[at + i] = denseMotif[i] + (at ~/ 200) * 131;
        }
      }
      // Même pub aux offsets 500, 2500 et 6000.
      for (final at in [500, 2500, 6000]) {
        for (var i = 0; i < denseMotif.length; i++) {
          values[at + i] = 0x71000000 + i;
        }
      }
      dense.add(
        FingerprintEpisode(
          episodeId: id + 1,
          values: values,
          hopMicros: chromaprintStoredHopMicros,
          durationMs: 30 * 60 * 1000,
        ),
      );
    }
    final denseWatch = Stopwatch()..start();
    final denseFound = discoverPatterns(dense);
    denseWatch.stop();
    expect(denseFound, isNotEmpty);
    // ignore: avoid_print
    print(
      'BENCH match_dense_4x30min ms=${denseWatch.elapsedMilliseconds} '
      'patterns=${denseFound.length}',
    );

    final chirp = _chirp(milliseconds: 2000);
    final bed = _chirp(milliseconds: 20000, f0: 900, f1: 300);
    final at = 8000 * logMelSampleRate ~/ 1000;
    for (var i = 0; i < chirp.length; i++) {
      bed[at + i] = chirp[i];
    }
    final needle = computeLogMel(chirp);
    final haystack = computeLogMel(bed);
    final searchWatch = Stopwatch()..start();
    var hits = 0;
    for (var i = 0; i < 8; i++) {
      hits += searchLogMel(needle, haystack, threshold: 0.5).length;
    }
    searchWatch.stop();
    expect(hits, greaterThan(0));
    // ignore: avoid_print
    print('BENCH logmel_search_8x20s ms=${searchWatch.elapsedMilliseconds}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

List<int> _noise(int length, int seed) {
  var state = seed;
  return List<int>.generate(length, (_) {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    return state == 0 ? 1 : state;
  });
}

Float64List _chirp({
  required int milliseconds,
  double f0 = 400,
  double f1 = 1800,
}) {
  final count = milliseconds * logMelSampleRate ~/ 1000;
  final out = Float64List(count);
  for (var i = 0; i < count; i++) {
    final t = i / logMelSampleRate;
    final f = f0 + (f1 - f0) * i / count;
    out[i] = 0.6 * 32767 * math.sin(2 * math.pi * f * t);
  }
  return out;
}
