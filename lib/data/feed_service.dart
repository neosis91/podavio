import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:podcast_search/podcast_search.dart' as remote;

import 'app_database.dart';
import 'apple_feed.dart';
import 'chapters_parser.dart';
import 'discover_hit.dart';
import 'fyyd_search.dart';
import 'models.dart';
import 'podcast_index_search.dart';
import 'spotify_feed.dart';

const podavioUserAgent = 'Podavio/0.1 (podcast player)';

enum DiscoverSearchScope {
  combined,
  apple,
  podcastIndex,
  fyyd,
}

class FeedService {
  FeedService(this._database);

  final AppDatabase _database;
  final remote.Search _search = remote.Search();
  final PodcastIndexSearch _podcastIndex = PodcastIndexSearch();
  final FyydSearch _fyyd = FyydSearch();

  Future<SubscribeResult> subscribe(String rawUrl) async {
    final url = await _resolveFeedUrl(rawUrl);
    final existing = await _database.findByFeedUrl(url);
    final wasSubscribed = existing?.subscribed ?? false;
    final id = await _refreshUrl(
      url,
      subscribed: true,
      keepUpdated: true,
    );
    return SubscribeResult(
      podcastId: id,
      created: existing == null || !wasSubscribed,
    );
  }

  /// Charge le flux en aperçu (épisodes utilisables) sans l’ajouter à la bibliothèque.
  Future<int> preview(String rawUrl) async {
    final url = await _resolveFeedUrl(rawUrl);
    final existing = await _database.findByFeedUrl(url);
    if (existing != null) {
      // Rafraîchir les épisodes sans changer le statut d’abonnement.
      return _refreshUrl(url);
    }
    return _refreshUrl(url, subscribed: false, keepUpdated: false);
  }

  /// Abonne plusieurs flux en parallèle (réseau), avec une limite de concurrence.
  Future<RefreshReport> subscribeMany(
    List<String> urls, {
    int concurrency = 4,
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

  Future<int> refresh(String feedUrl) => _refreshUrl(feedUrl);

  Future<RefreshReport> refreshAll({
    int concurrency = 4,
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

    Future<void> worker() async {
      while (true) {
        final index = next;
        if (index >= total) return;
        next = index + 1;
        final podcast = podcasts[index];
        try {
          await _refreshUrl(podcast.feedUrl);
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
    return RefreshReport(total: total, failures: List.unmodifiable(failures));
  }

  Future<remote.SearchResult> search(String query) {
    return _search.search(query, country: remote.Country.france, limit: 30);
  }

  Future<remote.SearchResult> charts() {
    return _search.charts(country: remote.Country.france, limit: 24);
  }

  /// Suggestions combinées (Apple charts FR + Podcast Index trending + fyyd).
  Future<List<DiscoverHit>> discoverCharts({int limit = 24}) async {
    Future<List<DiscoverHit>?> safe(Future<List<DiscoverHit>> future) async {
      try {
        return await future;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safe(_appleChartHits()),
      safe(_podcastIndex.trending(lang: 'fr', max: limit)),
      safe(_fyyd.suggestions(count: limit)),
    ]);

    final merged = _mergeHits(results, const [1.0, 1.0, 0.8]);
    // Grille visuelle : préférer ceux qui ont une jaquette.
    final withArt = merged.where((h) => (h.imageUrl ?? '').isNotEmpty).toList();
    final without = merged.where((h) => (h.imageUrl ?? '').isEmpty).toList();
    final ordered = [...withArt, ...without];
    if (ordered.length <= limit) return ordered;
    return ordered.sublist(0, limit);
  }

  Future<List<DiscoverHit>> _appleChartHits() async {
    final result = await _search.charts(
      country: remote.Country.france,
      limit: 24,
    );
    if (!result.successful) {
      throw Exception(
        result.lastError.isEmpty ? 'La recherche a échoué.' : result.lastError,
      );
    }
    return [
      for (final item in result.items)
        DiscoverHit(
          title: item.trackName ?? item.collectionName ?? 'Podcast',
          author: item.artistName ?? '',
          imageUrl: item.bestArtworkUrl,
          feedUrl: item.feedUrl?.trim() ?? '',
          source: DiscoverSource.apple,
          appleId: item.collectionId ?? item.trackId,
        ),
    ];
  }

  /// Recherche multi-annuaires (Apple, Podcast Index, fyyd).
  Future<List<DiscoverHit>> discoverSearch(
    String query, {
    DiscoverSearchScope scope = DiscoverSearchScope.combined,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    switch (scope) {
      case DiscoverSearchScope.apple:
        return _searchAppleHits(trimmed);
      case DiscoverSearchScope.podcastIndex:
        return _podcastIndex.search(trimmed);
      case DiscoverSearchScope.fyyd:
        return _fyyd.search(trimmed);
      case DiscoverSearchScope.combined:
        return _searchCombined(trimmed);
    }
  }

  Future<List<DiscoverHit>> _searchCombined(String query) async {
    Future<List<DiscoverHit>?> safe(Future<List<DiscoverHit>> future) async {
      try {
        return await future;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safe(_searchAppleHits(query)),
      safe(_podcastIndex.search(query)),
      safe(_fyyd.search(query)),
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

  Future<List<DiscoverHit>> _searchAppleHits(String query) async {
    final result = await _search.search(
      query,
      country: remote.Country.france,
      limit: 30,
    );
    if (!result.successful) {
      throw Exception(
        result.lastError.isEmpty ? 'La recherche a échoué.' : result.lastError,
      );
    }
    return [
      for (final item in result.items)
        DiscoverHit(
          title: item.trackName ?? item.collectionName ?? 'Podcast',
          author: item.artistName ?? '',
          imageUrl: item.bestArtworkUrl,
          feedUrl: item.feedUrl?.trim() ?? '',
          source: DiscoverSource.apple,
          appleId: item.collectionId ?? item.trackId,
        ),
    ];
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

  Future<int> _refreshUrl(
    String url, {
    bool? subscribed,
    bool? keepUpdated,
  }) async {
    final podcast =
        await remote.Feed.loadFeed(
          url: url,
          userAgent: podavioUserAgent,
          timeout: const Duration(seconds: 30),
        ).timeout(
          const Duration(seconds: 40),
          onTimeout: () {
            throw Exception('Le flux met trop de temps à répondre.');
          },
        );
    final pscByKey = await _loadPscChapters(url);
    return _database.saveFeed(
      _draftFrom(url, podcast, pscByKey: pscByKey),
      subscribed: subscribed,
      keepUpdated: keepUpdated,
    );
  }

  Future<Map<String, List<ChapterDraft>>> _loadPscChapters(String url) async {
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: const {'User-Agent': podavioUserAgent},
          )
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

    final author = podcast.persons
        .map((person) => person.name.trim())
        .where((name) => name.isNotEmpty)
        .join(', ');

    return FeedDraft(
      feedUrl: url,
      title: _blankToNull(podcast.title) ?? url,
      author: author,
      description: _bounded(podcast.description?.trim() ?? ''),
      imageUrl: _blankToNull(podcast.image),
      link: _blankToNull(podcast.link),
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

  /// Charge et mémorise les chapitres Podcast Index d’un épisode (lazy).
  Future<void> ensureChapters(int episodeId) async {
    final episode = await _database.episodeById(episodeId);
    if (episode == null) return;
    if (episode.chaptersFetched) return;
    final url = episode.chaptersUrl?.trim() ?? '';
    if (url.isEmpty) {
      await _database.markChaptersFetched(episodeId);
      return;
    }
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: const {'User-Agent': podavioUserAgent},
          )
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
    } catch (_) {
      // Réessai possible plus tard (UA / réseau).
      await _database.markChaptersFetched(episodeId);
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
