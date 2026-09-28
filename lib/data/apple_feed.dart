final _appleFeedUrl = RegExp(r'"feedUrl"\s*:\s*"(https?:[^"]+)"');

/// Apple’s search API omits `feedUrl` for some shows. The public podcast
/// page still embeds the RSS address as JSON.
String? appleFeedUrlFromPage(String html) {
  final match = _appleFeedUrl.firstMatch(html);
  if (match == null) return null;
  final raw = _unescape(match.group(1)!);
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  if (uri.host.endsWith('apple.com')) return null;
  return uri.toString();
}

String _unescape(String value) {
  return value
      .replaceAll(r'\/', '/')
      .replaceAllMapped(
        RegExp(r'\\u([0-9a-fA-F]{4})'),
        (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
      );
}
