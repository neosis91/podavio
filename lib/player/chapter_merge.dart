import '../data/app_database.dart';
import '../data/skip_segments.dart';

/// Chapitre affiché : un chapitre du flux, un passage détecté, ou la suite
/// d’un chapitre coupé par un passage.
class DisplayChapter {
  const DisplayChapter({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.title,
    required this.fromSegment,
    this.link,
  });

  final int id;
  final int startMs;

  /// Fin exclusive, ou `null` jusqu’à la fin de l’épisode.
  final int? endMs;
  final String title;

  /// Titre à traduire : c’est une clé de [skipKindLabel].
  final bool fromSegment;
  final String? link;
}

DisplayChapter? currentDisplayChapter(
  List<DisplayChapter> chapters,
  Duration position,
) {
  final ms = position.inMilliseconds;
  DisplayChapter? current;
  for (final chapter in chapters) {
    if (chapter.startMs > ms) break;
    final ended = chapter.endMs != null && ms >= chapter.endMs!;
    current = ended ? null : chapter;
  }
  return current;
}

class _Span {
  const _Span({
    required this.start,
    required this.end,
    required this.title,
    required this.id,
    required this.fromSegment,
    this.link,
  });

  final int start;
  final int? end;
  final String title;
  final int id;
  final bool fromSegment;
  final String? link;
}

/// Insère les passages détectés dans les chapitres.
///
/// Un passage coupe le chapitre qu’il traverse. La partie d’avant et celle
/// d’après gardent le titre du chapitre. Les passages déjà issus d’un titre
/// de chapitre, et ceux écartés à la main, ne sont pas ajoutés une seconde fois.
List<DisplayChapter> mergeChaptersWithSegments({
  required List<EpisodeChapter> chapters,
  required List<SkipSegment> segments,
}) {
  final ordered = [...chapters]
    ..sort((a, b) {
      final byStart = a.startMs.compareTo(b.startMs);
      if (byStart != 0) return byStart;
      return a.sortIndex.compareTo(b.sortIndex);
    });
  final spans = <_Span>[];
  if (ordered.isEmpty || ordered.first.startMs > 0) {
    spans.add(
      _Span(
        start: 0,
        end: ordered.isEmpty ? null : ordered.first.startMs,
        title: '',
        id: 0,
        fromSegment: false,
      ),
    );
  }
  for (var i = 0; i < ordered.length; i++) {
    final chapter = ordered[i];
    final next = i + 1 < ordered.length ? ordered[i + 1].startMs : null;
    if (next != null && next <= chapter.startMs) continue;
    spans.add(
      _Span(
        start: chapter.startMs,
        end: next,
        title: chapter.title,
        id: chapter.id,
        fromSegment: false,
        link: chapter.link,
      ),
    );
  }

  var synthetic = -1;
  final found =
      segments
          .where(
            (segment) =>
                segment.confirmed != false &&
                segment.source != SkipSegmentSource.chapter &&
                segment.endMs > segment.startMs,
          )
          .toList()
        ..sort((a, b) {
          final byStart = a.startMs.compareTo(b.startMs);
          if (byStart != 0) return byStart;
          return (b.endMs - b.startMs).compareTo(a.endMs - a.startMs);
        });
  for (final segment in found) {
    _punch(
      spans,
      segment.startMs,
      segment.endMs,
      skipKindLabel(segment.kind),
      () => synthetic--,
    );
  }

  return [
    for (final span in spans)
      if (span.title.isNotEmpty && (span.end == null || span.end! > span.start))
        DisplayChapter(
          id: span.id,
          startMs: span.start,
          endMs: span.end,
          title: span.title,
          fromSegment: span.fromSegment,
          link: span.link,
        ),
  ];
}

void _punch(
  List<_Span> spans,
  int start,
  int end,
  String title,
  int Function() nextId,
) {
  _splitAt(spans, start, nextId);
  _splitAt(spans, end, nextId);
  final next = <_Span>[];
  var placed = false;
  for (final span in spans) {
    final spanEnd = span.end ?? 1 << 62;
    final overlaps = span.start < end && spanEnd > start;
    if (!overlaps) {
      next.add(span);
      continue;
    }
    if (!placed) {
      next.add(
        _Span(
          start: start,
          end: end,
          title: title,
          id: nextId(),
          fromSegment: true,
        ),
      );
      placed = true;
    }
  }
  spans
    ..clear()
    ..addAll(next);
}

void _splitAt(List<_Span> spans, int at, int Function() nextId) {
  for (var i = 0; i < spans.length; i++) {
    final span = spans[i];
    if (at <= span.start) return;
    if (span.end != null && at >= span.end!) continue;
    spans[i] = _Span(
      start: span.start,
      end: at,
      title: span.title,
      id: span.id,
      fromSegment: span.fromSegment,
      link: span.link,
    );
    spans.insert(
      i + 1,
      _Span(
        start: at,
        end: span.end,
        title: span.title,
        id: nextId(),
        fromSegment: span.fromSegment,
        link: span.link,
      ),
    );
    return;
  }
}
