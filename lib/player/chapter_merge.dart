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

/// Titre affiché. Les passages détectés et le chapitre « Episode »
/// passent par la traduction. Un titre donné par le podcast reste tel quel.
String localizedChapterTitle(
  DisplayChapter chapter,
  String Function(String key) translate,
) {
  if (chapter.fromSegment || chapter.title == episodeChapterLabel) {
    final kind = chapter.fromSegment
        ? skipKindForStoredLabel(chapter.title)
        : null;
    if (kind != null) return translate(skipKindLabel(shownSkipKind(kind)));
    return translate(chapter.title);
  }
  return chapter.title;
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
/// La ligne couvre tout l’épisode. Un passage coupe le chapitre qu’il
/// traverse : la partie d’avant et celle d’après gardent le titre du
/// podcast. Sans chapitre du podcast, ces parties s’appellent « Episode ».
/// Les pubs qui se suivent restent des chapitres distincts. Les passages
/// déjà issus d’un titre de chapitre, et ceux écartés à la main, ne sont
/// pas ajoutés une seconde fois.
///
/// [durationMs] donne une fin exacte au dernier chapitre. Sans durée, cette
/// fin reste ouverte.
List<DisplayChapter> mergeChaptersWithSegments({
  required List<EpisodeChapter> chapters,
  required List<SkipSegment> segments,
  int? durationMs,
}) {
  final ordered = [...chapters]
    ..sort((a, b) {
      final byStart = a.startMs.compareTo(b.startMs);
      if (byStart != 0) return byStart;
      return a.sortIndex.compareTo(b.sortIndex);
    });
  int? close(int start, int? next) {
    if (next != null) return next;
    if (durationMs != null && durationMs > start) return durationMs;
    return null;
  }

  final spans = <_Span>[];
  if (ordered.isEmpty || ordered.first.startMs > 0) {
    spans.add(
      _Span(
        start: 0,
        end: ordered.isEmpty ? close(0, null) : ordered.first.startMs,
        title: episodeChapterLabel,
        id: 0,
        fromSegment: false,
      ),
    );
  }
  for (var i = 0; i < ordered.length; i++) {
    final chapter = ordered[i];
    final next = i + 1 < ordered.length ? ordered[i + 1].startMs : null;
    if (next != null && next <= chapter.startMs) continue;
    final title = chapter.title.trim().isEmpty
        ? episodeChapterLabel
        : chapter.title;
    spans.add(
      _Span(
        start: chapter.startMs,
        end: close(chapter.startMs, next),
        title: title,
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
      detectedChapterLabel(segment.kind, source: segment.source),
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
