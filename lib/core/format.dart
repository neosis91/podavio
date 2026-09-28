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
