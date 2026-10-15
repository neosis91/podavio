import 'dart:convert';

import 'package:http/http.dart' as http;

import 'discover_hit.dart';
import 'discover_languages.dart';
import 'feed_service.dart';

/// Recherche / suggestions fyyd (https://fyyd.de) — API publique sans clé.
class FyydSearch {
  FyydSearch({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Catégories pour peupler la grille (fyyd n’expose pas de tops globaux).
  static const _suggestionCategories = <int>[
    155, // News
    181, // Society & Culture
    115, // Comedy
    203, // Technology
    129, // History
  ];

  Future<List<DiscoverHit>> search(
    String query, {
    int count = 20,
    List<String> languages = const [discoverLanguagesAll],
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final uri = Uri.https('api.fyyd.de', '/0.2/search/podcast', {
      'title': q,
      'count': '$count',
    });
    final response = await _client
        .get(uri, headers: const {'User-Agent': podavioUserAgent})
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('fyyd a répondu ${response.statusCode}.');
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return const [];
    final data = json['data'];
    if (data is! List) return const [];
    return _hitsFromList(data, languages);
  }

  /// Suggestions via quelques catégories. Seules les langues choisies restent.
  ///
  /// [page] est l’index fyyd (0 = première page) pour enchaîner les lots.
  Future<List<DiscoverHit>> suggestions({
    int count = 24,
    int page = 0,
    List<String> languages = const [discoverLanguagesAll],
  }) async {
    final perCategory = (count / _suggestionCategories.length).ceil().clamp(
      4,
      12,
    );
    final batches = await Future.wait([
      for (final id in _suggestionCategories)
        _categoryPodcasts(
          id,
          count: perCategory,
          page: page,
          languages: languages,
        ),
    ]);

    final queues = [for (final batch in batches) List<DiscoverHit>.from(batch)];
    final seen = <String>{};
    final out = <DiscoverHit>[];
    var progress = true;
    while (out.length < count && progress) {
      progress = false;
      for (final queue in queues) {
        while (queue.isNotEmpty) {
          final hit = queue.removeAt(0);
          if (!seen.add(hit.dedupeKey)) continue;
          out.add(hit);
          progress = true;
          break;
        }
        if (out.length >= count) break;
      }
    }
    return out;
  }

  Future<List<DiscoverHit>> _categoryPodcasts(
    int categoryId, {
    required int count,
    int page = 0,
    List<String> languages = const [discoverLanguagesAll],
  }) async {
    final uri = Uri.https('api.fyyd.de', '/0.2/category', {
      'category_id': '$categoryId',
      'count': '$count',
      'page': '$page',
    });
    final response = await _client
        .get(uri, headers: const {'User-Agent': podavioUserAgent})
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) return const [];

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return const [];
    final data = json['data'];
    if (data is! Map) return const [];
    final podcasts = data['podcasts'];
    if (podcasts is! List) return const [];

    return _hitsFromList(podcasts, languages);
  }

  List<DiscoverHit> _hitsFromList(List<dynamic> data, List<String> languages) {
    final hits = <DiscoverHit>[];
    for (final raw in data) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      if (!discoverLanguageMatches(map['language'] as String?, languages)) {
        continue;
      }
      final hit = _hitFromMap(map);
      if (hit != null) hits.add(hit);
    }
    return hits;
  }

  DiscoverHit? _hitFromMap(Map<String, dynamic> map) {
    final feedUrl = (map['xmlURL'] as String?)?.trim() ?? '';
    if (feedUrl.isEmpty) return null;
    final title = (map['title'] as String?)?.trim();
    return DiscoverHit(
      title: (title == null || title.isEmpty) ? 'Podcast' : title,
      author: (map['author'] as String?)?.trim() ?? '',
      // imgURL = jaquette d’origine. Les URL img-1.fyyd.de répondent 403.
      imageUrl: _blankToNull(
        (map['imgURL'] as String?) ??
            (map['imageURL'] as String?) ??
            (map['layoutImageURL'] as String?) ??
            (map['smallImageURL'] as String?) ??
            (map['thumbImageURL'] as String?),
      ),
      feedUrl: feedUrl,
      source: DiscoverSource.fyyd,
    );
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
