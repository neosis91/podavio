import 'dart:async';

import '../data/app_database.dart';
import 'playback_source.dart';

enum QueueStepKind { none, seekStart, remote, play }

/// Pas à appliquer par le lecteur. La classe ne lance pas la lecture.
class QueueStep {
  const QueueStep.none()
    : kind = QueueStepKind.none,
      remoteAction = null,
      entry = null;

  const QueueStep.seekStart()
    : kind = QueueStepKind.seekStart,
      remoteAction = null,
      entry = null;

  const QueueStep.remote(this.remoteAction)
    : kind = QueueStepKind.remote,
      entry = null;

  QueueStep.play(this.entry) : kind = QueueStepKind.play, remoteAction = null;

  final QueueStepKind kind;
  final String? remoteAction;
  final EpisodeEntry? entry;
}

/// Épisode précédent ou suivant dans la liste d’origine.
class QueueCursor {
  Future<QueueStep> previous({
    required bool remote,
    required bool advancing,
    required bool hasEpisode,
    required Duration position,
    required PlaybackSource source,
    required int? episodeId,
    required AppDatabase database,
    required bool Function() isDisposed,
    required bool Function() isMounted,
  }) async {
    if (remote) {
      if (position.inMilliseconds > 3000) return const QueueStep.seekStart();
      return const QueueStep.remote('previous');
    }
    if (advancing || isDisposed() || !hasEpisode) return const QueueStep.none();
    if (episodeId == null) return const QueueStep.none();
    final earlier = await relative(
      delta: -1,
      source: source,
      episodeId: episodeId,
      database: database,
      isDisposed: isDisposed,
    );
    if (isDisposed() || !isMounted()) return const QueueStep.none();
    if (earlier == null) return const QueueStep.seekStart();
    return QueueStep.play(earlier);
  }

  Future<QueueStep> next({
    required bool remote,
    required bool advancing,
    required PlaybackSource source,
    required int? episodeId,
    required AppDatabase database,
    required bool Function() isDisposed,
  }) async {
    if (remote) return const QueueStep.remote('next');
    if (advancing || isDisposed()) return const QueueStep.none();
    final following = await relative(
      delta: 1,
      source: source,
      episodeId: episodeId,
      database: database,
      isDisposed: isDisposed,
    );
    if (following == null || isDisposed()) return const QueueStep.none();
    return QueueStep.play(following);
  }

  /// Vrai s’il existe un épisode suivant dans la liste en cours, sinon dans
  /// le podcast.
  Stream<bool> watchHasNext({
    required PlaybackSource source,
    required int? episodeId,
    required int? podcastId,
    required AppDatabase database,
  }) {
    return Stream<int>.multi((listener) {
      var tick = 0;
      void ping() => listener.add(tick++);
      final sourceSub = source
          .watch(database)
          .listen((_) => ping(), onError: listener.addError);
      final showSub = podcastId == null
          ? null
          : database
                .watchEpisodeWindow(podcastId: podcastId)
                .listen((_) => ping(), onError: listener.addError);
      listener.onCancel = () async {
        await sourceSub.cancel();
        await showSub?.cancel();
      };
    }).asyncMap((_) async {
      final following = await relative(
        delta: 1,
        source: source,
        episodeId: episodeId,
        database: database,
        isDisposed: () => false,
      );
      return following != null;
    });
  }

  /// Voisin dans la liste d’origine. `1` = suivant, `-1` = précédent.
  /// Hors de la file de lecture, le suivant retombe sur le premier.
  /// Sans voisin dans cette liste, on prend l’épisode voisin du même podcast,
  /// du plus ancien vers le plus récent.
  Future<EpisodeEntry?> relative({
    required int delta,
    required PlaybackSource source,
    required int? episodeId,
    required AppDatabase database,
    required bool Function() isDisposed,
  }) async {
    final items = await source.watch(database).first;
    if (isDisposed()) return null;
    final picked = _pick(items, delta, episodeId, source.isQueue);
    if (picked != null || episodeId == null) return picked;
    if (_isWholeShow(source)) return null;
    final current = await database.getEpisode(episodeId);
    if (current == null || isDisposed()) return null;
    final show = await database
        .watchEpisodeWindow(podcastId: current.podcast.id, oldestFirst: true)
        .first;
    if (isDisposed()) return null;
    return _pick(show, delta, episodeId, false);
  }

  /// Liste complète d’un podcast, sans filtre ni playlist.
  bool _isWholeShow(PlaybackSource source) {
    final query = source.query;
    return query.podcastId != null &&
        !query.unreadOnly &&
        !query.favoritesOnly &&
        !query.downloadsOnly &&
        !query.cacheOnly &&
        !query.queuedOnly &&
        !query.historyOnly &&
        !query.inProgressOnly &&
        query.playlistId == null &&
        query.search.isEmpty;
  }

  EpisodeEntry? _pick(
    List<EpisodeEntry> items,
    int delta,
    int? episodeId,
    bool queueFallback,
  ) {
    if (items.isEmpty) return null;
    if (episodeId == null) {
      return delta > 0 && queueFallback ? items.first : null;
    }
    final index = items.indexWhere((entry) => entry.episode.id == episodeId);
    if (index < 0) {
      return delta > 0 && queueFallback ? items.first : null;
    }
    final target = index + delta;
    if (target < 0 || target >= items.length) return null;
    return items[target];
  }
}
