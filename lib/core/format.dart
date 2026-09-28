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
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
