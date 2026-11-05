import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:podcast_search/podcast_search.dart' as remote;

import 'app_database.dart';
import 'apple_feed.dart';
import 'catalog_categories.dart';
import 'discover_hit.dart';
import 'discover_languages.dart';
import 'feed_service.dart';
import 'fyyd_search.dart';
import 'http_auth.dart';
import 'podcast_index_search.dart';

/// Recherche et classements (Apple, Podcast Index, fyyd).
class DiscoverCatalog {
  DiscoverCatalog(this._database);

  final AppDatabase _database;
  final PodcastIndexSearch _podcastIndex = PodcastIndexSearch();
  final FyydSearch _fyyd = FyydSearch();
  final _channelLanguages = <String, String?>{};
  final _categoryQueue = <Podcast>[];
  final _categoryInflight = <int>{};
  final _categoryFailedAt = <int, DateTime>{};
  var _categoryRunning = 0;
  static const _categoryRetryBackoff = Duration(minutes: 10);
  static const _categoryConcurrency = 3;

  Future<remote.SearchResult> search(
    String query, {
    List<String> languages = const [discoverLanguagesAll],
  }) {
    final stores = appleSearchStores(languages);
    final country = stores.isEmpty ? remote.Country.none : stores.first;
    return remote.Search().search(query, country: country, limit: 30);
  }

  Future<remote.SearchResult> charts({
    List<String> languages = const [discoverLanguagesAll],
  }) {
    final stores = appleChartStores(languages);
    final country = stores.isEmpty ? remote.Country.unitedStates : stores.first;
    return remote.Search().charts(country: country, limit: 24);
  }

  /// Suggestions combinées (Apple, Podcast Index, fyyd).
  Future<List<DiscoverHit>> discoverCharts({
    int limit = 24,
    List<String> languages = const [discoverLanguagesAll],
  }) async {
    Future<List<DiscoverHit>?> safe(Future<List<DiscoverHit>> future) async {
      try {
        return await future;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safe(_appleChartHits(languages: languages)),
      safe(_podcastIndex.trending(languages: languages, max: limit)),
      safe(_fyyd.suggestions(count: limit, languages: languages)),
    ]);

    final merged = _mergeHits(results, const [1.0, 1.0, 0.8]);
    // Grille visuelle : préférer ceux qui ont une jaquette.
    final withArt = merged.where((h) => (h.imageUrl ?? '').isNotEmpty).toList();
    final without = merged.where((h) => (h.imageUrl ?? '').isEmpty).toList();
    final ordered = [...withArt, ...without];
    if (ordered.length <= limit) return ordered;
    return ordered.sublist(0, limit);
  }

  /// Une page de suggestions. La page 0 mêle les tops Apple ; les suivantes
  /// avancent dans Podcast Index (top élargi) et fyyd (page suivante).
  Future<List<DiscoverHit>> discoverChartsPage({
    required int page,
    int pageSize = 16,
    List<String> languages = const [discoverLanguagesAll],
  }) async {
    Future<List<DiscoverHit>?> safe(Future<List<DiscoverHit>> future) async {
      try {
        return await future;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safe(
        page == 0
            ? _appleChartHits(languages: languages)
            : Future.value(const <DiscoverHit>[]),
      ),
      safe(
        _podcastIndex.trending(
          languages: languages,
          max: (page + 1) * pageSize,
        ),
      ),
      safe(
        _fyyd.suggestions(count: pageSize, page: page, languages: languages),
      ),
    ]);

    final merged = _mergeHits(results, const [1.0, 1.0, 0.8]);
    final withArt = merged.where((h) => (h.imageUrl ?? '').isNotEmpty).toList();
    final without = merged.where((h) => (h.imageUrl ?? '').isEmpty).toList();
    return [...withArt, ...without];
  }

  Future<List<DiscoverHit>> _appleChartHits({
    List<String> languages = const [discoverLanguagesAll],
    int limit = 24,
    String genre = '',
  }) {
    return _appleFromStores(appleChartStores(languages), (country) async {
      final result = await remote.Search().charts(
        country: country,
        limit: limit,
        genre: genre,
      );
      return _appleHits(result, languages);
    });
  }

  /// Genres les plus présents dans les classements du mois : tops Apple et
  /// tendances Podcast Index des 30 derniers jours.
  Future<List<String>> mostPlayedCategoryIds(List<String> languages) async {
    final batches = await Future.wait([
      _appleChartCategoryIds(languages),
      () async {
        try {
          return await _podcastIndex.trendingCategoryIds(languages: languages);
        } catch (_) {
          return const <String>[];
        }
      }(),
    ]);
    final ids = [for (final batch in batches) ...batch];
    if (ids.isEmpty) {
      throw Exception('La recherche a échoué.');
    }
    return rankPlayedCategories(ids);
  }

  Future<List<String>> _appleChartCategoryIds(List<String> languages) async {
    final batches = await Future.wait([
      for (final store in appleChartStores(languages))
        _appleStoreCategoryIds(store),
    ]);
    return [for (final batch in batches) ...batch];
  }

  Future<List<String>> _appleStoreCategoryIds(remote.Country store) async {
    if (store.code.isEmpty) return const [];
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://itunes.apple.com/${store.code}/rss/toppodcasts/limit=100/json',
            ),
            headers: const {'User-Agent': podavioUserAgent},
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return const [];
      return catalogIdsFromAppleChart(jsonDecode(response.body));
    } catch (_) {
      return const [];
    }
  }

  /// Trois rangées pour une catégorie : classements Apple, tendances
  /// Podcast Index, liste fyyd. Une source en échec est absente. Toutes en
  /// échec, la future échoue.
  Future<List<HomeCategoryShelf>> categoryShelves(
    String id, {
    List<String> languages = const [discoverLanguagesAll],
  }) async {
    final category = catalogCategoryById(id);
    if (category == null) return const [];

    Future<List<DiscoverHit>?> safe(Future<List<DiscoverHit>> future) async {
      try {
        return await future;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safe(
        _appleChartHits(languages: languages, limit: 18, genre: category.genre),
      ),
      safe(
        _podcastIndex.trending(
          languages: languages,
          max: 18,
          category: category.genre,
        ),
      ),
      safe(_fyyd.category(category.fyydId, count: 18, languages: languages)),
    ]);
    if (results.every((list) => list == null)) {
      throw Exception('La recherche a échoué.');
    }

    const sources = [
      DiscoverSource.apple,
      DiscoverSource.podcastIndex,
      DiscoverSource.fyyd,
    ];
    return [
      for (var i = 0; i < results.length; i++)
        if (results[i] != null && results[i]!.isNotEmpty)
          HomeCategoryShelf(source: sources[i], hits: results[i]!),
    ];
  }

  /// Une page de podcasts pour les sujets choisis d’une catégorie.
  ///
  /// Page 0 : le premier sujet (Apple + PI + fyyd). Pages suivantes : un
  /// sujet à la fois, pour que le scroll apporte encore des podcasts nouveaux.
  /// [subjects] vide ou absent : le regroupement par défaut.
  Future<List<DiscoverHit>> categoryHitsPage({
    required String id,
    required int page,
    int pageSize = 20,
    List<String> languages = const [discoverLanguagesAll],
    List<CatalogMember>? subjects,
  }) async {
    final category = catalogCategoryById(id);
    if (category == null) return const [];

    Future<List<DiscoverHit>?> safe(Future<List<DiscoverHit>> future) async {
      try {
        return await future;
      } catch (_) {
        return null;
      }
    }

    final members = (subjects == null || subjects.isEmpty)
        ? category.regroupMembers
        : subjects;
    final piles = <List<DiscoverHit>?>[];
    final weights = <double>[];

    if (page == 0) {
      final first = members.first;
      final results = await Future.wait([
        safe(
          _appleChartHits(
            languages: languages,
            limit: pageSize,
            genre: first.genre,
          ),
        ),
        safe(
          _podcastIndex.trending(
            languages: languages,
            max: pageSize,
            category: first.genre,
          ),
        ),
        safe(
          _fyyd.category(
            first.fyydId,
            count: pageSize,
            page: 0,
            languages: languages,
          ),
        ),
      ]);
      piles.addAll(results);
      weights.addAll(const [1.0, 1.0, 0.8]);
    } else {
      final index = (page - 1) % members.length;
      final deep = (page - 1) ~/ members.length;
      final member = members[index];
      final pair = await Future.wait([
        safe(
          _podcastIndex.trending(
            languages: languages,
            max: (deep + 2) * pageSize,
            category: member.genre,
          ),
        ),
        safe(
          _fyyd.category(
            member.fyydId,
            count: pageSize,
            page: deep + (index == 0 ? 1 : 0),
            languages: languages,
          ),
        ),
      ]);
      piles.addAll(pair);
      weights.addAll(const [1.0, 0.8]);
    }

    if (piles.every((list) => list == null)) {
      throw Exception('La recherche a échoué.');
    }
    return _mergeHits(piles, weights);
  }

  /// Recherche multi-annuaires (Apple, Podcast Index, fyyd).
  Future<List<DiscoverHit>> discoverSearch(
    String query, {
    DiscoverSearchScope scope = DiscoverSearchScope.combined,
    List<String> languages = const [discoverLanguagesAll],
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    switch (scope) {
      case DiscoverSearchScope.apple:
        return _searchAppleHits(trimmed, languages);
      case DiscoverSearchScope.podcastIndex:
        return _podcastIndex.search(trimmed, languages: languages);
      case DiscoverSearchScope.fyyd:
        return _fyyd.search(trimmed, languages: languages);
      case DiscoverSearchScope.combined:
        return _searchCombined(trimmed, languages);
    }
  }

  Future<List<DiscoverHit>> _searchCombined(
    String query,
    List<String> languages,
  ) async {
    Future<List<DiscoverHit>?> safe(Future<List<DiscoverHit>> future) async {
      try {
        return await future;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safe(_searchAppleHits(query, languages)),
      safe(_podcastIndex.search(query, languages: languages)),
      safe(_fyyd.search(query, languages: languages)),
    ]);

    return _mergeHits(results, const [1.0, 1.0, 0.8]);
  }

  /// Pondération proche d’AntennaPod CombinedSearcher.
  List<DiscoverHit> _mergeHits(
    List<List<DiscoverHit>?> results,
    List<double> weights,
  ) {
    final ranking = <String, double>{};
    final byKey = <String, DiscoverHit>{};

    for (var provider = 0; provider < results.length; provider++) {
      final list = results[provider];
      if (list == null) continue;
      final weight = weights[provider];
      for (var i = 0; i < list.length; i++) {
        final hit = list[i];
        final key = hit.dedupeKey;
        byKey.putIfAbsent(key, () => hit);
        ranking[key] = (ranking[key] ?? 0) + weight / (i + 1);
      }
    }

    final sorted = ranking.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted) byKey[e.key]!];
  }

  Future<List<DiscoverHit>> _searchAppleHits(
    String query,
    List<String> languages,
  ) {
    return _appleFromStores(appleSearchStores(languages), (country) async {
      final result = await remote.Search().search(
        query,
        country: country,
        limit: 30,
      );
      return _appleHits(result, languages);
    });
  }

  Future<List<DiscoverHit>> _appleFromStores(
    List<remote.Country> stores,
    Future<List<DiscoverHit>> Function(remote.Country country) fetch,
  ) async {
    if (stores.isEmpty) return const [];
    final results = await Future.wait([
      for (final store in stores)
        () async {
          try {
            return await fetch(store);
          } catch (_) {
            return null;
          }
        }(),
    ]);
    if (results.every((list) => list == null)) {
      throw Exception('La recherche a échoué.');
    }
    return _mergeHits(results, [for (final _ in stores) 1.0]);
  }

  Future<List<DiscoverHit>> _appleHits(
    remote.SearchResult result,
    List<String> languages,
  ) async {
    if (!result.successful) {
      throw Exception(
        result.lastError.isEmpty ? 'La recherche a échoué.' : result.lastError,
      );
    }
    final hits = [
      for (final item in result.items)
        DiscoverHit(
          title: item.trackName ?? item.collectionName ?? 'Podcast',
          author: item.artistName ?? '',
          imageUrl: item.bestArtworkUrl,
          feedUrl: item.feedUrl?.trim() ?? '',
          source: DiscoverSource.apple,
          appleId: item.collectionId ?? item.trackId,
          episodeCount: item.trackCount,
          lastEpisodeAt: item.releaseDate,
        ),
    ];
    if (discoverLanguagesAreAll(languages) || hits.isEmpty) return hits;

    // La boutique est un pays, pas une langue : tagesschau est dans le store FR.
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final checked = await Future.wait([
        for (final hit in hits) _appleHitIfLanguage(client, hit, languages),
      ]);
      return [for (final hit in checked) ?hit];
    } finally {
      client.close(force: true);
    }
  }

  Future<DiscoverHit?> _appleHitIfLanguage(
    HttpClient client,
    DiscoverHit hit,
    List<String> languages,
  ) async {
    final url = hit.feedUrl.trim();
    if (url.isEmpty) return hit;
    final read = await _channelLanguage(client, url);
    if (!read.reached) return hit;
    if (!discoverLanguageMatches(read.language, languages)) return null;
    return hit;
  }

  Future<({bool reached, String? language})> _channelLanguage(
    HttpClient client,
    String url,
  ) async {
    if (_channelLanguages.containsKey(url)) {
      return (reached: true, language: _channelLanguages[url]);
    }
    final read = await _fetchChannelLanguage(client, url);
    if (read.reached) _channelLanguages[url] = read.language;
    return read;
  }

  /// Lit le début du flux jusqu’à la langue du channel. Un échec réseau
  /// laisse le résultat visible ; une langue absente l’écarte.
  Future<({bool reached, String? language})> _fetchChannelLanguage(
    HttpClient client,
    String url,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return (reached: false, language: null);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 6));
      request.followRedirects = true;
      request.headers.set(HttpHeaders.userAgentHeader, podavioUserAgent);
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        return (reached: false, language: null);
      }
      final buffer = StringBuffer();
      var bytes = 0;
      const maxBytes = 64 * 1024;
      await for (final chunk in response.timeout(const Duration(seconds: 8))) {
        bytes += chunk.length;
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        final text = buffer.toString();
        final language = rssChannelLanguage(text);
        if (language != null) return (reached: true, language: language);
        if (text.toLowerCase().contains('<item')) {
          return (reached: true, language: null);
        }
        if (bytes >= maxBytes) return (reached: false, language: null);
      }
      final text = buffer.toString();
      if (text.trim().isEmpty) return (reached: false, language: null);
      return (reached: true, language: rssChannelLanguage(text));
    } catch (_) {
      return (reached: false, language: null);
    }
  }

  /// Resolves the public RSS address when iTunes search omitted it.
  Future<String> feedUrlForAppleShow(int id) async {
    final response = await http
        .get(
          Uri.parse('https://podcasts.apple.com/podcast/id$id'),
          headers: const {
            'User-Agent': 'Mozilla/5.0 (compatible; Podavio/0.1)',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('La page Apple Podcasts n’a pas répondu.');
    }
    final feed = appleFeedUrlFromPage(response.body);
    if (feed == null) {
      throw Exception(
        'Ce podcast n’a pas de flux RSS public. Podavio ne peut pas s’y abonner.',
      );
    }
    return feed;
  }

  /// Lit les genres des abonnements qui n’en ont pas encore. Un échec réseau
  /// est retenté plus tard ; une lecture aboutie, même vide, est mémorisée.
  void backfillPodcastCategories(List<Podcast> pending) {
    final queued = {for (final podcast in _categoryQueue) podcast.id};
    for (final podcast in pending) {
      if (podcast.categoriesJson != null) continue;
      if (queued.contains(podcast.id) ||
          _categoryInflight.contains(podcast.id)) {
        continue;
      }
      final failedAt = _categoryFailedAt[podcast.id];
      if (failedAt != null &&
          DateTime.now().difference(failedAt) < _categoryRetryBackoff) {
        continue;
      }
      _categoryQueue.add(podcast);
      queued.add(podcast.id);
    }
    _pumpCategoryQueue();
  }

  void _pumpCategoryQueue() {
    while (_categoryRunning < _categoryConcurrency &&
        _categoryQueue.isNotEmpty) {
      final podcast = _categoryQueue.removeAt(0);
      _categoryRunning++;
      _categoryInflight.add(podcast.id);
      unawaited(
        _backfillCategory(podcast).whenComplete(() {
          _categoryRunning--;
          _categoryInflight.remove(podcast.id);
          _pumpCategoryQueue();
        }),
      );
    }
  }

  Future<void> _backfillCategory(Podcast podcast) async {
    try {
      final categories = await _fetchChannelCategories(
        podcast.feedUrl,
        username: podcast.authUsername,
        password: podcast.authPassword,
      );
      if (categories == null) {
        _categoryFailedAt[podcast.id] = DateTime.now();
        return;
      }
      _categoryFailedAt.remove(podcast.id);
      await _database.setPodcastCategoriesIfMissing(podcast.id, categories);
    } catch (_) {
      _categoryFailedAt[podcast.id] = DateTime.now();
    }
  }

  /// `null` si le début du flux n’a pas pu être lu. Une liste vide : aucun genre.
  Future<List<String>?> _fetchChannelCategories(
    String url, {
    String? username,
    String? password,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      request.followRedirects = true;
      request.headers.set(HttpHeaders.userAgentHeader, podavioUserAgent);
      final authorization = basicAuthorization(username, password);
      if (authorization != null) {
        request.headers.set(HttpHeaders.authorizationHeader, authorization);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        return null;
      }
      final buffer = StringBuffer();
      var bytes = 0;
      const maxBytes = 256 * 1024;
      await for (final chunk in response.timeout(const Duration(seconds: 12))) {
        bytes += chunk.length;
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        final text = buffer.toString();
        if (text.toLowerCase().contains('<item')) {
          return rssChannelCategories(text);
        }
        if (bytes >= maxBytes) {
          final found = rssChannelCategories(text);
          return found.isEmpty ? null : found;
        }
      }
      final text = buffer.toString();
      if (text.trim().isEmpty) return null;
      return rssChannelCategories(text);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
