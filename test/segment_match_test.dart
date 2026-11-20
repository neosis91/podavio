import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/segment_match.dart';
import 'package:podavio/data/skip_segments.dart';

void main() {
  test('chromaprint matches within 6 bits and tolerates a gap of 2', () {
    expect(chromaprintValuesMatch(0, 0), isTrue);
    expect(chromaprintValuesMatch(0, 0x3F), isTrue);
    expect(hammingDistance32(0, 0x3F), 6);
    expect(chromaprintValuesMatch(0, 0x7F), isFalse);

    expect(fingerprintOffsetsContinue(10, 11), isTrue);
    expect(fingerprintOffsetsContinue(10, 13), isTrue);
    expect(fingerprintOffsetsContinue(10, 14), isFalse);
    expect(fingerprintOffsetsContinue(10, 10), isFalse);
  });

  test('ads need 10 seconds, log-mel takes over under 3 seconds', () {
    expect(adDurationQualifies(29000), isTrue);
    expect(adDurationQualifies(10000), isTrue);
    expect(adDurationQualifies(9000), isFalse);

    expect(logMelScoreMatches(0.96), isTrue);
    expect(logMelScoreMatches(0.97), isTrue);
    expect(logMelScoreMatches(logMelMatchThreshold), isTrue);
    expect(logMelScoreMatches(0.50), isFalse);
    expect(logMelSampleRate, 8000);
    expect(logMelBandCount, 40);
    expect(logMelHopMs, 10);
    expect(logMelSearchWindowMs, jingleSearchWindowMs);
  });

  test('log-mel template round-trips', () {
    final frames = [
      List<double>.filled(logMelBandCount, 0.25),
      [for (var i = 0; i < logMelBandCount; i++) i / logMelBandCount],
    ];
    final decoded = decodeLogMel(encodeLogMel(frames));
    expect(decoded, hasLength(2));
    expect(decoded[0][0], closeTo(0.25, 1e-6));
    expect(decoded[1][7], closeTo(7 / logMelBandCount, 1e-6));
  });

  test(
    'jingle search keeps a shifted RTL hit and drops short or rare ones',
    () {
      final stable = [
        for (final id in [1, 2, 3])
          _hit(id, start: 0, end: 4000, duration: 3600000),
      ];
      expect(acceptJingleCandidate(stable), isTrue);

      // 0:00 ou 27,7 s, juste après le pré-roll.
      final rtl = [
        _hit(1, start: 0, end: 3500, duration: 3600000),
        _hit(
          2,
          start: 27700,
          end: 31200,
          duration: 3600000,
          preRollEndMs: 27700,
        ),
        _hit(
          3,
          start: 27700,
          end: 31200,
          duration: 3600000,
          preRollEndMs: 27700,
        ),
      ];
      expect(acceptJingleCandidate(rtl), isTrue);
      expect(classifyRepeatedSegment(rtl).kind, SkipSegmentKind.intro);
      expect(classifyRepeatedSegment(rtl).autoSkip, isTrue);

      final twoSeconds = [
        for (final id in [1, 2, 3])
          _hit(id, start: 0, end: 2000, duration: 3600000),
      ];
      expect(acceptJingleCandidate(twoSeconds), isFalse);

      final onlyTwoEpisodes = [
        _hit(1, start: 0, end: 4000, duration: 3600000),
        _hit(2, start: 0, end: 4000, duration: 3600000),
      ];
      expect(acceptJingleCandidate(onlyTwoEpisodes), isFalse);

      final pastWindow = [
        for (final id in [1, 2, 3])
          _hit(id, start: 200000, end: 204000, duration: 3600000),
      ];
      expect(acceptJingleCandidate(pastWindow), isFalse);
    },
  );

  test('placement distinguishes intro, outro, dynamic ad and a refrain', () {
    final intro = [
      for (final id in [1, 2, 4])
        _hit(id, start: 1200, end: 6000, duration: 3600000),
    ];
    expect(classifyRepeatedSegment(intro).kind, SkipSegmentKind.intro);

    final outro = [
      _hit(1, start: 3553000, end: 3600000, duration: 3600000),
      _hit(2, start: 3585000, end: 3600000, duration: 3600000),
    ];
    expect(classifyRepeatedSegment(outro).kind, SkipSegmentKind.outro);

    // Squarespace, huit positions : insertion dynamique.
    const squarespaceStarts = [
      40000,
      120000,
      250000,
      480000,
      700000,
      900000,
      1100000,
      1400000,
    ];
    final squarespace = [
      for (var i = 0; i < squarespaceStarts.length; i++)
        _hit(
          i + 1,
          start: squarespaceStarts[i],
          end: squarespaceStarts[i] + 29000,
          duration: 3600000,
        ),
    ];
    final squarespaceClass = classifyRepeatedSegment(squarespace);
    expect(squarespaceClass.kind, SkipSegmentKind.ad);
    expect(squarespaceClass.autoSkip, isTrue);

    final sponsor = [
      _hit(1, start: 600000, end: 670000, duration: 3600000),
      _hit(2, start: 601000, end: 671000, duration: 3600000),
    ];
    expect(classifyRepeatedSegment(sponsor).kind, SkipSegmentKind.sponsor);

    final refrain = [
      _hit(7, start: 30000, end: 45000, duration: 3600000),
      _hit(7, start: 120000, end: 135000, duration: 3600000),
      _hit(7, start: 400000, end: 415000, duration: 3600000),
    ];
    final refrainClass = classifyRepeatedSegment(refrain);
    expect(refrainClass.kind, isNull);
    expect(refrainClass.autoSkip, isFalse);
  });

  test('Acast sting ends the pre-roll and RSS duration estimates ads', () {
    expect(knownNetworkStings, [acastNetworkSting]);
    expect(acastNetworkSting.durationMs, 1300);
    expect(preRollEndFromSting(27000, acastNetworkSting), 28300);

    expect(
      approximateInsertedAdMs(rssDurationMs: 1800000, fileDurationMs: 1830000),
      30000,
    );
    expect(
      approximateInsertedAdMs(rssDurationMs: 1800000, fileDurationMs: 2055000),
      255000,
    );
    expect(
      approximateInsertedAdMs(rssDurationMs: 1800000, fileDurationMs: 1800000),
      isNull,
    );
    expect(
      approximateInsertedAdMs(rssDurationMs: null, fileDurationMs: 1800000),
      isNull,
    );
  });
}

SegmentOccurrence _hit(
  int episodeId, {
  required int start,
  required int end,
  required int duration,
  int? preRollEndMs,
}) {
  return SegmentOccurrence(
    episodeId: episodeId,
    startMs: start,
    endMs: end,
    episodeDurationMs: duration,
    preRollEndMs: preRollEndMs,
  );
}
