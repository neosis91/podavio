import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import 'app_database.dart';
import 'chapters_parser.dart';
import 'feed_service.dart';
import 'http_auth.dart';

/// Chapitres Podcast Index, chargés quand un épisode est lu.
class ChapterLoader {
  ChapterLoader(this._database);

  final AppDatabase _database;
  final _inflight = <int, Future<void>>{};
  final _failedAt = <int, DateTime>{};
  static const _retryBackoff = Duration(minutes: 5);

  /// Fetch chapitres encore en cours pour cet épisode.
  bool isChaptersInflight(int episodeId) => _inflight.containsKey(episodeId);

  /// Dernier fetch a échoué et le backoff empêche un nouvel essai.
  bool chaptersRecentlyFailed(int episodeId) {
    final failedAt = _failedAt[episodeId];
    if (failedAt == null) return false;
    return DateTime.now().difference(failedAt) < _retryBackoff;
  }

  /// Charge et mémorise les chapitres Podcast Index d’un épisode (lazy).
  Future<void> ensureChapters(int episodeId) {
    final inflight = _inflight[episodeId];
    if (inflight != null) return inflight;
    final future = _ensureChapters(episodeId).whenComplete(() {
      _inflight.remove(episodeId);
    });
    _inflight[episodeId] = future;
    return future;
  }

  Future<void> _ensureChapters(int episodeId) async {
    final episode = await _database.episodeById(episodeId);
    if (episode == null) return;
    if (episode.chaptersFetched) return;
    final failedAt = _failedAt[episodeId];
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < _retryBackoff) {
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
      _failedAt.remove(episodeId);
    } catch (_) {
      // Pas de markFetched : réessai après backoff.
      _failedAt[episodeId] = DateTime.now();
    }
  }
}
