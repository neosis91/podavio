import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/chromaprint.dart';

void main() {
  test('fingerprint is deterministic and follows the hop', () {
    final samples = _signal(chromaprintSampleRate * 4);
    final first = chromaprintFingerprint(samples);
    final second = chromaprintFingerprint(samples);
    expect(second, first);
    expect(first, isNotEmpty);
    expect(first.length, chromaprintExpectedLength(samples.length));
    expect(chromaprintStoredHopMicros, 123809);
    final other = _signal(chromaprintSampleRate * 4, base: 90);
    expect(chromaprintFingerprint(other), isNot(first));
  });

  test('fingerprint matches fpcalc on a synthetic signal', () async {
    final fpcalc = await Process.run('which', ['fpcalc']);
    if (fpcalc.exitCode != 0) return;
    final samples = _signal(chromaprintSampleRate * 8);
    final file = File('${Directory.systemTemp.path}/podavio-fpcalc.wav');
    await file.writeAsBytes(_wav(samples));
    addTearDown(() => file.exists().then((ok) => ok ? file.delete() : null));

    final ours = chromaprintFingerprint(samples);

    final raw = await Process.run(fpcalc.stdout.toString().trim(), [
      '-raw',
      '-algorithm',
      '2',
      file.path,
    ]);
    expect(raw.exitCode, 0, reason: raw.stderr.toString());
    final line = raw.stdout.toString().trim();
    final marker = 'FINGERPRINT=';
    final values = line
        .substring(line.indexOf(marker) + marker.length)
        .split(',')
        .map(int.parse)
        .toList();
    expect(ours.length, values.length);
    var mismatches = 0;
    for (var i = 0; i < ours.length; i++) {
      if (ours[i].toUnsigned(32) != values[i].toUnsigned(32)) mismatches++;
    }
    expect(mismatches, 0, reason: '$mismatches valeurs diffèrent de fpcalc');
    expect(ours.length, chromaprintExpectedLength(samples.length));
    expect(chromaprintStoredHopMicros, 123809);
  });
}

Int16List _signal(int count, {double base = 180}) {
  final out = Int16List(count);
  for (var i = 0; i < count; i++) {
    final t = i / chromaprintSampleRate;
    final sweep = base + 40 * math.sin(2 * math.pi * 0.7 * t);
    final sample =
        0.45 * math.sin(2 * math.pi * sweep * t) +
        0.2 * math.sin(2 * math.pi * (sweep * 1.5) * t) +
        0.1 * math.sin(2 * math.pi * 90 * t);
    out[i] = (sample * 32767).round().clamp(-32768, 32767);
  }
  return out;
}

Uint8List _wav(Int16List samples) {
  final dataBytes = samples.length * 2;
  final bytes = Uint8List(44 + dataBytes);
  final view = ByteData.sublistView(bytes);
  void str(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes[offset + i] = value.codeUnitAt(i);
    }
  }

  str(0, 'RIFF');
  view.setUint32(4, 36 + dataBytes, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, chromaprintSampleRate, Endian.little);
  view.setUint32(28, chromaprintSampleRate * 2, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  str(36, 'data');
  view.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return bytes;
}
