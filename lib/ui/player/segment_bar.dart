import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/skip_segments.dart';

/// Portion colorée sur la barre de lecture.
class ColoredBarSpan {
  const ColoredBarSpan({
    required this.startMs,
    required this.endMs,
    required this.color,
  });

  final int startMs;
  final int endMs;
  final Color color;
}

/// Passages encore affichés, du plus long au plus court à départ égal,
/// pour qu’un passage court reste visible par-dessus un plus large.
List<ColoredBarSpan> spansForSegments(List<SkipSegment> segments) {
  final spans = <ColoredBarSpan>[
    for (final segment in segments)
      if (segment.endMs > segment.startMs)
        ColoredBarSpan(
          startMs: segment.startMs,
          endMs: segment.endMs,
          color: Color(skipKindArgb(segment.kind)),
        ),
  ];
  spans.sort((a, b) {
    final byStart = a.startMs.compareTo(b.startMs);
    if (byStart != 0) return byStart;
    return (b.endMs - b.startMs).compareTo(a.endMs - a.startMs);
  });
  return spans;
}

/// Rectangle du passage sur la piste. `null` si la durée ou l’intervalle
/// est vide. Un passage trop court garde [minWidth] pour rester lisible.
Rect? segmentBarRect({
  required Rect track,
  required int durationMs,
  required int startMs,
  required int endMs,
  required TextDirection textDirection,
  double minWidth = 4,
}) {
  if (durationMs <= 0 || track.width <= 0 || endMs <= startMs) return null;
  double xOf(int ms) {
    final fraction = ms.clamp(0, durationMs) / durationMs;
    return textDirection == TextDirection.ltr
        ? track.left + track.width * fraction
        : track.right - track.width * fraction;
  }

  var left = math.min(xOf(startMs), xOf(endMs));
  var right = math.max(xOf(startMs), xOf(endMs));
  if (right - left < minWidth) right = left + minWidth;
  if (right > track.right) {
    right = track.right;
    left = math.max(track.left, right - minWidth);
  }
  if (left < track.left) left = track.left;
  if (right - left < 1) return null;
  return Rect.fromLTRB(left, track.top, right, track.bottom);
}

/// Piste arrondie du lecteur, avec les passages peints dans la barre.
///
/// Le grand lecteur utilise la piste Material 3 de 2023. La piste à trou
/// exige [SliderThemeData.trackGap], absent de ce thème : le dessin
/// échouait et la barre disparaissait.
class SkipSegmentTrackShape extends RoundedRectSliderTrackShape {
  const SkipSegmentTrackShape({required this.spans, required this.durationMs});

  final List<ColoredBarSpan> spans;
  final int durationMs;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    if (durationMs > 0 && spans.isNotEmpty) {
      final canvas = context.canvas;
      canvas
        ..save()
        ..clipRRect(
          RRect.fromRectAndRadius(
            trackRect,
            Radius.circular(trackRect.shortestSide / 2),
          ),
        );
      for (final span in spans) {
        final rect = segmentBarRect(
          track: trackRect,
          durationMs: durationMs,
          startMs: span.startMs,
          endMs: span.endMs,
          textDirection: textDirection,
        );
        if (rect == null) continue;
        canvas.drawRect(rect, Paint()..color = span.color);
      }
      canvas.restore();
    }
    _paintUnreadBorder(
      context.canvas,
      trackRect: trackRect,
      thumbCenter: thumbCenter,
      trackHeight: sliderTheme.trackHeight,
      textDirection: textDirection,
    );
  }
}

/// Barre de lecture des listes.
///
/// Thème clair : lu sombre, reste gris, pour rester lisible sur un fond clair.
/// Thème sombre : lu blanc, reste noir, contour blanc sur toute la barre.
/// Les portions colorées sont peintes par-dessus.
class SegmentProgressBar extends StatelessWidget {
  const SegmentProgressBar({
    super.key,
    required this.fraction,
    required this.durationMs,
    this.spans = const [],
    this.height = 4,
  });

  final double fraction;
  final int durationMs;
  final List<ColoredBarSpan> spans;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SegmentProgressPainter(
          fraction: fraction.clamp(0.0, 1.0),
          durationMs: durationMs,
          spans: spans,
          textDirection: Directionality.of(context),
          played: dark ? Colors.white : const Color(0xFF1A1A1A),
          unread: dark ? Colors.black : const Color(0xFFE4E4E4),
          border: dark ? Colors.white : null,
        ),
      ),
    );
  }
}

class _SegmentProgressPainter extends CustomPainter {
  const _SegmentProgressPainter({
    required this.fraction,
    required this.durationMs,
    required this.spans,
    required this.textDirection,
    required this.played,
    required this.unread,
    required this.border,
  });

  final double fraction;
  final int durationMs;
  final List<ColoredBarSpan> spans;
  final TextDirection textDirection;
  final Color played;
  final Color unread;
  final Color? border;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final track = Offset.zero & size;
    final radius = Radius.circular(track.height / 2);
    final isLTR = textDirection == TextDirection.ltr;
    final playedEdge = isLTR
        ? track.left + track.width * fraction
        : track.right - track.width * fraction;
    final shape = RRect.fromRectAndRadius(track, radius);
    canvas.drawRRect(shape, Paint()..color = unread);
    if (fraction > 0) {
      final playedRect = isLTR
          ? Rect.fromLTRB(track.left, track.top, playedEdge, track.bottom)
          : Rect.fromLTRB(playedEdge, track.top, track.right, track.bottom);
      canvas
        ..save()
        ..clipRRect(shape)
        ..drawRect(playedRect, Paint()..color = played)
        ..restore();
    }
    if (durationMs > 0 && spans.isNotEmpty) {
      canvas
        ..save()
        ..clipRRect(shape);
      for (final span in spans) {
        final rect = segmentBarRect(
          track: track,
          durationMs: durationMs,
          startMs: span.startMs,
          endMs: span.endMs,
          textDirection: textDirection,
        );
        if (rect == null) continue;
        canvas.drawRect(rect, Paint()..color = span.color);
      }
      canvas.restore();
    }
    final outline = border;
    if (outline != null) {
      const stroke = 1.0;
      final inset = track.deflate(stroke / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(inset, Radius.circular(inset.height / 2)),
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_SegmentProgressPainter old) {
    return fraction != old.fraction ||
        durationMs != old.durationMs ||
        textDirection != old.textDirection ||
        played != old.played ||
        unread != old.unread ||
        border != old.border ||
        spans != old.spans;
  }
}

/// Contour blanc de la partie non lue. Le remplissage noir est déjà peint
/// par la piste ; sur le fond noir du lecteur, seul ce trait la montre.
void _paintUnreadBorder(
  Canvas canvas, {
  required Rect trackRect,
  required Offset thumbCenter,
  required double? trackHeight,
  required TextDirection textDirection,
}) {
  if (trackHeight == null || trackHeight <= 0 || trackRect.width <= 0) return;
  final isLTR = textDirection == TextDirection.ltr;
  final showsUnread = isLTR
      ? thumbCenter.dx < trackRect.right - trackHeight / 2
      : thumbCenter.dx > trackRect.left + trackHeight / 2;
  if (!showsUnread) return;

  final radius = Radius.circular(trackRect.height / 2);
  final unread = isLTR
      ? RRect.fromLTRBR(
          thumbCenter.dx - trackHeight / 2,
          trackRect.top,
          trackRect.right,
          trackRect.bottom,
          radius,
        )
      : RRect.fromLTRBR(
          trackRect.left,
          trackRect.top,
          thumbCenter.dx + trackHeight / 2,
          trackRect.bottom,
          radius,
        );
  final clip = isLTR
      ? Rect.fromLTRB(
          thumbCenter.dx,
          trackRect.top - 2,
          trackRect.right + 2,
          trackRect.bottom + 2,
        )
      : Rect.fromLTRB(
          trackRect.left - 2,
          trackRect.top - 2,
          thumbCenter.dx,
          trackRect.bottom + 2,
        );
  canvas
    ..save()
    ..clipRect(clip)
    ..drawRRect(
      unread,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    )
    ..restore();
}
