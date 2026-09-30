import 'package:http/http.dart' as http;
import 'package:podcast_search/podcast_search.dart' as remote;

import 'app_database.dart';
import 'apple_feed.dart';
import 'models.dart';
import 'spotify_feed.dart';

const podavioUserAgent = 'Podavio/0.1 (podcast player)';

class FeedService {
  FeedService(this._database);

  final AppDatabase _database;
  final remote.Search _search = remote.Search();

  Future<SubscribeResult> subscribe(String rawUrl) async {
    final url = await _resolveFeedUrl(rawUrl);
    final existing = await _database.findByFeedUrl(url);
    final id = await _refreshUrl(url);
    return SubscribeResult(podcastId: id, created: existing == null);
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
    final podcasts = await _database.listPodcasts();
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

  Future<int> _refreshUrl(String url) async {
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
    return _database.saveFeed(_draftFrom(url, podcast));
  }

  FeedDraft _draftFrom(String url, remote.Podcast podcast) {
    final episodes = <EpisodeDraft>[];
    for (final episode in podcast.episodes) {
      final audioUrl = episode.contentUrl?.trim() ?? '';
      if (audioUrl.isEmpty) continue;
      final guid = episode.guid.trim().isEmpty ? audioUrl : episode.guid.trim();
      final notes = _notes(episode);
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
