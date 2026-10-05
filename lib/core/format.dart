import 'package:intl/intl.dart';

String formatClock(Duration duration) {
  final safe = duration < Duration.zero ? Duration.zero : duration;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  final seconds = safe.inSeconds.remainder(60);
  final mm = hours > 0 ? minutes.toString().padLeft(2, '0') : '$minutes';
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$mm:$ss';
  return '$mm:$ss';
}

/// Durée média convertie en temps réel à la vitesse [speed] (ex. 2× → moitié).
Duration durationAtSpeed(Duration media, double speed) {
  if (media <= Duration.zero) return Duration.zero;
  if (speed <= 0 || (speed - 1).abs() < 0.001) return media;
  return Duration(microseconds: (media.inMicroseconds / speed).round());
}

String formatDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return "Aujourd'hui";
  if (day == today.subtract(const Duration(days: 1))) return 'Hier';
  return DateFormat.yMMMd('fr').format(local);
}

/// Date de sortie courte pour les listes (tuiles d’épisode).
String formatListDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return 'Auj.';
  if (day == today.subtract(const Duration(days: 1))) return 'Hier';
  if (local.year == now.year) {
    return DateFormat('d MMM', 'fr').format(local);
  }
  return DateFormat('d/MM/yy', 'fr').format(local);
}

/// Date de sortie : sans année si c’est l’année en cours.
String formatReleaseDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  if (local.year == DateTime.now().year) {
    return DateFormat.MMMd('fr').format(local);
  }
  return DateFormat.yMMMd('fr').format(local);
}

String formatListeningTime(int seconds) {
  if (seconds <= 0) return '0 min';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours h';
  return '$hours h $minutes min';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 Mo';
  const kilo = 1024.0;
  if (bytes < kilo * kilo) {
    return '${(bytes / kilo).toStringAsFixed(bytes < 10 * kilo ? 1 : 0)} Ko';
  }
  if (bytes < kilo * kilo * kilo) {
    final mega = bytes / (kilo * kilo);
    return '${mega.toStringAsFixed(mega < 10 ? 1 : 0)} Mo';
  }
  final giga = bytes / (kilo * kilo * kilo);
  return '${giga.toStringAsFixed(giga < 10 ? 2 : 1)} Go';
}

String formatReleaseCadence(Duration? interval) {
  if (interval == null) return 'Indéterminé';
  final days = interval.inHours / 24;
  if (days < 1.2) return 'Quotidien';
  if (days < 2.5) return 'Tous les 2 jours';
  if (days < 5) return 'Tous les ${days.round()} jours';
  if (days < 9) return 'Hebdomadaire';
  if (days < 18) return 'Toutes les 2 semaines';
  if (days < 40) return 'Mensuel';
  if (days < 80) return 'Tous les 2 mois';
  return 'Tous les ${days.round()} jours';
}

String formatMonthShort(int month) {
  return DateFormat.MMM('fr').format(DateTime(2000, month));
}

String formatRelativeFuture(DateTime? date) {
  if (date == null) return 'Indéterminée';
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = day.difference(today).inDays;
  if (diff < 0) return 'En retard (prévu ${formatDate(local)})';
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Demain';
  if (diff < 14) return 'Dans $diff jours';
  return formatDate(local);
}

String audioExtension(String? mimeType, String url) {
  final mime = mimeType?.toLowerCase() ?? '';
  if (mime.contains('mpeg') || mime.contains('mp3')) return '.mp3';
  if (mime.contains('mp4') || mime.contains('m4a') || mime.contains('aac')) {
    return '.m4a';
  }
  if (mime.contains('ogg') || mime.contains('opus')) return '.ogg';
  if (mime.contains('wav')) return '.wav';
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  for (final extension in ['.mp3', '.m4a', '.aac', '.ogg', '.opus', '.wav']) {
    if (path.endsWith(extension)) return extension;
  }
  return '.mp3';
}

/// Nom de fichier pour un épisode téléchargé : `[podcast] titre.ext`
String downloadFileName({
  required String podcastTitle,
  required String episodeTitle,
  required String extension,
}) {
  final podcast = sanitizeFileName(podcastTitle).trim();
  final episode = sanitizeFileName(episodeTitle).trim();
  final label = podcast.isEmpty
      ? (episode.isEmpty ? 'episode' : episode)
      : episode.isEmpty
      ? '[$podcast]'
      : '[$podcast] $episode';
  final maxBase = 180;
  final base = label.length <= maxBase
      ? label
      : label.substring(0, maxBase).trimRight();
  return '$base$extension';
}

String sanitizeFileName(String value) {
  return value
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^\.+'), '')
      .trim();
}

String plainText(String html) {
  const lineBreak = '\u0000';
  const paragraphBreak = '\u0001';
  if (!html.contains('<')) return _plainLines(_decodeEntities(html));

  final marked = html
      .replaceAll(RegExp(r'<br[^>]*>', caseSensitive: false), lineBreak)
      .replaceAll(RegExp(r'<hr[^>]*>', caseSensitive: false), paragraphBreak)
      .replaceAll(
        RegExp(
          r'</?(?:p|div|h[1-6]|blockquote|section|article|header|footer|pre|ul|ol|tr)(?:\s[^>]*)?>',
          caseSensitive: false,
        ),
        paragraphBreak,
      )
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '$lineBreak• ')
      .replaceAll(RegExp(r'<[^>]*>'), '');
  final collapsed = _decodeEntities(marked).replaceAll(RegExp(r'\s+'), ' ');
  return collapsed
      .replaceAll(paragraphBreak, '\n\n')
      .replaceAll(lineBreak, '\n')
      .replaceAll(RegExp(r'[ \t]*\n[ \t]*'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Segment de notes d’épisode : texte brut ou lien http(s).
class ShowNotesSpan {
  const ShowNotesSpan(this.text, {this.url});

  final String text;
  final String? url;

  bool get isLink => url != null && url!.isNotEmpty;
}

/// Conserve les liens `<a href>` et les URLs nues, le reste comme [plainText].
List<ShowNotesSpan> showNotesSpans(String html) {
  if (html.trim().isEmpty) return const [];

  // Marqueurs hors plage utilisée par [plainText] (\u0000 / \u0001).
  const start = '\uE000';
  const sep = '\uE001';
  const end = '\uE002';
  final hrefs = <String>[];
  final withAnchors = html.replaceAllMapped(
    RegExp(
      r'''<a\s[^>]*?\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))[^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    ),
    (match) {
      final href = match.group(1) ?? match.group(2) ?? match.group(3) ?? '';
      final label = match.group(4) ?? '';
      final index = hrefs.length;
      hrefs.add(href);
      return '$start$index$sep$label$end';
    },
  );

  final plain = plainText(withAnchors);
  if (plain.isEmpty) return const [];

  final spans = <ShowNotesSpan>[];
  final marker = RegExp('$start(\\d+)$sep(.*?)$end', dotAll: true);
  var cursor = 0;
  for (final match in marker.allMatches(plain)) {
    if (match.start > cursor) {
      spans.addAll(_spansWithBareUrls(plain.substring(cursor, match.start)));
    }
    final index = int.tryParse(match.group(1) ?? '');
    final label = match.group(2) ?? '';
    final href = (index != null && index >= 0 && index < hrefs.length)
        ? hrefs[index]
        : '';
    final uri = _httpUrl(href);
    if (uri == null) {
      final text = label.isNotEmpty ? label : href.trim();
      if (text.isNotEmpty) spans.add(ShowNotesSpan(text));
    } else {
      final text = label.isNotEmpty ? label : uri.toString();
      spans.add(ShowNotesSpan(text, url: uri.toString()));
    }
    cursor = match.end;
  }
  if (cursor < plain.length) {
    spans.addAll(_spansWithBareUrls(plain.substring(cursor)));
  }
  return spans;
}

Iterable<ShowNotesSpan> _spansWithBareUrls(String text) sync* {
  if (text.isEmpty) return;
  final pattern = RegExp(r'https?://[^\s]+', caseSensitive: false);
  var cursor = 0;
  for (final match in pattern.allMatches(text)) {
    var end = match.end;
    while (end > match.start &&
        '.,;:!?)]}>»"\''.contains(text[end - 1])) {
      end--;
    }
    final raw = text.substring(match.start, end);
    final uri = _httpUrl(raw);
    if (uri == null) continue;
    if (match.start > cursor) {
      yield ShowNotesSpan(text.substring(cursor, match.start));
    }
    yield ShowNotesSpan(uri.toString(), url: uri.toString());
    cursor = end;
  }
  if (cursor < text.length) {
    yield ShowNotesSpan(text.substring(cursor));
  }
}

Uri? _httpUrl(String raw) {
  final value = _decodeEntities(raw).trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

String _plainLines(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim());
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _decodeEntities(String value) {
  return value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
}
