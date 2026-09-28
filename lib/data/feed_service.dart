import 'package:podcast_search/podcast_search.dart' as remote;

import 'app_database.dart';
import 'models.dart';

const podavioUserAgent = 'Podavio/0.1 (podcast player)';

class FeedService {
  FeedService(this._database);

  final AppDatabase _database;
  final remote.Search _search = remote.Search();

  Future<SubscribeResult> subscribe(String rawUrl) async {
    final url = _normalizeUrl(rawUrl);
    final existing = await _database.findByFeedUrl(url);
    final id = await _refreshUrl(url);
    return SubscribeResult(podcastId: id, created: existing == null);
  }

  Future<int> refresh(String feedUrl) => _refreshUrl(feedUrl);

  Future<RefreshReport> refreshAll() async {
    final podcasts = await _database.listPodcasts();
    var failed = 0;
    for (final podcast in podcasts) {
      try {
        await _refreshUrl(podcast.feedUrl);
      } catch (_) {
        failed++;
      }
    }
    return RefreshReport(total: podcasts.length, failed: failed);
  }

  Future<remote.SearchResult> search(String query) {
    return _search.search(query, country: remote.Country.france, limit: 30);
  }

  Future<remote.SearchResult> charts() {
    return _search.charts(country: remote.Country.france, limit: 24);
  }

  Future<int> _refreshUrl(String url) async {
    final podcast = await remote.Feed.loadFeed(
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
          title: episode.title.trim().isEmpty ? 'Sans titre' : episode.title.trim(),
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
