import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/envelope.dart';
import 'package:podavio/data/segment_finder.dart';
import 'package:podavio/data/segment_match.dart';
import 'package:podavio/data/skip_segments.dart';

void main() {
  const hop = chromaprintStoredHopMicros;

  test('repeated segment at different offsets is an ad', () {
    final motif = _motif(100, 1);
    final episodes = [
      _episode(id: 1, length: 2000, seed: 11, at: 80, motif: motif),
      _episode(id: 2, length: 2000, seed: 22, at: 600, motif: motif),
      _episode(id: 3, length: 2000, seed: 33, at: 1200, motif: motif),
    ];
    final found = discoverPatterns(episodes);
    expect(found, hasLength(1));
    expect(found.single.classification.kind, SkipSegmentKind.ad);
    expect(found.single.classification.autoSkip, isTrue);
    expect(found.single.classification.confidence, crossEpisodeConfidence);
    expect(found.single.occurrences, hasLength(3));
    expect(found.single.durationMs, greaterThanOrEqualTo(10000));
    final starts = found.single.occurrences.map((hit) => hit.startMs).toList()
      ..sort();
    expect(starts[0], closeTo(_ms(80), 1500));
    expect(starts[1], closeTo(_ms(600), 1500));
    expect(starts[2], closeTo(_ms(1200), 1500));
  });

  test('a stable opening is an intro and a stable ending is an outro', () {
    final intro = _motif(100, 2);
    final opening = discoverPatterns([
      _episode(
        id: 1,
        length: 2000,
        seed: 1,
        at: 8,
        motif: intro,
        durationMs: 400000,
      ),
      _episode(
        id: 2,
        length: 2000,
        seed: 2,
        at: 8,
        motif: intro,
        durationMs: 400000,
      ),
    ]);
    expect(opening.single.classification.kind, SkipSegmentKind.intro);

    final outro = _motif(100, 3);
    final ending = discoverPatterns([
      _episode(
        id: 1,
        length: 800,
        seed: 4,
        at: 566,
        motif: outro,
        durationMs: 120000,
      ),
      _episode(
        id: 2,
        length: 800,
        seed: 5,
        at: 566,
        motif: outro,
        durationMs: 120000,
      ),
    ]);
    expect(ending.single.classification.kind, SkipSegmentKind.outro);

    final sponsor = _motif(100, 4);
    final middle = discoverPatterns([
      _episode(
        id: 1,
        length: 1900,
        seed: 6,
        at: 1616,
        motif: sponsor,
        durationMs: 400000,
      ),
      _episode(
        id: 2,
        length: 1900,
        seed: 7,
        at: 1616,
        motif: sponsor,
        durationMs: 400000,
      ),
    ]);
    expect(middle.single.classification.kind, SkipSegmentKind.sponsor);
  });

  test(
    'a short jingle is kept only when three episodes share its position',
    () {
      final jingle = _motif(30, 8);
      final kept = discoverPatterns([
        for (var id = 1; id <= 3; id++)
          _episode(id: id, length: 800, seed: id * 9, at: 220, motif: jingle),
      ]);
      expect(kept, hasLength(1));
      expect(kept.single.classification.kind, SkipSegmentKind.intro);
      expect(kept.single.durationMs, inInclusiveRange(3000, 9999));

      final shifted = discoverPatterns([
        _episode(id: 1, length: 1200, seed: 1, at: 20, motif: jingle),
        _episode(id: 2, length: 1200, seed: 2, at: 400, motif: jingle),
        _episode(id: 3, length: 1200, seed: 3, at: 900, motif: jingle),
      ]);
      expect(shifted, isEmpty);

      final pair = discoverPatterns([
        _episode(id: 1, length: 800, seed: 1, at: 220, motif: jingle),
        _episode(id: 2, length: 800, seed: 2, at: 220, motif: jingle),
      ]);
      expect(pair, isEmpty);
    },
  );

  test(
    'two missing points stay one range, three split it below 10 seconds',
    () {
      final motif = _motif(100, 9);
      final broken = List<int>.from(motif)
        ..[40] = 1
        ..[41] = 2;
      final joined = discoverPatterns([
        _episode(id: 1, length: 1500, seed: 1, at: 300, motif: motif),
        _episode(id: 2, length: 1500, seed: 2, at: 700, motif: broken),
      ]);
      expect(joined, hasLength(1));
      expect(joined.single.durationMs, greaterThanOrEqualTo(10000));

      final split = List<int>.from(motif)
        ..[40] = 1
        ..[41] = 2
        ..[42] = 3;
      final pieces = discoverPatterns([
        _episode(id: 1, length: 1500, seed: 3, at: 300, motif: motif),
        _episode(id: 2, length: 1500, seed: 4, at: 700, motif: split),
      ]);
      expect(pieces.where((pattern) => pattern.durationMs >= 10000), isEmpty);
    },
  );

  test('a repeat inside one episode is only a candidate past 20 seconds', () {
    final motif = _motif(100, 12);
    final values = _noise(1200, 3);
    _write(values, 30, motif);
    _write(values, 230, motif);
    final found = discoverPatterns([
      FingerprintEpisode(
        episodeId: 1,
        values: values,
        hopMicros: hop,
        durationMs: 400000,
      ),
    ]);
    expect(found, hasLength(1));
    expect(found.single.classification.autoSkip, isFalse);
    expect(found.single.classification.kind, isNull);
    expect(
      found.single.classification.confidence,
      lessThan(lowConfidenceCutoff),
    );
    expect(found.single.occurrences, hasLength(2));

    final close = _noise(800, 4);
    _write(close, 10, motif);
    _write(close, 50, motif);
    expect(
      discoverPatterns([
        FingerprintEpisode(
          episodeId: 1,
          values: close,
          hopMicros: hop,
          durationMs: 400000,
        ),
      ]),
      isEmpty,
    );
  });

  test('known templates are matched before a new pattern is created', () {
    final motif = _motif(100, 15);
    final episodes = [
      _episode(id: 1, length: 1500, seed: 1, at: 80, motif: motif),
      _episode(id: 2, length: 1500, seed: 2, at: 500, motif: motif),
    ];
    final plan = buildAnalysisPlan(
      episodes: episodes,
      templates: [
        KnownTemplate(
          id: 7,
          kind: SkipSegmentKind.sponsor,
          fingerprint: motif,
          durationMs: _ms(100),
          confirmed: false,
        ),
      ],
    );
    expect(plan.patterns, hasLength(1));
    expect(plan.patterns.single.templateId, 7);
    expect(plan.patterns.single.kind, SkipSegmentKind.sponsor);
    expect(plan.patterns.single.confirmed, isFalse);
    expect(plan.patterns.single.segments, hasLength(2));
    expect(plan.patterns.single.confidence, crossEpisodeConfidence);
    expect(
      plan.patterns.single.segments.every(
        (segment) => segment.confirmed == false,
      ),
      isTrue,
    );
  });

  test('music inside one episode is dropped, speech is only a candidate', () {
    final motif = _motif(100, 21);
    final musicValues = _placed(1200, 2, 40, motif);
    _write(musicValues, 400, motif);
    // Deux passages de musique, pas une période : le ratio suffit.
    expect(
      discoverPatterns([
        FingerprintEpisode(
          episodeId: 1,
          values: musicValues,
          hopMicros: hop,
          durationMs: 400000,
          speech: _level(60, 0),
        ),
      ]),
      isEmpty,
    );

    final spoken = FingerprintEpisode(
      episodeId: 4,
      values: _placed(1200, 3, 40, motif),
      hopMicros: hop,
      durationMs: 400000,
      speech: _level(60, 255),
    );
    final copy = FingerprintEpisode(
      episodeId: 4,
      values: List<int>.from(spoken.values),
      hopMicros: hop,
      durationMs: 400000,
      speech: _level(60, 255),
    );
    _write(copy.values, 400, motif);
    final kept = discoverPatterns([copy]);
    expect(kept, hasLength(1));
    expect(kept.single.classification.autoSkip, isFalse);
    expect(kept.single.classification.kind, isNull);
    expect(
      kept.single.classification.confidence,
      greaterThanOrEqualTo(lowConfidenceCutoff),
    );
    expect(
      kept.single.classification.confidence,
      lessThan(crossEpisodeConfidence),
    );

    // Refrain toutes les ~21 s, trois fois : rejeté même sans note de parole.
    final loop = _noise(1200, 8);
    _write(loop, 40, motif);
    _write(loop, 210, motif);
    _write(loop, 380, motif);
    expect(
      discoverPatterns([
        FingerprintEpisode(
          episodeId: 9,
          values: loop,
          hopMicros: hop,
          durationMs: 400000,
        ),
      ]),
      isEmpty,
    );
  });

  test('a musical intro shared by episodes is still skipped', () {
    final jingle = _motif(80, 30);
    final found = discoverPatterns([
      _episode(
        id: 1,
        length: 1600,
        seed: 1,
        at: 6,
        motif: jingle,
        speech: _level(30, 0),
      ),
      _episode(
        id: 2,
        length: 1600,
        seed: 2,
        at: 6,
        motif: jingle,
        speech: _level(30, 0),
      ),
      _episode(
        id: 3,
        length: 1600,
        seed: 3,
        at: 6,
        motif: jingle,
        speech: _level(30, 0),
      ),
    ]);
    expect(found, hasLength(1));
    expect(found.single.classification.kind, SkipSegmentKind.intro);
    expect(found.single.classification.autoSkip, isTrue);
    expect(found.single.classification.confidence, crossEpisodeConfidence);
  });

  test('a sparse bridge of one match in three is not an ad', () {
    final motif = _motif(120, 50);
    final noisy = List<int>.from(motif);
    for (var i = 0; i < noisy.length; i++) {
      if (i % 3 != 0) noisy[i] = motif[i] ^ 0x00FFFFFF;
    }
    expect(
      discoverPatterns([
        _episode(id: 1, length: 1500, seed: 1, at: 200, motif: motif),
        _episode(id: 2, length: 1500, seed: 2, at: 800, motif: noisy),
      ]),
      isEmpty,
    );
  });

  test('a dynamic ad stays an ad when the speech score is high', () {
    final ad = _motif(120, 44);
    final found = discoverPatterns([
      _episode(
        id: 1,
        length: 1800,
        seed: 1,
        at: 80,
        motif: ad,
        speech: _level(40, 255),
      ),
      _episode(
        id: 2,
        length: 1800,
        seed: 2,
        at: 700,
        motif: ad,
        speech: _level(40, 255),
      ),
    ]);
    expect(found.single.classification.kind, SkipSegmentKind.ad);
    expect(found.single.classification.autoSkip, isTrue);
  });

  test('split outro pieces join and run to the end of the file', () {
    const gap = 32;
    final first = _motif(40, 21);
    final second = _motif(50, 22);
    final third = _motif(40, 23);
    const start = 719;
    final secondAt = start + first.length + gap;
    final thirdAt = secondAt + second.length + gap;
    final endIndex = thirdAt + third.length;
    final durationMs = _ms(endIndex) + 4000;
    expect(durationMs - _ms(start), lessThanOrEqualTo(60000));

    FingerprintEpisode episode(int id) {
      final values = _noise(endIndex + 80, id * 19);
      _write(values, start, first);
      _write(values, secondAt, second);
      _write(values, thirdAt, third);
      return FingerprintEpisode(
        episodeId: id,
        values: values,
        hopMicros: hop,
        durationMs: durationMs,
      );
    }

    final found = discoverPatterns([episode(1), episode(2)]);
    final outros = found.where(
      (pattern) => pattern.classification.kind == SkipSegmentKind.outro,
    );
    expect(outros, hasLength(1));
    for (final hit in outros.single.occurrences) {
      expect((hit.startMs - _ms(start)).abs(), lessThanOrEqualTo(500));
      expect(hit.endMs, durationMs);
    }
  });

  test('an outro ends at each file, not at one shared clock time', () {
    final motif = _motif(100, 31);
    FingerprintEpisode build(int id, int durationMs) {
      final at =
          ((durationMs - 4000) * 1000) ~/ chromaprintStoredHopMicros -
          motif.length;
      final values = _noise(at + motif.length + 40, id);
      _write(values, at, motif);
      return FingerprintEpisode(
        episodeId: id,
        values: values,
        hopMicros: hop,
        durationMs: durationMs,
      );
    }

    const short = 200000;
    const long = 260000;
    final found = discoverPatterns([build(1, short), build(2, long)]);
    final outros = found.where(
      (pattern) => pattern.classification.kind == SkipSegmentKind.outro,
    );
    expect(outros, hasLength(1));
    final byId = {
      for (final hit in outros.single.occurrences) hit.episodeId: hit,
    };
    expect(byId[1]!.endMs, short);
    expect(byId[2]!.endMs, long);
    expect(short - byId[1]!.startMs, lessThanOrEqualTo(60000));
    expect(long - byId[2]!.startMs, lessThanOrEqualTo(60000));
    expect((byId[2]!.startMs - byId[1]!.startMs).abs(), greaterThan(30000));
  });
  test('an episode that matches a known template is not compared again', () {
    final known = _motif(100, 41);
    final other = _motif(100, 42);
    final first = _noise(2000, 5);
    final second = _noise(2000, 6);
    _write(first, 100, known);
    _write(second, 300, known);
    _write(first, 900, other);
    _write(second, 1300, other);
    FingerprintEpisode episode(int id, List<int> values) => FingerprintEpisode(
      episodeId: id,
      values: values,
      hopMicros: hop,
      durationMs: 400000,
    );
    final plan = buildAnalysisPlan(
      episodes: [episode(1, first), episode(2, second)],
      templates: [
        KnownTemplate(
          id: 7,
          kind: SkipSegmentKind.ad,
          fingerprint: known,
          durationMs: _ms(100),
          confirmed: null,
        ),
      ],
      focusEpisodeId: 2,
      contextLayer: false,
    );
    expect(plan.patterns, hasLength(1));
    expect(plan.patterns.single.templateId, 7);
  });

  test('a shared portion longer than two minutes is not compared', () {
    final long = _motif(1100, 43);
    final found = discoverPatterns([
      _episode(id: 1, length: 3000, seed: 1, at: 100, motif: long),
      _episode(id: 2, length: 3000, seed: 2, at: 600, motif: long),
    ]);
    expect(found, isEmpty);
  });

  test('envelopes that do not follow each other drop the chroma match', () {
    final motif = _motif(160, 44);
    FingerprintEpisode episode(int id, int at, Uint8List envelope) {
      final values = _noise(2000, id * 31);
      _write(values, at, motif);
      return FingerprintEpisode(
        episodeId: id,
        values: values,
        hopMicros: hop,
        durationMs: _ms(2000),
        envelope: envelope,
      );
    }

    Uint8List envelope(int seed) {
      final frames = _ms(2000) ~/ envelopeHopMs + 50;
      final out = Uint8List(frames);
      var state = seed;
      for (var i = 0; i < frames; i++) {
        state = (1664525 * state + 1013904223) & 0x7fffffff;
        out[i] = 20 + state % 200;
      }
      return out;
    }

    final a = envelope(1);
    final b = envelope(2);
    final shift = (_ms(700) - _ms(100)) ~/ envelopeHopMs;
    final copied = Uint8List.fromList(b);
    for (
      var i = _ms(100) ~/ envelopeHopMs;
      i < _ms(260) ~/ envelopeHopMs;
      i++
    ) {
      copied[i + shift] = a[i];
    }
    final unrelated = discoverPatterns([
      episode(1, 100, a),
      episode(2, 700, b),
    ]);
    expect(unrelated, isEmpty);
    final shared = discoverPatterns([
      episode(1, 100, a),
      episode(2, 700, copied),
    ]);
    expect(shared, hasLength(1));
    for (final hit in shared.single.occurrences) {
      final at = hit.episodeId == 1 ? _ms(100) : _ms(700);
      expect(hit.startMs, closeTo(at, 1500));
    }
  });

  test('an Olaf blob is not a Chromaprint print', () {
    final olaf = Uint8List.fromList([
      0x4F,
      0x6C,
      0x61,
      0x66,
      ...List.filled(48, 1),
    ]);
    expect(isChromaprintPrint(olaf), isFalse);
    expect(isChromaprintPrint(encodeFingerprint(_motif(16, 1))), isTrue);
    expect(isChromaprintPrint(Uint8List(0)), isFalse);
  });
}

int _ms(int index) => index * chromaprintStoredHopMicros ~/ 1000;

List<int> _motif(int length, int salt) {
  return [for (var i = 0; i < length; i++) 0xC0000000 + salt * 1000 + i];
}

List<int> _noise(int length, int seed) {
  var state = seed;
  return List<int>.generate(length, (_) {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    return state;
  });
}

void _write(List<int> values, int at, List<int> motif) {
  for (var i = 0; i < motif.length; i++) {
    values[at + i] = motif[i];
  }
}

FingerprintEpisode _episode({
  required int id,
  required int length,
  required int seed,
  required int at,
  required List<int> motif,
  int durationMs = 400000,
  Uint8List? speech,
}) {
  final values = _noise(length, seed + id * 17);
  _write(values, at, motif);
  return FingerprintEpisode(
    episodeId: id,
    values: values,
    hopMicros: chromaprintStoredHopMicros,
    durationMs: durationMs,
    speech: speech,
  );
}

Uint8List _level(int seconds, int value) {
  return Uint8List(seconds)..fillRange(0, seconds, value);
}

List<int> _placed(int length, int seed, int at, List<int> motif) {
  final values = _noise(length, seed);
  _write(values, at, motif);
  return values;
}
