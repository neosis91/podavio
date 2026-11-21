import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/envelope.dart';
import 'package:podavio/data/log_mel.dart';
import 'package:podavio/data/log_mel_match.dart';
import 'package:podavio/data/segment_finder.dart';
import 'package:podavio/data/segment_match.dart';

void main() {
  test('envelope snap lands within 40 ms of the shared ad', () {
    const trueStart = 5000;
    const trueEnd = 17000;
    const lead = 800;
    const otherAt = 20000;
    final shift = envelopeEdgeShift(
      anchor: _envelope(outside: 12, adStart: trueStart, adEnd: trueEnd),
      other: _envelope(
        outside: 220,
        adStart: otherAt,
        adEnd: otherAt + (trueEnd - trueStart),
      ),
      anchorStartMs: trueStart - lead,
      anchorEndMs: trueEnd + lead,
      otherStartMs: otherAt - lead,
      otherEndMs: otherAt + (trueEnd - trueStart) + lead,
    );
    expect(shift, isNotNull);
    expect(
      ((trueStart - lead) + shift!.startMs - trueStart).abs(),
      lessThanOrEqualTo(40),
    );
    expect(
      ((trueEnd + lead) + shift.endMs - trueEnd).abs(),
      lessThanOrEqualTo(40),
    );
  });

  test('a hash run that starts early is pulled back by the envelope', () {
    const at = 80;
    final motif = _motif(100, 9);
    final bleed = _motif(8, 3);
    final found = discoverPatterns([
      _withBleed(id: 1, seed: 1, at: at, motif: motif, bleed: bleed),
      _withBleed(id: 2, seed: 2, at: at + 400, motif: motif, bleed: bleed),
    ]);
    expect(found, hasLength(1));
    final starts = found.single.occurrences.map((hit) => hit.startMs).toList()
      ..sort();
    expect((starts[0] - _ms(at)).abs(), lessThanOrEqualTo(40));
    expect((starts[1] - _ms(at + 400)).abs(), lessThanOrEqualTo(40));
    final ends = found.single.occurrences.map((hit) => hit.endMs).toList()
      ..sort();
    expect((ends[0] - _ms(at + motif.length)).abs(), lessThanOrEqualTo(80));
    expect(
      (ends[1] - _ms(at + 400 + motif.length)).abs(),
      lessThanOrEqualTo(80),
    );
  });

  test('log-mel edges snap a wide window onto the chirp', () {
    final chirp = _chirp(milliseconds: 4000, f0: 320, f1: 1600);
    const atA = 5000;
    const atB = 12000;
    final left = computeLogMel(_bed(chirp, atMs: atA, tone: 180));
    final right = computeLogMel(_bed(chirp, atMs: atB, tone: 420));
    final refined = refinePairedLogMelEdges(
      left: left,
      leftStartMs: atA - 600,
      leftEndMs: atA + 4000 + 600,
      right: right,
      rightStartMs: atB - 600,
      rightEndMs: atB + 4000 + 600,
    );
    expect(refined, isNotNull);
    expect((refined!.startMs - atA).abs(), lessThanOrEqualTo(40));
    expect((refined.endMs - (atA + 4000)).abs(), lessThanOrEqualTo(80));
    expect(refined.score, greaterThanOrEqualTo(logMelMatchThreshold));
  });
}

Uint8List _envelope({
  required int outside,
  required int adStart,
  required int adEnd,
  int totalMs = 250000,
}) {
  final count = totalMs ~/ envelopeHopMs;
  final out = Uint8List(count);
  for (var i = 0; i < count; i++) {
    final ms = i * envelopeHopMs;
    if (ms < adStart || ms >= adEnd) {
      out[i] = outside;
    } else {
      out[i] = 40 + ((ms - adStart) ~/ envelopeHopMs) % 50;
    }
  }
  return out;
}

int _ms(int index) => index * chromaprintStoredHopMicros ~/ 1000;

List<int> _motif(int length, int salt) {
  return [for (var i = 0; i < length; i++) 0xC0000000 + salt * 1000 + i];
}

FingerprintEpisode _withBleed({
  required int id,
  required int seed,
  required int at,
  required List<int> motif,
  required List<int> bleed,
}) {
  var state = seed;
  final values = List<int>.generate(1600, (_) {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    return state == 0 ? 1 : state;
  });
  for (var i = 0; i < bleed.length; i++) {
    values[at - bleed.length + i] = bleed[i];
  }
  for (var i = 0; i < motif.length; i++) {
    values[at + i] = motif[i];
  }
  final start = _ms(at);
  final end = _ms(at + motif.length);
  return FingerprintEpisode(
    episodeId: id,
    values: values,
    hopMicros: chromaprintStoredHopMicros,
    durationMs: 400000,
    envelope: _envelope(outside: 20 + id * 80, adStart: start, adEnd: end),
  );
}

Float64List _bed(Float64List chirp, {required int atMs, required double tone}) {
  const totalMs = 20000;
  final count = totalMs * logMelSampleRate ~/ 1000;
  final out = Float64List(count);
  for (var i = 0; i < count; i++) {
    final t = i / logMelSampleRate;
    out[i] = 0.25 * 32767 * math.sin(2 * math.pi * tone * t);
  }
  final at = atMs * logMelSampleRate ~/ 1000;
  for (var i = 0; i < chirp.length && at + i < out.length; i++) {
    out[at + i] = chirp[i];
  }
  return out;
}

Float64List _chirp({
  required int milliseconds,
  required double f0,
  required double f1,
}) {
  final count = milliseconds * logMelSampleRate ~/ 1000;
  final out = Float64List(count);
  for (var i = 0; i < count; i++) {
    final t = i / logMelSampleRate;
    final f = f0 + (f1 - f0) * i / count;
    out[i] = 0.7 * 32767 * math.sin(2 * math.pi * f * t);
  }
  return out;
}
