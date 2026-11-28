import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/ad_context.dart';
import 'package:podavio/data/envelope.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/segment_finder.dart';

void main() {
  test('a flat 15 s tone is kept without context and rejected with it', () {
    final episodes = [
      _episode(
        1,
        _span(0, 15000),
        envelope: _flat(40000, 80),
        speech: _speech(40, 15),
      ),
      _episode(
        2,
        _span(30000, 45000),
        envelope: _flat(40000, 80),
        speech: _speech(40, 15),
      ),
    ];
    final off = buildAnalysisPlan(
      episodes: episodes,
      templates: const [],
      contextLayer: false,
    );
    final on = buildAnalysisPlan(episodes: episodes, templates: const []);
    expect(off.patterns, isNotEmpty);
    expect(on.patterns, isEmpty);
  });

  test('context proposes a single-episode ad and stays quiet without it', () {
    final ad = _inserted(startMs: 8000, lengthMs: 20000);
    final episodes = [
      _episode(1, _span(8400, 28000), envelope: ad.envelope, speech: ad.speech),
      _episode(
        2,
        _span(0, 20000, salt: 3),
        envelope: _varying(20000),
        speech: _speech(20, 230),
      ),
    ];
    final off = buildAnalysisPlan(
      episodes: episodes,
      templates: const [],
      contextLayer: false,
    );
    final on = buildAnalysisPlan(episodes: episodes, templates: const []);
    expect(off.patterns, isEmpty);
    expect(on.patterns, hasLength(1));
    final segment = on.patterns.single.segments.single;
    expect(segment.episodeId, 1);
    expect(segment.endMs - segment.startMs, inInclusiveRange(15000, 25000));
  });

  test('a 70 s read is kept whole, and context keeps it under 120 s', () {
    final ad = _inserted(startMs: 9000, lengthMs: 70000, totalMs: 100000);
    final episodes = [
      _episode(
        1,
        _span(10000, 80000),
        durationMs: 100000,
        envelope: ad.envelope,
        speech: ad.speech,
      ),
      _episode(
        2,
        _span(20000, 90000),
        durationMs: 110000,
        envelope: _shift(ad.envelope, 10000),
        speech: ad.speech,
      ),
    ];
    final off = buildAnalysisPlan(
      episodes: episodes,
      templates: const [],
      contextLayer: false,
    );
    final on = buildAnalysisPlan(episodes: episodes, templates: const []);
    expect(off.patterns, isNotEmpty);
    final lengths = [
      for (final segment in on.patterns.expand((item) => item.segments))
        segment.endMs - segment.startMs,
    ];
    expect(lengths.any((length) => length >= 65000), isTrue);
    expect(lengths.every((length) => length <= adContextMaxDurationMs), isTrue);
  });

  test('ordinary programme and an unlabeled stretch are not proposed', () {
    final fusion = fuseAdContext(
      matches: const [],
      episodes: {
        1: AdContextEpisode(
          durationMs: 30000,
          envelope: _varying(30000),
          speech: _speech(30, 230),
        ),
      },
    );
    expect(fusion.proposed, isEmpty);
  });

  test('a chapter title lifts a quiet level change over the threshold', () {
    final built = _levelChange(startMs: 300000, lengthMs: 20000);
    final plain = AdContextEpisode(
      durationMs: 1200000,
      envelope: built.envelope,
      speech: _speech(1200, 230),
    );
    final labeled = AdContextEpisode(
      durationMs: 1200000,
      envelope: built.envelope,
      speech: _speech(1200, 230),
      chapters: [
        AdContextChapter(
          startMs: built.startMs,
          endMs: built.endMs,
          title: 'Publicité',
        ),
      ],
    );
    expect(
      fuseAdContext(matches: const [], episodes: {1: plain}).proposed,
      isEmpty,
    );
    final hit = fuseAdContext(
      matches: const [],
      episodes: {1: labeled},
    ).proposed.single;
    expect(
      hit.startMs,
      inInclusiveRange(built.startMs - 500, built.startMs + 500),
    );
  });

  test('mn04 labels are ignored unless the flag is on', () {
    final built = _levelChange(startMs: 300000, lengthMs: 20000);
    final episode = AdContextEpisode(
      durationMs: 1200000,
      envelope: built.envelope,
      speech: _speech(1200, 180),
    );
    final cue = Mn04Cue(
      episodeId: 1,
      startMs: built.startMs,
      endMs: built.endMs,
      speech: 0.7,
      music: 0.4,
      jingle: 0.05,
      backgroundMusic: 0.55,
      scoreJump: 0.4,
    );
    final off = fuseAdContext(
      matches: const [],
      episodes: {1: episode},
      mn04: [cue],
    );
    final on = fuseAdContext(
      matches: const [],
      episodes: {1: episode},
      useMn04: true,
      mn04: [cue],
    );
    expect(off.proposed, isEmpty);
    expect(on.proposed, hasLength(1));
  });
}

FingerprintEpisode _episode(
  int id,
  ({int startMs, int endMs, int salt}) span, {
  int durationMs = 400000,
  Uint8List? envelope,
  Uint8List? speech,
}) {
  final hop = chromaprintStoredHopMicros / 1000;
  final values = List<int>.generate(
    (durationMs / hop).floor(),
    (index) => (id * 7919 + index * 104729) & 0x7fffffff,
  );
  final from = (span.startMs / hop).ceil();
  final to = math.min(values.length, (span.endMs / hop).floor());
  for (var i = from; i < to; i++) {
    values[i] = span.salt * 100000 + i - from;
  }
  return FingerprintEpisode(
    episodeId: id,
    values: values,
    hopMicros: chromaprintStoredHopMicros,
    durationMs: durationMs,
    envelope: envelope,
    speech: speech,
  );
}

({int startMs, int endMs, int salt}) _span(
  int startMs,
  int endMs, {
  int salt = 7,
}) => (startMs: startMs, endMs: endMs, salt: salt);

Uint8List _flat(int ms, int level) {
  return Uint8List(ms ~/ envelopeHopMs)
    ..fillRange(0, ms ~/ envelopeHopMs, level);
}

Uint8List _speech(int seconds, int level) =>
    Uint8List(seconds)..fillRange(0, seconds, level);

Uint8List _varying(int ms) {
  final out = Uint8List(ms ~/ envelopeHopMs);
  for (var i = 0; i < out.length; i++) {
    out[i] = (i ~/ 100).isEven ? 15 : 80;
  }
  return out;
}

({Uint8List envelope, Uint8List speech, int startMs, int endMs}) _inserted({
  required int startMs,
  required int lengthMs,
  int totalMs = 50000,
}) {
  final out = _varying(totalMs);
  final open = startMs ~/ envelopeHopMs;
  final close = (startMs + lengthMs) ~/ envelopeHopMs;
  final gap = 400 ~/ envelopeHopMs;
  for (var i = open - gap; i < open; i++) {
    if (i >= 0 && i < out.length) out[i] = 0;
  }
  for (var i = open; i < close && i < out.length; i++) {
    out[i] = 140 + ((i - open) * 37 + (i - open) ~/ 7 * 11) % 100;
  }
  for (var i = close; i < close + gap && i < out.length; i++) {
    out[i] = 0;
  }
  final speech = _speech(totalMs ~/ 1000, 230);
  final from = startMs ~/ 1000;
  final to = (startMs + lengthMs) ~/ 1000;
  for (var i = from; i < to && i < speech.length; i++) {
    speech[i] = 180;
  }
  return (
    envelope: out,
    speech: speech,
    startMs: startMs,
    endMs: startMs + lengthMs,
  );
}

({Uint8List envelope, int startMs, int endMs}) _levelChange({
  required int startMs,
  required int lengthMs,
}) {
  final total = startMs + lengthMs + 8000;
  final out = _flat(total, 40);
  final open = startMs ~/ envelopeHopMs;
  final close = (startMs + lengthMs) ~/ envelopeHopMs;
  final gap = 400 ~/ envelopeHopMs;
  for (var i = open - gap; i < open; i++) {
    out[i] = 0;
  }
  for (var i = open; i < close; i++) {
    out[i] = 200;
  }
  for (var i = close; i < close + gap && i < out.length; i++) {
    out[i] = 0;
  }
  return (envelope: out, startMs: startMs, endMs: startMs + lengthMs);
}

Uint8List _shift(Uint8List source, int ms) {
  final hops = ms ~/ envelopeHopMs;
  final out = Uint8List(source.length + hops);
  out.setRange(hops, hops + source.length, source);
  for (var i = 0; i < hops && i < out.length; i++) {
    out[i] = (i ~/ 100).isEven ? 15 : 80;
  }
  return out;
}
