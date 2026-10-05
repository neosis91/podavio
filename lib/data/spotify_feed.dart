import '../core/search.dart';

class SpotifyShowLink {
  const SpotifyShowLink(this.pageUrl);

  final String pageUrl;
}

class SpotifyShowInfo {
  const SpotifyShowInfo({required this.title, required this.author});

  final String title;
  final String author;
}

class FeedCandidate {
  const FeedCandidate({
    required this.title,
    required this.author,
    required this.feedUrl,
  });

  final String title;
  final String author;
  final String? feedUrl;
}

/// Page publique d’une émission. Un lien d’épisode n’est pas une émission.
SpotifyShowLink? spotifyShowLink(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final uriLink = RegExp(
    r'^spotify:show:([A-Za-z0-9]+)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (uriLink != null) {
    return SpotifyShowLink('https://open.spotify.com/show/${uriLink.group(1)}');
  }
  final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase();
  if (host != 'open.spotify.com' && host != 'spotify.com') return null;
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isNotEmpty && segments.first.toLowerCase().startsWith('intl-')) {
    segments.removeAt(0);
  }
  if (segments.length < 2) return null;
  final kind = segments.first.toLowerCase();
  final id = segments[1];
  if (kind == 'episode') {
    throw const FormatException(
      'Collez le lien de l’émission Spotify, pas celui d’un épisode.',
    );
  }
  if (kind != 'show' || id.isEmpty) return null;
  return SpotifyShowLink('https://open.spotify.com/show/$id');
}

SpotifyShowInfo? spotifyShowFromHtml(String html) {
  final title = _meta(html, 'og:title');
  if (title == null || title.isEmpty) return null;
  final description = _meta(html, 'og:description') ?? '';
  return SpotifyShowInfo(title: title, author: _author(description));
}

String? matchingFeedUrl({
  required String title,
  required String author,
  required List<FeedCandidate> candidates,
}) {
  final wanted = foldName(title);
  final wantedAuthor = foldName(author);
  if (wanted.isEmpty) return null;
  String? sameTitle;
  for (final candidate in candidates) {
    final feed = candidate.feedUrl?.trim() ?? '';
    if (feed.isEmpty) continue;
    if (foldName(candidate.title) != wanted) continue;
    final candidateAuthor = foldName(candidate.author);
    if (wantedAuthor.isNotEmpty &&
        candidateAuthor.isNotEmpty &&
        (candidateAuthor.contains(wantedAuthor) ||
            wantedAuthor.contains(candidateAuthor))) {
      return feed;
    }
    sameTitle ??= feed;
  }
  return sameTitle;
}

String foldName(String value) {
  return foldForSearch(value).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String? _meta(String html, String property) {
  final match = RegExp(
    'property="$property"\\s+content="([^"]*)"',
    caseSensitive: false,
  ).firstMatch(html);
  final value = match?.group(1);
  if (value == null) return null;
  return _decode(value).trim();
}

String _author(String description) {
  final parts = description
      .split('·')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2 && parts.first.toLowerCase() == 'podcast') {
    return parts[1];
  }
  return '';
}

String _decode(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
