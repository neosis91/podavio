import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/segment_finder.dart';
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
    expect(
      plan.patterns.single.segments.every(
        (segment) => segment.confirmed == false,
      ),
      isTrue,
    );
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
}) {
  final values = _noise(length, seed + id * 17);
  _write(values, at, motif);
  return FingerprintEpisode(
    episodeId: id,
    values: values,
    hopMicros: chromaprintStoredHopMicros,
    durationMs: durationMs,
  );
}
