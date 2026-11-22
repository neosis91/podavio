import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:olaf_ffi/olaf_ffi.dart';
import 'package:podavio/data/chromaprint.dart';
import 'package:podavio/data/envelope.dart';
import 'package:podavio/data/olaf_ads.dart';
import 'package:podavio/data/segment_finder.dart';
import 'package:podavio/data/segment_match.dart';
import 'package:podavio/data/skip_segments.dart';

void main() {
  test('shared landmarks become one ad, at different offsets', () {
    final plan = planOlafAds(
      episodes: [
        _episode(1, _span(8000, 20640)),
        _episode(2, _span(50000, 62640)),
      ],
      templates: const [],
    );
    expect(plan.patterns, hasLength(1));
    final pattern = plan.patterns.single;
    expect(pattern.kind, SkipSegmentKind.ad);
    expect(pattern.fingerprintBytes, isNotNull);
    expect(isOlafAdPrint(pattern.fingerprintBytes!), isTrue);
    expect(pattern.segments, hasLength(2));
    final byId = {
      for (final segment in pattern.segments) segment.episodeId: segment,
    };
    expect(byId[1]!.startMs, closeTo(8000, 40));
    expect(byId[2]!.startMs, closeTo(50000, 40));
    expect(byId[1]!.endMs - byId[1]!.startMs, inInclusiveRange(10000, 60000));
  });

  test('a match longer than a minute is capped at 60 s', () {
    final plan = planOlafAds(
      episodes: [
        _episode(1, _span(5000, 85000, hashes: 300)),
        _episode(2, _span(40000, 120000, hashes: 300)),
      ],
      templates: const [],
    );
    expect(plan.patterns, isNotEmpty);
    for (final pattern in plan.patterns) {
      expect(pattern.kind, isNot(SkipSegmentKind.outro));
      for (final segment in pattern.segments) {
        expect(
          segment.endMs - segment.startMs,
          lessThanOrEqualTo(olafAdMaxDurationMs),
        );
        expect(
          segment.endMs - segment.startMs,
          greaterThanOrEqualTo(adMinDurationMs),
        );
      }
    }
  });

  test('a sting shorter than 10 s is not an ad', () {
    final plan = planOlafAds(
      episodes: [
        _episode(1, _span(1000, 4500)),
        _episode(2, _span(8000, 11500)),
      ],
      templates: const [],
    );
    expect(plan.patterns, isEmpty);
  });

  test('a repeated ending in the last minute is an outro', () {
    final plan = planOlafAds(
      episodes: [
        _episode(1, _span(270000, 294648), durationMs: 300000),
        _episode(2, _span(300000, 324648), durationMs: 330000),
      ],
      templates: const [],
    );
    expect(plan.patterns, hasLength(1));
    expect(plan.patterns.single.kind, SkipSegmentKind.outro);
    final byId = {
      for (final segment in plan.patterns.single.segments)
        segment.episodeId: segment,
    };
    expect(byId[1]!.endMs, 300000);
    expect(byId[2]!.endMs, 330000);
  });

  test('unrelated episodes share no pattern', () {
    final plan = planOlafAds(
      episodes: [
        _episode(1, _span(0, 20000, salt: 1)),
        _episode(2, _span(0, 20000, salt: 2)),
      ],
      templates: const [],
    );
    expect(plan.patterns, isEmpty);
  });

  test('a known template is found in a later episode', () {
    final first = planOlafAds(
      episodes: [
        _episode(1, _span(10000, 22640)),
        _episode(2, _span(70000, 82640)),
      ],
      templates: const [],
    );
    final pattern = first.patterns.single;
    final again = planOlafAds(
      episodes: [
        _episode(1, _span(10000, 22640)),
        _episode(3, _span(120000, 132640)),
      ],
      templates: [
        OlafAdTemplate(
          id: 7,
          kind: SkipSegmentKind.sponsor,
          confirmed: false,
          durationMs: pattern.durationMs,
          prints: pattern.fingerprintBytes!,
          confidence: pattern.confidence,
        ),
      ],
    );
    final hit = again.patterns.single.segments.singleWhere(
      (segment) => segment.episodeId == 3,
    );
    expect(hit.kind, SkipSegmentKind.sponsor);
    expect(hit.confirmed, isFalse);
    expect(hit.startMs, closeTo(120000, 80));
  });

  test('silence snap moves the end onto the held silence', () {
    final silenceAt = 12000;
    final envelope = Uint8List(2000);
    for (var i = 0; i < silenceAt ~/ envelopeHopMs; i++) {
      envelope[i] = 40;
    }
    final plan = planOlafAds(
      episodes: [
        _episode(1, _span(0, 10112), envelope: envelope),
        _episode(2, _span(40000, 50112)),
      ],
      templates: const [],
    );
    final hit = plan.patterns.single.segments.singleWhere(
      (segment) => segment.episodeId == 1,
    );
    expect(hit.endMs, inInclusiveRange(11800, 12400));
  });

  test('the same ad still links a third episode through the first match', () {
    final plan = planOlafAds(
      episodes: [
        _episode(1, _span(0, 16000)),
        _episode(2, _span(30000, 46000)),
        _episode(3, _span(80000, 96000)),
      ],
      templates: const [],
    );
    final ids = {
      for (final pattern in plan.patterns)
        for (final segment in pattern.segments) segment.episodeId,
    };
    expect(ids, {1, 2, 3});
  });

  test('a second ad that only matches a later episode is left out', () {
    final plan = planOlafAds(
      episodes: [
        _episode(1, _marks([(0, 16000, 4), (80000, 96000, 9)])),
        _episode(2, _span(20000, 36000, salt: 4)),
        _episode(3, _span(40000, 56000, salt: 9)),
      ],
      templates: const [],
    );
    final ids = {
      for (final pattern in plan.patterns)
        for (final segment in pattern.segments) segment.episodeId,
    };
    expect(ids, {1, 2});
    expect(ids.contains(3), isFalse);
  });

  test(
    'a known sequence is not followed by a search of the other episodes',
    () {
      final known = planOlafAds(
        episodes: [
          _episode(1, _span(0, 16000, salt: 4)),
          _episode(2, _span(20000, 36000, salt: 4)),
        ],
        templates: const [],
      );
      final pattern = known.patterns.single;
      final again = planOlafAds(
        episodes: [
          _episode(1, _marks([(0, 16000, 4), (80000, 96000, 9)])),
          _episode(2, _span(20000, 36000, salt: 4)),
          _episode(3, _span(40000, 56000, salt: 9)),
        ],
        templates: [
          OlafAdTemplate(
            id: 4,
            kind: SkipSegmentKind.ad,
            confirmed: null,
            durationMs: pattern.durationMs,
            prints: pattern.fingerprintBytes!,
            confidence: pattern.confidence,
          ),
        ],
        focusEpisodeId: 1,
      );
      final ids = {
        for (final found in again.patterns)
          for (final segment in found.segments) segment.episodeId,
      };
      expect(ids.contains(3), isFalse);
      expect(
        again.patterns
            .expand((item) => item.segments)
            .any(
              (segment) => segment.episodeId == 1 && segment.startMs < 20000,
            ),
        isTrue,
      );
    },
  );

  test('Chromaprint bytes are not an Olaf ad print', () {
    expect(isOlafAdPrint(encodeFingerprint([1, 2, 3, 4])), isFalse);
    expect(isOlafAdPrint(encodeOlafAdPrints(const [])), isTrue);
  });

  test('real RTL episodes, Olaf against Chromaprint', () async {
    final dir = Platform.environment['OLAF_AD_PCM'];
    if (dir == null || dir.isEmpty) return;
    expect(await ensureOlafLibrary(), isTrue);
    const names = ['sample', 'palatine', 'hetre'];
    final rssBefore = ProcessInfo.currentRss;
    final fingerprints = <FingerprintEpisode>[];
    final olafEpisodes = <OlafAdEpisode>[];
    for (var i = 0; i < names.length; i++) {
      final path = '$dir/${names[i]}.pcm';
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      final denseWatch = Stopwatch()..start();
      final dense = fingerprintPcmFile(
        path,
        sampleRate: chromaprintSampleRate,
        maxMs: 60000,
      );
      denseWatch.stop();
      final adWatch = Stopwatch()..start();
      final ads = fingerprintPcmFile(
        path,
        sampleRate: chromaprintSampleRate,
        maxMs: 0,
        keepModulus: olafAdKeepModulus,
      );
      adWatch.stop();
      final fingerWatch = Stopwatch()..start();
      final values = _chromaprintFile(path);
      fingerWatch.stop();
      final length = file.lengthSync();
      final durationMs = length ~/ 2 * 1000 ~/ chromaprintSampleRate;
      final envelope = _envelopeFile(path);
      fingerprints.add(
        FingerprintEpisode(
          episodeId: i + 1,
          values: values,
          hopMicros: chromaprintStoredHopMicros,
          durationMs: durationMs,
          envelope: envelope,
        ),
      );
      olafEpisodes.add(
        OlafAdEpisode(
          episodeId: i + 1,
          prints: encodeOlafAdPrints(ads ?? const []),
          durationMs: durationMs,
          envelope: envelope,
        ),
      );
      // ignore: avoid_print
      print(
        'EP ${names[i]} dur=${durationMs}ms '
        'dense60=${dense?.length} in ${denseWatch.elapsedMilliseconds}ms '
        'olaf=${ads?.length} bytes=${ads == null ? 0 : encodeOlafAdPrints(ads).length} '
        'in ${adWatch.elapsedMilliseconds}ms '
        'chroma=${values.length} in ${fingerWatch.elapsedMilliseconds}ms',
      );
    }
    final rssAfter = ProcessInfo.currentRss;
    final chromaMatch = Stopwatch()..start();
    final chromaFound = discoverPatterns(fingerprints);
    chromaMatch.stop();
    final olafMatch = Stopwatch()..start();
    final olafFound = planOlafAds(episodes: olafEpisodes, templates: const []);
    olafMatch.stop();
    // ignore: avoid_print
    print(
      'MATCH chroma ${chromaMatch.elapsedMilliseconds}ms '
      'patterns=${chromaFound.length} '
      'olaf ${olafMatch.elapsedMilliseconds}ms '
      'patterns=${olafFound.patterns.length} '
      'rssDelta=${rssAfter - rssBefore}',
    );
    for (final pattern in chromaFound) {
      // ignore: avoid_print
      print(
        'CHROMA ${pattern.classification.kind} '
        '${[for (final hit in pattern.occurrences) '${hit.episodeId}:${hit.startMs}-${hit.endMs}'].join(' ')}',
      );
    }
    for (final pattern in olafFound.patterns) {
      // ignore: avoid_print
      print(
        'OLAF ${pattern.kind} '
        '${[for (final hit in pattern.segments) '${hit.episodeId}:${hit.startMs}-${hit.endMs}'].join(' ')}',
      );
    }
    expect(olafEpisodes, hasLength(names.length));
    expect(olafEpisodes.every((episode) => episode.prints.length > 4), isTrue);
  });
}

OlafAdEpisode _episode(
  int id,
  Uint8List prints, {
  int durationMs = 400000,
  Uint8List? envelope,
}) {
  return OlafAdEpisode(
    episodeId: id,
    prints: prints,
    durationMs: durationMs,
    envelope: envelope,
  );
}

Uint8List _marks(List<(int, int, int)> ranges, {int hashes = 80}) {
  final marks = <OlafLandmark>[];
  for (final range in ranges) {
    final start = range.$1 ~/ olafStepMs;
    final frames = (range.$2 - range.$1) ~/ olafStepMs;
    final step = frames ~/ (hashes - 1);
    for (var i = 0; i < hashes; i++) {
      marks.add(
        OlafLandmark(hash: range.$3 * 100000 + i, t1: start + i * step),
      );
    }
  }
  return encodeOlafAdPrints(marks);
}

Uint8List _span(int startMs, int endMs, {int salt = 7, int hashes = 80}) {
  final start = startMs ~/ olafStepMs;
  final frames = (endMs - startMs) ~/ olafStepMs;
  final step = frames ~/ (hashes - 1);
  return encodeOlafAdPrints([
    for (var i = 0; i < hashes; i++)
      OlafLandmark(hash: salt * 100000 + i, t1: start + i * step),
  ]);
}

List<int> _chromaprintFile(String path) {
  final hasher = ChromaprintHasher();
  final file = File(path).openSync();
  final raw = Uint8List(8192 * 2);
  final piece = Int16List(8192);
  try {
    while (true) {
      final read = file.readIntoSync(raw);
      if (read < 2) break;
      final samples = read ~/ 2;
      final view = ByteData.sublistView(raw, 0, samples * 2);
      for (var i = 0; i < samples; i++) {
        piece[i] = view.getInt16(i * 2, Endian.little);
      }
      hasher.add(
        samples == piece.length
            ? piece
            : Int16List.sublistView(piece, 0, samples),
      );
    }
  } finally {
    file.closeSync();
  }
  return hasher.finish();
}

Uint8List _envelopeFile(String path) {
  final builder = EnergyEnvelopeBuilder();
  final file = File(path).openSync();
  final raw = Uint8List(8192 * 2);
  final piece = Int16List(8192);
  try {
    while (true) {
      final read = file.readIntoSync(raw);
      if (read < 2) break;
      final samples = read ~/ 2;
      final view = ByteData.sublistView(raw, 0, samples * 2);
      for (var i = 0; i < samples; i++) {
        piece[i] = view.getInt16(i * 2, Endian.little);
      }
      builder.add(
        samples == piece.length
            ? piece
            : Int16List.sublistView(piece, 0, samples),
      );
    }
  } finally {
    file.closeSync();
  }
  return builder.finish();
}
