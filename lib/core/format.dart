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
