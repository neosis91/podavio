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
  if (day == today) {
    return _phrase('today');
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return _phrase('yesterday');
  }
  return DateFormat.yMMMd().format(local);
}

/// Date de sortie courte pour les listes (tuiles d’épisode).
String formatListDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) {
    return _phrase('todayShort');
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return _phrase('yesterday');
  }
  if (local.year == now.year) {
    return DateFormat('d MMM').format(local);
  }
  return DateFormat('d/MM/yy').format(local);
}

/// Date de sortie : sans année si c’est l’année en cours.
String formatReleaseDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  if (local.year == DateTime.now().year) {
    return DateFormat.MMMd().format(local);
  }
  return DateFormat.yMMMd().format(local);
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
  if (interval == null) return _phrase('unknown');
  final days = interval.inHours / 24;
  if (days < 1.2) return _phrase('daily');
  if (days < 2.5) return _phrase('every2days');
  if (days < 5) return _phrase('everyNDays', {'n': '${days.round()}'});
  if (days < 9) return _phrase('weekly');
  if (days < 18) return _phrase('biweekly');
  if (days < 40) return _phrase('monthly');
  if (days < 80) return _phrase('bimonthly');
  return _phrase('everyNDays', {'n': '${days.round()}'});
}

String formatMonthShort(int month) {
  return DateFormat.MMM().format(DateTime(2000, month));
}

String formatRelativeFuture(DateTime? date) {
  if (date == null) return _phrase('unknownDate');
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = day.difference(today).inDays;
  if (diff < 0) {
    return _phrase('late', {'date': formatDate(local)});
  }
  if (diff == 0) return _phrase('today');
  if (diff == 1) return _phrase('tomorrow');
  if (diff < 14) return _phrase('inDays', {'n': '$diff'});
  return formatDate(local);
}

String _languageCode() {
  final current = Intl.getCurrentLocale();
  final code = current.split(RegExp('[_-]')).first.toLowerCase();
  if (code.isEmpty) return 'fr';
  return code;
}

String _phrase(String id, [Map<String, String>? params]) {
  final table = _phrases[_languageCode()] ?? _phrases['en']!;
  var text = table[id] ?? _phrases['fr']![id] ?? id;
  if (params != null) {
    for (final entry in params.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
  }
  return text;
}

const _phrases = <String, Map<String, String>>{
  'fr': {
    'today': "Aujourd'hui",
    'todayShort': 'Auj.',
    'yesterday': 'Hier',
    'tomorrow': 'Demain',
    'inDays': 'Dans {n} jours',
    'late': 'En retard (prévu {date})',
    'unknown': 'Indéterminé',
    'unknownDate': 'Indéterminée',
    'daily': 'Quotidien',
    'every2days': 'Tous les 2 jours',
    'everyNDays': 'Tous les {n} jours',
    'weekly': 'Hebdomadaire',
    'biweekly': 'Toutes les 2 semaines',
    'monthly': 'Mensuel',
    'bimonthly': 'Tous les 2 mois',
  },
  'en': {
    'today': 'Today',
    'todayShort': 'Today',
    'yesterday': 'Yesterday',
    'tomorrow': 'Tomorrow',
    'inDays': 'In {n} days',
    'late': 'Late (due {date})',
    'unknown': 'Unknown',
    'unknownDate': 'Unknown',
    'daily': 'Daily',
    'every2days': 'Every 2 days',
    'everyNDays': 'Every {n} days',
    'weekly': 'Weekly',
    'biweekly': 'Every 2 weeks',
    'monthly': 'Monthly',
    'bimonthly': 'Every 2 months',
  },
  'de': {
    'today': 'Heute',
    'todayShort': 'Heute',
    'yesterday': 'Gestern',
    'tomorrow': 'Morgen',
    'inDays': 'In {n} Tagen',
    'late': 'Verspätet (geplant {date})',
    'unknown': 'Unbekannt',
    'unknownDate': 'Unbekannt',
    'daily': 'Täglich',
    'every2days': 'Alle 2 Tage',
    'everyNDays': 'Alle {n} Tage',
    'weekly': 'Wöchentlich',
    'biweekly': 'Alle 2 Wochen',
    'monthly': 'Monatlich',
    'bimonthly': 'Alle 2 Monate',
  },
  'es': {
    'today': 'Hoy',
    'todayShort': 'Hoy',
    'yesterday': 'Ayer',
    'tomorrow': 'Mañana',
    'inDays': 'En {n} días',
    'late': 'Con retraso (previsto {date})',
    'unknown': 'Desconocido',
    'unknownDate': 'Desconocida',
    'daily': 'Diario',
    'every2days': 'Cada 2 días',
    'everyNDays': 'Cada {n} días',
    'weekly': 'Semanal',
    'biweekly': 'Cada 2 semanas',
    'monthly': 'Mensual',
    'bimonthly': 'Cada 2 meses',
  },
  'it': {
    'today': 'Oggi',
    'todayShort': 'Oggi',
    'yesterday': 'Ieri',
    'tomorrow': 'Domani',
    'inDays': 'Tra {n} giorni',
    'late': 'In ritardo (previsto {date})',
    'unknown': 'Sconosciuto',
    'unknownDate': 'Sconosciuta',
    'daily': 'Quotidiano',
    'every2days': 'Ogni 2 giorni',
    'everyNDays': 'Ogni {n} giorni',
    'weekly': 'Settimanale',
    'biweekly': 'Ogni 2 settimane',
    'monthly': 'Mensile',
    'bimonthly': 'Ogni 2 mesi',
  },
  'pt': {
    'today': 'Hoje',
    'todayShort': 'Hoje',
    'yesterday': 'Ontem',
    'tomorrow': 'Amanhã',
    'inDays': 'Em {n} dias',
    'late': 'Atrasado (previsto {date})',
    'unknown': 'Desconhecido',
    'unknownDate': 'Desconhecida',
    'daily': 'Diário',
    'every2days': 'A cada 2 dias',
    'everyNDays': 'A cada {n} dias',
    'weekly': 'Semanal',
    'biweekly': 'A cada 2 semanas',
    'monthly': 'Mensal',
    'bimonthly': 'A cada 2 meses',
  },
  'nl': {
    'today': 'Vandaag',
    'todayShort': 'Vandaag',
    'yesterday': 'Gisteren',
    'tomorrow': 'Morgen',
    'inDays': 'Over {n} dagen',
    'late': 'Te laat (gepland {date})',
    'unknown': 'Onbekend',
    'unknownDate': 'Onbekend',
    'daily': 'Dagelijks',
    'every2days': 'Om de 2 dagen',
    'everyNDays': 'Om de {n} dagen',
    'weekly': 'Wekelijks',
    'biweekly': 'Om de 2 weken',
    'monthly': 'Maandelijks',
    'bimonthly': 'Om de 2 maanden',
  },
  'zh': {
    'today': '今天',
    'todayShort': '今天',
    'yesterday': '昨天',
    'tomorrow': '明天',
    'inDays': '{n} 天后',
    'late': '已逾期（预计 {date}）',
    'unknown': '未知',
    'unknownDate': '未知',
    'daily': '每天',
    'every2days': '每 2 天',
    'everyNDays': '每 {n} 天',
    'weekly': '每周',
    'biweekly': '每 2 周',
    'monthly': '每月',
    'bimonthly': '每 2 个月',
  },
  'hi': {
    'today': 'आज',
    'todayShort': 'आज',
    'yesterday': 'बीता कल',
    'tomorrow': 'आने वाला कल',
    'inDays': '{n} दिनों में',
    'late': 'विलंबित (निर्धारित {date})',
    'unknown': 'अज्ञात',
    'unknownDate': 'अज्ञात',
    'daily': 'रोज़ाना',
    'every2days': 'हर 2 दिन',
    'everyNDays': 'हर {n} दिन',
    'weekly': 'साप्ताहिक',
    'biweekly': 'हर 2 सप्ताह',
    'monthly': 'मासिक',
    'bimonthly': 'हर 2 महीने',
  },
  'id': {
    'today': 'Hari ini',
    'todayShort': 'Hari ini',
    'yesterday': 'Kemarin',
    'tomorrow': 'Besok',
    'inDays': 'Dalam {n} hari',
    'late': 'Terlambat (jadwal {date})',
    'unknown': 'Tidak diketahui',
    'unknownDate': 'Tidak diketahui',
    'daily': 'Harian',
    'every2days': 'Setiap 2 hari',
    'everyNDays': 'Setiap {n} hari',
    'weekly': 'Mingguan',
    'biweekly': 'Setiap 2 minggu',
    'monthly': 'Bulanan',
    'bimonthly': 'Setiap 2 bulan',
  },
  'ja': {
    'today': '今日',
    'todayShort': '今日',
    'yesterday': '昨日',
    'tomorrow': '明日',
    'inDays': '{n}日後',
    'late': '遅延（予定 {date}）',
    'unknown': '不明',
    'unknownDate': '不明',
    'daily': '毎日',
    'every2days': '2日ごと',
    'everyNDays': '{n}日ごと',
    'weekly': '毎週',
    'biweekly': '2週間ごと',
    'monthly': '毎月',
    'bimonthly': '2か月ごと',
  },
  'ko': {
    'today': '오늘',
    'todayShort': '오늘',
    'yesterday': '어제',
    'tomorrow': '내일',
    'inDays': '{n}일 후',
    'late': '지연 (예정 {date})',
    'unknown': '알 수 없음',
    'unknownDate': '알 수 없음',
    'daily': '매일',
    'every2days': '2일마다',
    'everyNDays': '{n}일마다',
    'weekly': '매주',
    'biweekly': '2주마다',
    'monthly': '매월',
    'bimonthly': '2개월마다',
  },
  'ru': {
    'today': 'Сегодня',
    'todayShort': 'Сегодня',
    'yesterday': 'Вчера',
    'tomorrow': 'Завтра',
    'inDays': 'Через {n} дн.',
    'late': 'С опозданием (план {date})',
    'unknown': 'Неизвестно',
    'unknownDate': 'Неизвестна',
    'daily': 'Ежедневно',
    'every2days': 'Каждые 2 дня',
    'everyNDays': 'Каждые {n} дн.',
    'weekly': 'Еженедельно',
    'biweekly': 'Каждые 2 недели',
    'monthly': 'Ежемесячно',
    'bimonthly': 'Каждые 2 месяца',
  },
  'tr': {
    'today': 'Bugün',
    'todayShort': 'Bugün',
    'yesterday': 'Dün',
    'tomorrow': 'Yarın',
    'inDays': '{n} gün içinde',
    'late': 'Gecikmiş (plan {date})',
    'unknown': 'Belirsiz',
    'unknownDate': 'Belirsiz',
    'daily': 'Günlük',
    'every2days': '2 günde bir',
    'everyNDays': '{n} günde bir',
    'weekly': 'Haftalık',
    'biweekly': '2 haftada bir',
    'monthly': 'Aylık',
    'bimonthly': '2 ayda bir',
  },
  'ar': {
    'today': 'اليوم',
    'todayShort': 'اليوم',
    'yesterday': 'أمس',
    'tomorrow': 'غدًا',
    'inDays': 'خلال {n} أيام',
    'late': 'متأخر (الموعد {date})',
    'unknown': 'غير محدد',
    'unknownDate': 'غير محددة',
    'daily': 'يومي',
    'every2days': 'كل يومين',
    'everyNDays': 'كل {n} أيام',
    'weekly': 'أسبوعي',
    'biweekly': 'كل أسبوعين',
    'monthly': 'شهري',
    'bimonthly': 'كل شهرين',
  },
  'pl': {
    'today': 'Dzisiaj',
    'todayShort': 'Dzis.',
    'yesterday': 'Wczoraj',
    'tomorrow': 'Jutro',
    'inDays': 'Za {n} dni',
    'late': 'Opóźnione (plan {date})',
    'unknown': 'Nieokreślony',
    'unknownDate': 'Nieokreślona',
    'daily': 'Codziennie',
    'every2days': 'Co 2 dni',
    'everyNDays': 'Co {n} dni',
    'weekly': 'Co tydzień',
    'biweekly': 'Co 2 tygodnie',
    'monthly': 'Co miesiąc',
    'bimonthly': 'Co 2 miesiące',
  },
};

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
    while (end > match.start && '.,;:!?)]}>»"\''.contains(text[end - 1])) {
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
