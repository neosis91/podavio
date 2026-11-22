import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/log_mel.dart';
import 'package:podavio/data/segment_match.dart';
import 'package:podavio/data/speech_music.dart';

void main() {
  test('chunked fingerprint, resample and speech match the one-shot path', () {
    final samples = Int16List(chromaprintSampleRate * 3);
    for (var i = 0; i < samples.length; i++) {
      final t = i / chromaprintSampleRate;
      samples[i] = (math.sin(2 * math.pi * 220 * t) * 12000).round();
    }
    final file = File(
      '${Directory.systemTemp.path}/podavio-pcm-stream-test.pcm',
    );
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    final bytes = Uint8List(samples.length * 2);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < samples.length; i++) {
      view.setInt16(i * 2, samples[i], Endian.little);
    }
    file.writeAsBytesSync(bytes);

    final streamed = analyzePcmFileSync(file.path);
    expect(streamed.fingerprint, isEmpty);

    final resampler = LogMelResampler(
      maxSamples:
          (samples.length * logMelSampleRate) ~/ chromaprintSampleRate + 2,
    );
    const chunk = 1000;
    for (var offset = 0; offset < samples.length; offset += chunk) {
      final end = math.min(samples.length, offset + chunk);
      resampler.add(Int16List.sublistView(samples, offset, end));
    }
    final batched = resampleToLogMelRate(samples, chromaprintSampleRate);
    final streamedRate = resampler.output;
    expect(streamedRate.length, batched.length);
    for (var i = 0; i < batched.length; i++) {
      expect(streamedRate[i], closeTo(batched[i], 0.6));
    }

    final builder = SpeechTimelineBuilder();
    builder.add(Int16List.sublistView(samples, 0, 100));
    builder.add(Int16List.sublistView(samples, 100));
    expect(builder.finish(), speechMusicTimeline(samples));
    expect(streamed.speech, speechMusicTimeline(samples));
    expect(streamed.retainedBytes, lessThan(32 * 1024 * 1024));
  });

  test('a long silent episode does not keep the whole file in memory', () {
    const seconds = 20 * 60;
    final file = File(
      '${Directory.systemTemp.path}/podavio-pcm-long-silence.pcm',
    );
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    final chunk = Uint8List(chromaprintSampleRate * 2);
    final sink = file.openSync(mode: FileMode.write);
    for (var i = 0; i < seconds; i++) {
      sink.writeFromSync(chunk);
    }
    sink.closeSync();
    final length = file.lengthSync();
    final streamed = analyzePcmFileSync(file.path);
    // L’ancien chemin gardait le fichier et une copie Int16, soit 2× la taille.
    expect(length, greaterThan(20 * 1024 * 1024));
    expect(streamed.retainedBytes, lessThan(32 * 1024 * 1024));
    expect(streamed.retainedBytes * 2, lessThan(length));
    expect(streamed.elapsedMs, greaterThan(0));
  });
}
