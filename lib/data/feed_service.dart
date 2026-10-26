import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:podcast_search/podcast_search.dart' as remote;

import 'app_database.dart';
import 'http_auth.dart';
import 'apple_feed.dart';
import 'chapters_parser.dart';
import 'catalog_categories.dart';
import 'discover_hit.dart';
import 'discover_languages.dart';
import 'fyyd_search.dart';
import 'models.dart';
import 'podcast_index_search.dart';
import '../sync/sync_hooks.dart';
import 'spotify_feed.dart';

const podavioUserAgent = 'Podavio/0.1 (podcast player)';

/// Le serveur a répondu 401. [hadCredentials] : un identifiant a déjà été envoyé.
class FeedUnauthorizedException implements Exception {
  const FeedUnauthorizedException({this.hadCredentials = false});

  final bool hadCredentials;

  @override
  String toString() => hadCredentials
      ? 'Exception: Identifiant ou mot de passe refusé.'
      : 'Exception: Ce flux demande un identifiant et un mot de passe.';
}

bool isFeedUnauthorized(Object error) {
  if (error is FeedUnauthorizedException) return true;
  return error is remote.PodcastFailedException && error.statusCode == 401;
}

/// En-têtes à passer aux jaquettes, ou `null` si le podcast n’est pas protégé.
Map<String, String>? podcastAuthHeaders({String? username, String? password}) {
  final headers = podcastRequestHeaders(
    userAgent: podavioUserAgent,
    username: username,
    password: password,
  );
  if (!headers.containsKey('Authorization')) return null;
  return headers;
}

enum DiscoverSearchScope { combined, apple, podcastIndex, fyyd }

class FeedService {
  FeedService(this._database);

  final AppDatabase _database;
  final PodcastIndexSearch _podcastIndex = PodcastIndexSearch();
  final FyydSearch _fyyd = FyydSearch();
  final _chapterInflight = <int, Future<void>>{};
  final _chapterFailedAt = <int, DateTime>{};
  final _channelLanguages = <String, String?>{};
  static const _chapterRetryBackoff = Duration(minutes: 5);

  Future<SubscribeResult> subscribe(
    String rawUrl, {
    String? username,
    String? password,
    bool notifyNewEpisodes = false,
  }) async {
    final url = await _resolveFeedUrl(rawUrl);
    final existing = await _database.findByFeedUrl(url);
    final wasSubscribed = existing?.subscribed ?? false;
    final saved = await _refreshUrl(
      url,
      subscribed: true,
      keepUpdated: true,
      username: username,
      password: password,
    );
    final id = saved.podcastId;
    final created = existing == null || !wasSubscribed;
    if (created && notifyNewEpisodes) {
      await _database.setPodcastEpisodeNotification(id, enabled: true);
    }
    if (created) SyncHooks.reportSubscribed(url);
    return SubscribeResult(podcastId: id, created: created);
  }

  /// Charge le flux en aperçu (épisodes utilisables) sans l’ajouter à la bibliothèque.
  Future<int> preview(
    String rawUrl, {
    String? username,
    String? password,
  }) async {
    final url = await _resolveFeedUrl(rawUrl);
    final existing = await _database.findByFeedUrl(url);
    if (existing != null) {
      // Rafraîchir les épisodes sans changer le statut d’abonnement.
      return (await _refreshUrl(
        url,
        username: username,
        password: password,
      )).podcastId;
    }
    return (await _refreshUrl(
      url,
      subscribed: false,
      keepUpdated: false,
      username: username,
      password: password,
    )).podcastId;
  }

  /// Abonne plusieurs flux en parallèle (réseau), avec une limite de concurrence.
  Future<RefreshReport> subscribeMany(
    List<String> urls, {
    int concurrency = 2,
    void Function(int done, int total, List<SubscribeFailure> failures)?
    onProgress,
  }) async {
    if (urls.isEmpty) return const RefreshReport(total: 0);
    final total = urls.length;
    final workers = concurrency.clamp(1, total);
    var next = 0;
    var done = 0;
    final failures = <SubscribeFailure>[];

    Future<void> worker() async {
      while (true) {
        final index = next;
        if (index >= total) return;
        next = index + 1;
        final url = urls[index];
        try {
          await subscribe(url);
        } catch (error) {
          failures.add(
            SubscribeFailure(feedUrl: url, message: describeFeedError(error)),
          );
        }
        done++;
        onProgress?.call(done, total, List.unmodifiable(failures));
      }
    }

    await Future.wait(List.generate(workers, (_) => worker()));
    return RefreshReport(total: total, failures: List.unmodifiable(failures));
  }

  Future<SavedFeed> refresh(String feedUrl) => _refreshUrl(feedUrl);

  Future<RefreshReport> refreshAll({
    int concurrency = 2,
    bool notifyNewEpisodes = false,
    void Function(int done, int total, List<SubscribeFailure> failures)?
    onProgress,
  }) async {
    final podcasts = (await _database.listPodcasts())
        .where((podcast) => podcast.keepUpdated)
        .toList();
    if (podcasts.isEmpty) return const RefreshReport(total: 0);
    final total = podcasts.length;
    final workers = concurrency.clamp(1, total);
    var next = 0;
    var done = 0;
    final failures = <SubscribeFailure>[];
    final arrivals = <NewEpisodeArrival>[];

    Future<void> worker() async {
      while (true) {
        final index = next;
        if (index >= total) return;
        next = index + 1;
        final podcast = podcasts[index];
        try {
          final saved = await _refreshUrl(podcast.feedUrl);
          if (shouldNotifyNewEpisodes(
            notifyNewEpisodes: notifyNewEpisodes,
            keepUpdated: podcast.keepUpdated,
            episodeNotification: podcast.episodeNotification,
            newCount: saved.newEpisodeIds.length,
          )) {
            arrivals.add(
              NewEpisodeArrival(
                podcastId: podcast.id,
                title: podcast.title,
                count: saved.newEpisodeIds.length,
              ),
            );
          }
        } catch (error) {
          failures.add(
            SubscribeFailure(
              feedUrl: podcast.feedUrl,
              message: describeFeedError(error),
            ),
          );
        }
        done++;
        onProgress?.call(done, total, List.unmodifiable(failures));
      }
    }

    await Future.wait(List.generate(workers, (_) => worker()));
    return RefreshReport(
      total: total,
      failures: List.unmodifiable(failures),
      arrivals: List.unmodifiable(arrivals),
    );
  }

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

  /// Une page de podcasts pour un regroupement de catégories.
  ///
  /// Page 0 : parent seul (Apple + PI + fyyd). Pages suivantes : un membre
  /// du regroupement à la fois (parent puis sous-genres), pour que le scroll
  /// apporte encore des podcasts nouveaux.
  Future<List<DiscoverHit>> categoryHitsPage({
    required String id,
    required int page,
    int pageSize = 20,
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

    final genres = category.regroupGenres;
    final fyydIds = category.regroupFyydIds;
    final piles = <List<DiscoverHit>?>[];
    final weights = <double>[];

    if (page == 0) {
      final results = await Future.wait([
        safe(
          _appleChartHits(
            languages: languages,
            limit: pageSize,
            genre: category.genre,
          ),
        ),
        safe(
          _podcastIndex.trending(
            languages: languages,
            max: pageSize,
            category: category.genre,
          ),
        ),
        safe(
          _fyyd.category(
            category.fyydId,
            count: pageSize,
            page: 0,
            languages: languages,
          ),
        ),
      ]);
      piles.addAll(results);
      weights.addAll(const [1.0, 1.0, 0.8]);
    } else {
      final index = (page - 1) % genres.length;
      final deep = (page - 1) ~/ genres.length;
      final pair = await Future.wait([
        safe(
          _podcastIndex.trending(
            languages: languages,
            max: (deep + 2) * pageSize,
            category: genres[index],
          ),
        ),
        safe(
          _fyyd.category(
            fyydIds[index],
            count: pageSize,
            page: deep + (fyydIds[index] == category.fyydId ? 1 : 0),
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

  Future<SavedFeed> _refreshUrl(
    String url, {
    bool? subscribed,
    bool? keepUpdated,
    String? username,
    String? password,
  }) async {
    final existing = await _database.findByFeedUrl(url);
    final explicit = username != null || password != null;
    final user = explicit ? _blankToNull(username) : existing?.authUsername;
    final pass = explicit
        ? ((password ?? '').isEmpty ? null : password)
        : existing?.authPassword;
    final podcast = await _loadRemoteFeed(url, username: user, password: pass);
    final pscByKey = await _loadPscChapters(
      url,
      username: user,
      password: pass,
    );
    final saved = await _database.saveFeed(
      _draftFrom(url, podcast, pscByKey: pscByKey),
      subscribed: subscribed,
      keepUpdated: keepUpdated,
    );
    if (explicit) {
      await _database.setPodcastCredentials(
        saved.podcastId,
        username: user,
        password: pass,
      );
    }
    return saved;
  }

  Future<remote.Podcast> _loadRemoteFeed(
    String url, {
    String? username,
    String? password,
  }) async {
    final authorization = basicAuthorization(username, password);
    if (authorization == null) {
      try {
        return await remote.Feed.loadFeed(
          url: url,
          userAgent: podavioUserAgent,
          timeout: const Duration(seconds: 30),
        ).timeout(
          const Duration(seconds: 40),
          onTimeout: () {
            throw Exception('Le flux met trop de temps à répondre.');
          },
        );
      } on remote.PodcastFailedException catch (error) {
        if (error.statusCode == 401) {
          throw const FeedUnauthorizedException();
        }
        rethrow;
      }
    }

    final response = await getKeepingAuthorization(
      Uri.parse(url),
      headers: {'User-Agent': podavioUserAgent, 'Authorization': authorization},
      timeout: const Duration(seconds: 40),
    );
    if (response.statusCode == 401) {
      throw const FeedUnauthorizedException(hadCredentials: true);
    }
    if (response.statusCode != 200 || response.body.isEmpty) {
      throw Exception('Erreur HTTP ${response.statusCode}');
    }

    final directory = await Directory.systemTemp.createTemp('podavio-feed-');
    try {
      final file = File('${directory.path}/feed.xml');
      await file.writeAsString(response.body);
      return await remote.Feed.loadFeedFile(file: file.path);
    } finally {
      await directory.delete(recursive: true);
    }
  }

  Future<Map<String, List<ChapterDraft>>> _loadPscChapters(
    String url, {
    String? username,
    String? password,
  }) async {
    try {
      final headers = podcastRequestHeaders(
        userAgent: podavioUserAgent,
        username: username,
        password: password,
      );
      final response = headers.containsKey('Authorization')
          ? await getKeepingAuthorization(Uri.parse(url), headers: headers)
          : await http
                .get(Uri.parse(url), headers: headers)
                .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 || response.body.isEmpty) {
        return const {};
      }
      return parsePscChaptersByItem(response.body);
    } catch (_) {
      return const {};
    }
  }

  FeedDraft _draftFrom(
    String url,
    remote.Podcast podcast, {
    Map<String, List<ChapterDraft>> pscByKey = const {},
  }) {
    final episodes = <EpisodeDraft>[];
    for (final episode in podcast.episodes) {
      final audioUrl = episode.contentUrl?.trim() ?? '';
      if (audioUrl.isEmpty) continue;
      final guid = episode.guid.trim().isEmpty ? audioUrl : episode.guid.trim();
      final notes = _notes(episode);
      final chapters =
          pscByKey[guid] ?? pscByKey[audioUrl] ?? const <ChapterDraft>[];
      episodes.add(
        EpisodeDraft(
          guid: guid,
          title: episode.title.trim().isEmpty
              ? 'Sans titre'
              : episode.title.trim(),
          description: _bounded(notes),
          audioUrl: audioUrl,
          mimeType: episode.mimeType,
          durationSeconds: episode.duration?.inSeconds,
          publishedAt: episode.publicationDate,
          imageUrl: _blankToNull(episode.imageUrl),
          chaptersUrl: _blankToNull(episode.chapters?.url),
          chapters: chapters,
        ),
      );
    }

    final persons = [
      for (final person in podcast.persons)
        if (person.name.trim().isNotEmpty)
          PodcastPerson(
            name: person.name.trim(),
            role: _blankToNull(person.role),
            group: _blankToNull(person.group),
            image: _blankToNull(person.image),
            link: _blankToNull(person.link),
          ),
    ];
    final funding = [
      for (final item in podcast.funding)
        if ((item.url ?? '').trim().isNotEmpty)
          PodcastFunding(
            url: item.url!.trim(),
            label: _blankToNull(item.value),
          ),
    ];
    // `copyright` du package porte en pratique itunes:author.
    final itunesAuthor = podcast.copyright?.trim() ?? '';
    final author = persons.isNotEmpty
        ? persons.map((person) => person.name).join(', ')
        : itunesAuthor;

    return FeedDraft(
      feedUrl: url,
      title: _blankToNull(podcast.title) ?? url,
      author: author,
      description: _bounded(podcast.description?.trim() ?? ''),
      imageUrl: _blankToNull(podcast.image),
      link: _blankToNull(podcast.link),
      persons: persons,
      funding: funding,
      episodes: episodes,
    );
  }

  String _notes(remote.Episode episode) {
    final content = episode.content?.trim() ?? '';
    final description = episode.description.trim();
    if (content.length >= description.length) return content;
    return description;
  }

  String _bounded(String value) {
    const maxLength = 20000;
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  /// Fetch chapitres encore en cours pour cet épisode.
  bool isChaptersInflight(int episodeId) =>
      _chapterInflight.containsKey(episodeId);

  /// Dernier fetch a échoué et le backoff empêche un nouvel essai.
  bool chaptersRecentlyFailed(int episodeId) {
    final failedAt = _chapterFailedAt[episodeId];
    if (failedAt == null) return false;
    return DateTime.now().difference(failedAt) < _chapterRetryBackoff;
  }

  /// Charge et mémorise les chapitres Podcast Index d’un épisode (lazy).
  Future<void> ensureChapters(int episodeId) {
    final inflight = _chapterInflight[episodeId];
    if (inflight != null) return inflight;
    final future = _ensureChapters(episodeId).whenComplete(() {
      _chapterInflight.remove(episodeId);
    });
    _chapterInflight[episodeId] = future;
    return future;
  }

  Future<void> _ensureChapters(int episodeId) async {
    final episode = await _database.episodeById(episodeId);
    if (episode == null) return;
    if (episode.chaptersFetched) return;
    final failedAt = _chapterFailedAt[episodeId];
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < _chapterRetryBackoff) {
      return;
    }
    final url = episode.chaptersUrl?.trim() ?? '';
    if (url.isEmpty) {
      await _database.markChaptersFetched(episodeId);
      return;
    }
    try {
      final podcast = await _database.getPodcast(episode.podcastId);
      final headers = podcastRequestHeaders(
        userAgent: podavioUserAgent,
        username: podcast?.authUsername,
        password: podcast?.authPassword,
      );
      final response = headers.containsKey('Authorization')
          ? await getKeepingAuthorization(
              Uri.parse(url),
              headers: headers,
              timeout: const Duration(seconds: 20),
            )
          : await http
                .get(Uri.parse(url), headers: headers)
                .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('Chapitres HTTP ${response.statusCode}');
      }
      final parsed = parseChaptersJson(response.body);
      final rows = <EpisodeChaptersCompanion>[
        for (var i = 0; i < parsed.length; i++)
          EpisodeChaptersCompanion.insert(
            episodeId: episodeId,
            startMs: parsed[i].startMs,
            title: Value(parsed[i].title),
            link: Value(parsed[i].link),
            toc: Value(parsed[i].toc),
            sortIndex: Value(i),
          ),
      ];
      await _database.replaceChapters(episodeId, rows);
      _chapterFailedAt.remove(episodeId);
    } catch (_) {
      // Pas de markFetched : réessai après backoff.
      _chapterFailedAt[episodeId] = DateTime.now();
    }
  }

  Future<String> _resolveFeedUrl(String raw) async {
    final SpotifyShowLink link;
    try {
      final parsed = spotifyShowLink(raw);
      if (parsed == null) return _normalizeUrl(raw);
      link = parsed;
    } on FormatException {
      rethrow;
    }
    final show = await _spotifyShow(link);
    final result = await search(show.title);
    if (!result.successful) {
      throw Exception(
        result.lastError.isEmpty
            ? 'La recherche du flux public a échoué.'
            : result.lastError,
      );
    }
    final feed = matchingFeedUrl(
      title: show.title,
      author: show.author,
      candidates: [
        for (final item in result.items)
          FeedCandidate(
            title: item.collectionName ?? item.trackName ?? '',
            author: item.artistName ?? '',
            feedUrl: item.feedUrl,
          ),
      ],
    );
    if (feed == null) {
      throw Exception(
        '« ${show.title} » n’a pas de flux RSS public. Les émissions réservées à Spotify ne peuvent pas être lues dans Podavio.',
      );
    }
    return feed;
  }

  Future<SpotifyShowInfo> _spotifyShow(SpotifyShowLink link) async {
    final response = await http
        .get(
          Uri.parse(link.pageUrl),
          headers: const {
            'User-Agent': 'Mozilla/5.0 (compatible; Podavio/0.1)',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('La page Spotify n’a pas répondu.');
    }
    final show = spotifyShowFromHtml(response.body);
    if (show == null) {
      throw Exception('Impossible de reconnaître cette émission Spotify.');
    }
    return show;
  }

  String _normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Indiquez l’adresse d’un flux RSS.');
    }
    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('Cette adresse de flux n’est pas valide.');
    }
    return uri.toString();
  }
}

String describeFeedError(Object error) {
  if (error is FeedUnauthorizedException) {
    return error.hadCredentials
        ? 'Identifiant ou mot de passe refusé.'
        : 'Ce flux demande un identifiant et un mot de passe.';
  }
  if (error is remote.PodcastTimeoutException) {
    return 'Délai dépassé';
  }
  if (error is remote.PodcastCertificateException) {
    return 'Certificat HTTPS invalide';
  }
  if (error is remote.PodcastGoneException) {
    return 'Flux supprimé (${error.statusCode})';
  }

  final status = switch (error) {
    remote.PodcastFailedException(:final statusCode) => statusCode,
    remote.PodcastUnknownException(:final statusCode) => statusCode,
    remote.PodcastCancelledException(:final statusCode) => statusCode,
    _ => null,
  };
  if (status != null) {
    return switch (status) {
      404 => 'Flux introuvable (404)',
      410 => 'Flux supprimé (410)',
      401 => 'Accès non autorisé (401)',
      403 => 'Accès refusé (403)',
      408 || 504 => 'Délai dépassé ($status)',
      500 || 502 || 503 => 'Serveur indisponible ($status)',
      _ when status > 0 => 'Erreur HTTP $status',
      _ => 'Impossible de charger le flux',
    };
  }

  final text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  if (text.startsWith('FormatException: ')) return text.substring(17);
  if (text.startsWith('TimeoutException')) {
    return 'Délai dépassé';
  }
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Pas de connexion réseau';
  }
  return text;
}
