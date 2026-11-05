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
    if (position.inMilliseconds > 3000) return const QueueStep.seekStart();
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

  /// Voisin dans la liste d’origine. `1` = suivant, `-1` = précédent.
  /// Hors de la file de lecture, le suivant retombe sur le premier.
  Future<EpisodeEntry?> relative({
    required int delta,
    required PlaybackSource source,
    required int? episodeId,
    required AppDatabase database,
    required bool Function() isDisposed,
  }) async {
    final items = await source.watch(database).first;
    if (isDisposed() || items.isEmpty) return null;
    if (episodeId == null) {
      return delta > 0 && source.isQueue ? items.first : null;
    }
    final index = items.indexWhere((entry) => entry.episode.id == episodeId);
    if (index < 0) {
      return delta > 0 && source.isQueue ? items.first : null;
    }
    final target = index + delta;
    if (target < 0 || target >= items.length) return null;
    return items[target];
  }
}
