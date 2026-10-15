import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'discover_hit.dart';
import 'discover_languages.dart';
import 'feed_service.dart';

/// Recherche / tendances Podcast Index (https://podcastindex.org).
///
/// Clés : `--dart-define=PODCASTINDEX_API_KEY=…` et `PODCASTINDEX_API_SECRET=…`
/// (gratuit sur https://api.podcastindex.org). Sinon clés FOSS publiées par
/// AntennaPod (fallback open-source).
class PodcastIndexSearch {
  PodcastIndexSearch({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _apiKey = String.fromEnvironment(
    'PODCASTINDEX_API_KEY',
    defaultValue: 'XTMMQGA2YZ4WJUBYY4HK',
  );
  static const _apiSecret = String.fromEnvironment(
    'PODCASTINDEX_API_SECRET',
    defaultValue: 'XAaAhk4^2YBsTE33vdbwbZNj82ZRLABDDqFdKe7x',
  );

  Future<List<DiscoverHit>> search(
    String query, {
    int max = 30,
    List<String> languages = const [discoverLanguagesAll],
  }) {
    return _feeds('/api/1.0/search/byterm', {
      'q': query.trim(),
      'max': '$max',
    }, languages: languages);
  }

  /// Tendances Podcast Index. [languages] vide ou `*` : pas de filtre `lang`.
  Future<List<DiscoverHit>> trending({
    List<String> languages = const [discoverLanguagesAll],
    int max = 24,
  }) {
    final codes = podcastIndexLanguageQuery(languages);
    return _feeds('/api/1.0/podcasts/trending', {
      'max': '$max',
      if (codes.isNotEmpty) 'lang': codes.join(','),
    }, languages: languages);
  }

  Future<List<DiscoverHit>> _feeds(
    String path,
    Map<String, String> query, {
    List<String> languages = const [discoverLanguagesAll],
  }) async {
    if (query.containsKey('q') && (query['q'] ?? '').trim().isEmpty) {
      return const [];
    }

    final uri = Uri.https('api.podcastindex.org', path, query);
    final now = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final auth = sha1
        .convert(utf8.encode('$_apiKey$_apiSecret$now'))
        .toString();

    final response = await _client
        .get(
          uri,
          headers: {
            'User-Agent': podavioUserAgent,
            'X-Auth-Key': _apiKey,
            'X-Auth-Date': now,
            'Authorization': auth,
          },
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Podcast Index a répondu ${response.statusCode}.');
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return const [];
    final feeds = json['feeds'];
    if (feeds is! List) return const [];

    final hits = <DiscoverHit>[];
    for (final raw in feeds) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final feedUrl = (map['url'] as String?)?.trim() ?? '';
      if (feedUrl.isEmpty) continue;
      if (!discoverLanguageMatches(map['language'] as String?, languages)) {
        continue;
      }
      final title = (map['title'] as String?)?.trim();
      hits.add(
        DiscoverHit(
          title: (title == null || title.isEmpty) ? 'Podcast' : title,
          author: (map['author'] as String?)?.trim() ?? '',
          imageUrl: _blankToNull(
            (map['image'] as String?) ?? (map['artwork'] as String?),
          ),
          feedUrl: feedUrl,
          source: DiscoverSource.podcastIndex,
        ),
      );
    }
    return hits;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
