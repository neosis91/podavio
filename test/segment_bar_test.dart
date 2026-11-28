import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/skip_segments.dart';
import 'package:podavio/ui/player/segment_bar.dart';

void main() {
  const track = Rect.fromLTWH(10, 0, 1000, 16);

  test('places a span along the track', () {
    final rect = segmentBarRect(
      track: track,
      durationMs: 10000,
      startMs: 1000,
      endMs: 2500,
      textDirection: TextDirection.ltr,
    );
    expect(rect, const Rect.fromLTWH(110, 0, 150, 16));
  });

  test('mirrors a span for right-to-left', () {
    final rect = segmentBarRect(
      track: track,
      durationMs: 10000,
      startMs: 0,
      endMs: 1000,
      textDirection: TextDirection.rtl,
    );
    expect(rect, const Rect.fromLTWH(910, 0, 100, 16));
  });

  test('keeps a short span visible', () {
    final rect = segmentBarRect(
      track: track,
      durationMs: 1000000,
      startMs: 1000,
      endMs: 1100,
      textDirection: TextDirection.ltr,
      minWidth: 4,
    );
    expect(rect!.width, 4);
    expect(rect.left, closeTo(11, 0.01));
  });

  testWidgets('the Material 3 slider still paints its track', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SliderTheme(
            data: SliderThemeData(
              trackShape: SkipSegmentTrackShape(
                spans: [
                  ColoredBarSpan(
                    startMs: 1000,
                    endMs: 2000,
                    color: Color(skipKindArgb(SkipSegmentKind.ad)),
                  ),
                ],
                durationMs: 10000,
              ),
            ),
            child: Slider(value: 0.3, onChanged: (_) {}),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Slider), findsOneWidget);
  });

  test('rejects an empty range', () {
    expect(
      segmentBarRect(
        track: track,
        durationMs: 10000,
        startMs: 50,
        endMs: 50,
        textDirection: TextDirection.ltr,
      ),
      isNull,
    );
    expect(
      segmentBarRect(
        track: track,
        durationMs: 0,
        startMs: 0,
        endMs: 10,
        textDirection: TextDirection.ltr,
      ),
      isNull,
    );
  });
}
