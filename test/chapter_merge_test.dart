import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/skip_segments.dart';
import 'package:podavio/player/chapter_merge.dart';
import 'package:podavio/player/segment_skip.dart';

void main() {
  test('a detected passage splits the chapter it crosses', () {
    final merged = mergeChaptersWithSegments(
      chapters: [
        _chapter(id: 1, startMs: 0, title: 'Talk'),
        _chapter(id: 2, startMs: 60000, title: 'Interview'),
      ],
      segments: [
        _segment(id: 7, startMs: 20000, endMs: 40000, kind: SkipSegmentKind.ad),
      ],
    );

    expect(merged.map((chapter) => chapter.title), [
      'Talk',
      'Ad',
      'Talk',
      'Interview',
    ]);
    expect(merged.map((chapter) => chapter.startMs), [0, 20000, 40000, 60000]);
    expect(merged[1].fromSegment, isTrue);
    expect(merged[1].endMs, 40000);
    expect(merged[2].id, isNot(merged[0].id));
    expect(
      currentDisplayChapter(merged, const Duration(seconds: 25))?.title,
      'Ad',
    );
    expect(
      currentDisplayChapter(merged, const Duration(seconds: 45))?.title,
      'Talk',
    );
  });

  test('passages become chapters when the episode has none', () {
    final merged = mergeChaptersWithSegments(
      chapters: const [],
      segments: [
        _segment(
          id: 3,
          startMs: 10000,
          endMs: 30000,
          kind: SkipSegmentKind.sponsor,
        ),
      ],
    );

    expect(merged, hasLength(1));
    expect(merged.single.title, 'Sponsor');
    expect(merged.single.endMs, 30000);
    expect(currentDisplayChapter(merged, const Duration(seconds: 40)), isNull);
  });

  test('a rejected passage and a chapter-sourced one stay out', () {
    final merged = mergeChaptersWithSegments(
      chapters: [_chapter(id: 1, startMs: 0, title: 'Talk')],
      segments: [
        _segment(
          id: 1,
          startMs: 1000,
          endMs: 2000,
          kind: SkipSegmentKind.ad,
          confirmed: false,
        ),
        _segment(
          id: 2,
          startMs: 3000,
          endMs: 4000,
          kind: SkipSegmentKind.ad,
          source: SkipSegmentSource.chapter,
        ),
      ],
    );

    expect(merged.map((chapter) => chapter.title), ['Talk']);
  });

  test('a narrower passage is nested inside a wider one', () {
    final merged = mergeChaptersWithSegments(
      chapters: const [],
      segments: [
        _segment(id: 1, startMs: 10000, endMs: 40000, kind: SkipSegmentKind.ad),
        _segment(
          id: 2,
          startMs: 20000,
          endMs: 30000,
          kind: SkipSegmentKind.sponsor,
        ),
      ],
    );

    expect(merged.map((chapter) => chapter.title), ['Ad', 'Sponsor', 'Ad']);
    expect(merged.map((chapter) => chapter.startMs), [10000, 20000, 30000]);
  });

  test('the button is offered only when automatic skip is off', () {
    final ad = SkipCandidate(
      id: 1,
      startMs: 10000,
      endMs: 30000,
      kind: SkipSegmentKind.ad,
      confirmed: null,
    );
    final intro = SkipCandidate(
      id: 2,
      startMs: 0,
      endMs: 15000,
      kind: SkipSegmentKind.intro,
      confirmed: true,
    );

    expect(
      manualSkipOffer(
        positionMs: 12000,
        autoSkipAds: true,
        autoSkipKinds: const {SkipSegmentKind.ad},
        segments: [ad, intro],
      ),
      isNull,
    );
    expect(
      manualSkipOffer(
        positionMs: 20000,
        autoSkipAds: false,
        autoSkipKinds: const {SkipSegmentKind.ad},
        segments: [ad],
      )?.seekToMs,
      30000,
    );
    expect(
      manualSkipOffer(
        positionMs: 5000,
        autoSkipAds: true,
        autoSkipKinds: const {SkipSegmentKind.ad},
        segments: [intro],
      )?.kind,
      SkipSegmentKind.intro,
    );
  });
}

EpisodeChapter _chapter({
  required int id,
  required int startMs,
  required String title,
}) {
  return EpisodeChapter(
    id: id,
    episodeId: 1,
    startMs: startMs,
    title: title,
    toc: true,
    sortIndex: 0,
  );
}

SkipSegment _segment({
  required int id,
  required int startMs,
  required int endMs,
  required SkipSegmentKind kind,
  SkipSegmentSource source = SkipSegmentSource.fingerprint,
  bool? confirmed,
}) {
  return SkipSegment(
    id: id,
    episodeId: 1,
    startMs: startMs,
    endMs: endMs,
    kind: kind,
    source: source,
    matches: 1,
    confirmed: confirmed,
  );
}
