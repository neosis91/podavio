import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'catalog_categories.dart';
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
  /// Catégories des tendances des [sinceDays] derniers jours, une par podcast.
  Future<List<String>> trendingCategoryIds({
    List<String> languages = const [discoverLanguagesAll],
    int max = 100,
    int sinceDays = 30,
  }) async {
    final codes = podcastIndexLanguageQuery(languages);
    final feeds = await _feedList('/api/1.0/podcasts/trending', {
      'max': '$max',
      'since': '${-sinceDays * 24 * 3600}',
      if (codes.isNotEmpty) 'lang': codes.join(','),
    });
    final ids = <String>[];
    for (final map in feeds) {
      if (!discoverLanguageMatches(map['language'] as String?, languages)) {
        continue;
      }
      final seen = <String>{};
      final categories = map['categories'];
      if (categories is Map) {
        for (final value in categories.values) {
          if (value is! String) continue;
          final id = catalogIdFromGenreName(value);
          if (id != null) seen.add(id);
        }
      }
      ids.addAll(seen);
    }
    return ids;
  }

  Future<List<DiscoverHit>> trending({
    List<String> languages = const [discoverLanguagesAll],
    int max = 24,
    String category = '',
  }) {
    final codes = podcastIndexLanguageQuery(languages);
    final cat = category.trim();
    return _feeds('/api/1.0/podcasts/trending', {
      'max': '$max',
      if (codes.isNotEmpty) 'lang': codes.join(','),
      if (cat.isNotEmpty) 'cat': cat,
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

    final feeds = await _feedList(path, query);
    final hits = <DiscoverHit>[];
    for (final map in feeds) {
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
          episodeCount: _positiveInt(map['episodeCount']),
          lastEpisodeAt: _unixDate(
            map['newestItemPubdate'] ?? map['lastUpdate'],
          ),
        ),
      );
    }
    return hits;
  }

  Future<List<Map<String, dynamic>>> _feedList(
    String path,
    Map<String, String> query,
  ) async {
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

    return [
      for (final raw in feeds)
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static int? _positiveInt(Object? value) {
    final n = switch (value) {
      final int i => i,
      final num n => n.toInt(),
      final String s => int.tryParse(s.trim()),
      _ => null,
    };
    if (n == null || n <= 0) return null;
    return n;
  }

  static DateTime? _unixDate(Object? value) {
    final seconds = switch (value) {
      final int i => i,
      final num n => n.toInt(),
      final String s => int.tryParse(s.trim()),
      _ => null,
    };
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }
}
