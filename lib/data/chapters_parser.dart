import 'dart:convert';

import 'package:xml/xml.dart';

import '../core/search.dart';
import 'feed_text.dart';
import 'skip_segments.dart';

class ChapterDraft {
  const ChapterDraft({
    required this.startMs,
    required this.title,
    this.link,
    this.toc = true,
  });

  final int startMs;
  final String title;
  final String? link;
  final bool toc;
}

/// Parse un fichier chapitres Podcast Index (JSON).
List<ChapterDraft> parseChaptersJson(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return const [];
  final raw = decoded['chapters'];
  if (raw is! List) return const [];
  final chapters = <ChapterDraft>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final start = _asSeconds(item['startTime']);
    if (start == null || start < 0) continue;
    final toc = item['toc'] == false ? false : true;
    chapters.add(
      ChapterDraft(
        startMs: (start * 1000).round(),
        title: repairMojibake('${item['title'] ?? ''}'.trim()),
        link: _blankToNull('${item['url'] ?? ''}'),
        toc: toc,
      ),
    );
  }
  chapters.sort((a, b) => a.startMs.compareTo(b.startMs));
  return chapters;
}

/// Extrait les chapitres Podlove (psc:) d’un flux RSS, indexés par guid puis URL audio.
Map<String, List<ChapterDraft>> parsePscChaptersByItem(String xmlText) {
  final document = XmlDocument.parse(xmlText);
  final byKey = <String, List<ChapterDraft>>{};
  for (final item in document.findAllElements('item')) {
    final chapters = _pscChaptersIn(item);
    if (chapters.isEmpty) continue;
    for (final key in _itemKeys(item)) {
      byKey.putIfAbsent(key, () => chapters);
    }
  }
  return byKey;
}

List<ChapterDraft> _pscChaptersIn(XmlElement item) {
  final blocks = item.childElements.where(
    (el) => _local(el) == 'chapters' && _isPsc(el),
  );
  final chapters = <ChapterDraft>[];
  for (final block in blocks) {
    for (final node in block.childElements) {
      if (_local(node) != 'chapter') continue;
      final start = parseChapterClock(node.getAttribute('start') ?? '');
      if (start == null) continue;
      chapters.add(
        ChapterDraft(
          startMs: start,
          title: repairMojibake((node.getAttribute('title') ?? '').trim()),
          link: _blankToNull(node.getAttribute('href')),
        ),
      );
    }
  }
  chapters.sort((a, b) => a.startMs.compareTo(b.startMs));
  return chapters;
}

Iterable<String> _itemKeys(XmlElement item) sync* {
  final guid = item.getElement('guid')?.innerText.trim() ?? '';
  if (guid.isNotEmpty) yield guid;
  for (final enclosure in item.findElements('enclosure')) {
    final url = enclosure.getAttribute('url')?.trim() ?? '';
    if (url.isNotEmpty) yield url;
  }
}

bool _isPsc(XmlElement el) {
  final uri = el.namespaceUri ?? '';
  return uri.contains('podlove.org/simple-chapters') || el.name.prefix == 'psc';
}

String _local(XmlElement el) => el.name.local.toLowerCase();

double? _asSeconds(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final asClock = parseChapterClock(value);
    if (asClock != null) return asClock / 1000.0;
    return double.tryParse(value);
  }
  return null;
}

/// Accepte `125`, `2:05`, `1:02:05` ou `8:26.250`.
int? parseChapterClock(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (!text.contains(':')) {
    final seconds = double.tryParse(text);
    if (seconds == null || seconds < 0) return null;
    return (seconds * 1000).round();
  }
  final parts = text.split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  var hours = 0.0;
  var minutes = 0.0;
  var seconds = 0.0;
  if (parts.length == 3) {
    hours = double.tryParse(parts[0]) ?? -1;
    minutes = double.tryParse(parts[1]) ?? -1;
    seconds = double.tryParse(parts[2]) ?? -1;
  } else {
    minutes = double.tryParse(parts[0]) ?? -1;
    seconds = double.tryParse(parts[1]) ?? -1;
  }
  if (hours < 0 || minutes < 0 || seconds < 0) return null;
  final total = hours * 3600 + minutes * 60 + seconds;
  return (total * 1000).round();
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed;
}

// Titres de chapitres qui annoncent une pub ou un sponsor.
// Le texte est déjà plié (minuscules, sans accent).
final _selfPromoTitle = RegExp(
  r'(self[-\s]?promo\w*|auto[-\s]?promo\w*|autopub\w*)',
);
final _sponsorTitle = RegExp(
  r'(sponsor\w*|parrain\w*|partenariat|partenaire|gesponsert|gesponsord|'
  r'patrocin\w*|brought to you by|host[\s-]?read|спонсор|スポンサー|رعاية|راعي)',
);
final _adTitle = RegExp(
  r'(\bads?\b|\badvert\w*|\bcommercials?\b|\bpub\b|\bpubs\b|'
  r'publicit\w*|pubblicit\w*|publicidad\w*|\banuncios?\b|'
  r'\bwerbung\b|\banzeige\b|\breclame\b|'
  r'pre[\s-]?roll|mid[\s-]?roll|post[\s-]?roll|'
  r'реклам\w*|広告|إعلان)',
);

/// `null` si le titre ne ressemble pas à une pub, un sponsor ou une
/// auto-promo. Insensible à la casse et aux accents.
SkipSegmentKind? skipKindForChapterTitle(String title) {
  final folded = foldForSearch(title).trim();
  if (folded.isEmpty) return null;
  if (_selfPromoTitle.hasMatch(folded)) return SkipSegmentKind.selfPromo;
  if (_sponsorTitle.hasMatch(folded)) return SkipSegmentKind.sponsor;
  if (_adTitle.hasMatch(folded)) return SkipSegmentKind.ad;
  return null;
}
