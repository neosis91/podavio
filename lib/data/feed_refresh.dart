import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:podcast_search/podcast_search.dart' as remote;

import '../sync/sync_hooks.dart';
import 'app_database.dart';
import 'chapters_parser.dart';
import 'discover_catalog.dart';
import 'discover_languages.dart';
import 'feed_service.dart';
import 'feed_text.dart';
import 'http_auth.dart';
import 'models.dart';
import 'spotify_feed.dart';

/// Abonnement et rafraîchissement des flux RSS.
class FeedRefresh {
  FeedRefresh(this._database, this._catalog);

  final AppDatabase _database;
  final DiscoverCatalog _catalog;

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
    Future<void> Function()? beforeEach,
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
        if (beforeEach != null) await beforeEach();
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
    final loaded = await _loadRemoteFeed(url, username: user, password: pass);
    final pscByKey = await _loadPscChapters(
      url,
      username: user,
      password: pass,
    );
    final saved = await _database.saveFeed(
      _draftFrom(
        url,
        loaded.podcast,
        categories: loaded.categories,
        pscByKey: pscByKey,
      ),
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

  Future<({remote.Podcast podcast, List<String> categories})> _loadRemoteFeed(
    String url, {
    String? username,
    String? password,
  }) async {
    final headers = podcastRequestHeaders(
      userAgent: podavioUserAgent,
      username: username,
      password: password,
    );
    final http.Response response;
    try {
      response = headers.containsKey('Authorization')
          ? await getKeepingAuthorization(
              Uri.parse(url),
              headers: headers,
              timeout: const Duration(seconds: 40),
            )
          : await http
                .get(Uri.parse(url), headers: headers)
                .timeout(const Duration(seconds: 40));
    } on remote.PodcastFailedException catch (error) {
      if (error.statusCode == 401) {
        throw FeedUnauthorizedException(
          hadCredentials: headers.containsKey('Authorization'),
        );
      }
      rethrow;
    } on TimeoutException {
      throw Exception('Le flux met trop de temps à répondre.');
    }
    if (response.statusCode == 401) {
      throw FeedUnauthorizedException(
        hadCredentials: headers.containsKey('Authorization'),
      );
    }
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('Erreur HTTP ${response.statusCode}');
    }

    final document = decodeFeedDocument(
      response.bodyBytes,
      contentType: response.headers['content-type'],
    );
    final categories = rssChannelCategories(document);
    final directory = await Directory.systemTemp.createTemp('podavio-feed-');
    try {
      final file = File('${directory.path}/feed.xml');
      await file.writeAsString(document);
      final podcast = await remote.Feed.loadFeedFile(file: file.path);
      return (podcast: podcast, categories: categories);
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
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return const {};
      }
      return parsePscChaptersByItem(
        decodeFeedDocument(
          response.bodyBytes,
          contentType: response.headers['content-type'],
        ),
      );
    } catch (_) {
      return const {};
    }
  }

  FeedDraft _draftFrom(
    String url,
    remote.Podcast podcast, {
    List<String> categories = const [],
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
              : repairMojibake(episode.title.trim()),
          description: repairMojibake(_bounded(notes)),
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
      title: repairMojibake(_blankToNull(podcast.title) ?? url),
      author: repairMojibake(author),
      description: repairMojibake(_bounded(podcast.description?.trim() ?? '')),
      imageUrl: _blankToNull(podcast.image),
      link: _blankToNull(podcast.link),
      persons: persons,
      funding: funding,
      categories: categories,
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
    final result = await _catalog.search(show.title);
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
