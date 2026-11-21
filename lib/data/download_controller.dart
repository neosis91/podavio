import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import 'activity_messages.dart';
import 'app_database.dart';
import 'audio_analysis.dart';
import 'download_notifications.dart';
import 'download_service.dart';
import 'online_status.dart';
import 'providers.dart';

final downloadProgressProvider =
    NotifierProvider<DownloadProgressNotifier, Map<int, double>>(
      DownloadProgressNotifier.new,
    );

/// Épisodes en attente d’un créneau. Les fichiers déjà en cours sont dans
/// [downloadProgressProvider].
final downloadWaitingCountProvider =
    NotifierProvider<DownloadWaitingCountNotifier, int>(
      DownloadWaitingCountNotifier.new,
    );

/// Identifiants des épisodes qui attendent un créneau de téléchargement.
final downloadWaitingIdsProvider =
    NotifierProvider<DownloadWaitingIdsNotifier, Set<int>>(
      DownloadWaitingIdsNotifier.new,
    );

/// Épisodes déjà traités dans le lot en cours. Ils restent dans le total
/// jusqu’à la fin, ou jusqu’à un ajout ou un retrait.
final downloadBatchTallyProvider =
    NotifierProvider<DownloadBatchTallyNotifier, DownloadBatchTally>(
      DownloadBatchTallyNotifier.new,
    );

class DownloadBatchTally {
  const DownloadBatchTally({
    this.finished = 0,
    this.failed = 0,
    this.failedWritten = 0,
    this.skipped = 0,
  });

  final int finished;
  final int failed;

  /// Part déjà écrite des épisodes qui ont échoué.
  final double failedWritten;

  /// Téléchargements automatiques laissés de côté, par exemple sur le
  /// réseau mobile. Ils restent dans le total.
  final int skipped;

  @override
  bool operator ==(Object other) {
    return other is DownloadBatchTally &&
        other.finished == finished &&
        other.failed == failed &&
        other.failedWritten == failedWritten &&
        other.skipped == skipped;
  }

  @override
  int get hashCode => Object.hash(finished, failed, failedWritten, skipped);
}

class DownloadBatchTallyNotifier extends Notifier<DownloadBatchTally> {
  @override
  DownloadBatchTally build() => const DownloadBatchTally();

  void setCounts({
    required int finished,
    required int failed,
    required double failedWritten,
    required int skipped,
  }) {
    final next = DownloadBatchTally(
      finished: finished,
      failed: failed,
      failedWritten: failedWritten,
      skipped: skipped,
    );
    if (state == next) return;
    state = next;
  }
}

class DownloadWaitingCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setCount(int value) {
    if (state == value) return;
    state = value;
  }
}

/// Vrai si un nouvel ordre ne doit pas relancer cet épisode.
bool downloadAlreadyRequested(
  int episodeId, {
  required Map<int, double> running,
  required Set<int> waiting,
}) {
  return running.containsKey(episodeId) || waiting.contains(episodeId);
}

/// Épisode dont le téléchargement a échoué et peut être relancé.
class DownloadFailure {
  const DownloadFailure({
    required this.episode,
    required this.message,
    required this.written,
  });

  final Episode episode;
  final String message;

  /// Part déjà reçue au moment de l’échec, entre 0 et 1.
  final double written;

  @override
  bool operator ==(Object other) {
    return other is DownloadFailure &&
        other.episode.id == episode.id &&
        other.message == message &&
        other.written == written;
  }

  @override
  int get hashCode => Object.hash(episode.id, message, written);
}

final downloadFailuresProvider =
    NotifierProvider<DownloadFailuresNotifier, List<DownloadFailure>>(
      DownloadFailuresNotifier.new,
    );

class DownloadFailuresNotifier extends Notifier<List<DownloadFailure>> {
  @override
  List<DownloadFailure> build() => const [];

  void setFailures(List<DownloadFailure> value) {
    if (state.length == value.length) {
      var same = true;
      for (var index = 0; index < state.length; index++) {
        if (state[index] != value[index]) {
          same = false;
          break;
        }
      }
      if (same) return;
    }
    state = value;
  }
}

class DownloadWaitingIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void setIds(Set<int> value) {
    if (state.length == value.length && state.containsAll(value)) return;
    state = value;
  }
}

class _QueuedDownload {
  const _QueuedDownload({
    required this.episode,
    required this.automatic,
    required this.allowMobileOnce,
    this.resumeFrom = 0,
  });

  final Episode episode;
  final bool automatic;
  final bool allowMobileOnce;

  /// Progression déjà reçue, pour ne pas revenir à zéro le temps de reprendre.
  final double resumeFrom;
}

class _EpisodeLabel {
  const _EpisodeLabel(this.title, this.podcast);

  final String title;
  final String? podcast;
}

class DownloadProgressNotifier extends Notifier<Map<int, double>> {
  final _waiting = <_QueuedDownload>[];
  final _pending = <int, Completer<void>>{};
  final _labels = <int, _EpisodeLabel>{};
  final _failures = <DownloadFailure>[];
  var _batchOpen = false;
  var _succeeded = 0;
  var _failed = 0;
  var _failedWritten = 0.0;
  var _skipped = 0;
  String? _failureMessage;
  String? _successTitle;
  String? _successPodcast;
  String? _failureTitle;
  String? _failurePodcast;
  int? _postedPercent;
  int? _postedRemaining;
  int? _postedFailed;

  @override
  Map<int, double> build() {
    ref.listen(settingsProvider.select((s) => s.simultaneousDownloads), (_, _) {
      _pump();
    });
    return const {};
  }

  void cancel(int episodeId) {
    final waitingIndex = _waiting.indexWhere(
      (job) => job.episode.id == episodeId,
    );
    if (waitingIndex >= 0) {
      _waiting.removeAt(waitingIndex);
      _publishWaiting();
      _labels.remove(episodeId);
      _finish(episodeId, const DownloadCancelled());
      _publishDownloadNotice();
      unawaited(ref.read(downloadServiceProvider).forgetPartials([episodeId]));
      return;
    }
    ref.read(downloadServiceProvider).cancel(episodeId);
    _labels.remove(episodeId);
    _clear(episodeId);
    _publishDownloadNotice();
  }

  /// Met [episode] en file. Le futur se termine quand ce fichier est fini,
  /// pas quand un créneau se libère.
  Future<void> download(
    Episode episode, {
    bool automatic = false,
    bool allowMobileOnce = false,
  }) {
    if (episode.downloadPath != null) {
      if (_releaseFailure(episode.id) != null && _batchOpen) {
        _publishDownloadNotice();
      }
      return Future.value();
    }
    final resumed = _releaseFailure(episode.id);
    final existing = _pending[episode.id];
    if (existing != null) return existing.future;
    final done = Completer<void>();
    _pending[episode.id] = done;
    _labels[episode.id] = _EpisodeLabel(episode.title, null);
    _waiting.add(
      _QueuedDownload(
        episode: episode,
        automatic: automatic,
        allowMobileOnce: allowMobileOnce,
        resumeFrom: resumed?.written ?? 0,
      ),
    );
    _publishWaiting();
    _pump();
    _publishDownloadNotice();
    return done.future;
  }

  /// Relance les épisodes en échec. Sans [episodeId], relance toute la liste.
  List<Future<void>> retryFailures({int? episodeId}) {
    final episodes = [
      for (final failure in _failures)
        if (episodeId == null || failure.episode.id == episodeId)
          failure.episode,
    ];
    return [for (final episode in episodes) download(episode)];
  }

  /// Oublie les échecs une fois le lot terminé.
  void dismissFailures() {
    if (state.isNotEmpty || _waiting.isNotEmpty || _failures.isEmpty) return;
    final ids = [for (final failure in _failures) failure.episode.id];
    _failures.clear();
    _publishFailures();
    unawaited(ref.read(downloadServiceProvider).forgetPartials(ids));
  }

  Future<void> _run(_QueuedDownload job) async {
    final episode = job.episode;
    if (job.automatic &&
        !job.allowMobileOnce &&
        mobileDataBlocksDownload(
          allowMobileData: ref.read(settingsProvider).allowMobileData,
          mobileDataActive: await ref.read(mobileDataProbeProvider)(),
        )) {
      _labels.remove(episode.id);
      _skipped += 1;
      _finish(episode.id, null);
      _publishDownloadNotice();
      return;
    }
    if (!state.containsKey(episode.id)) {
      _labels.remove(episode.id);
      _finish(episode.id, const DownloadCancelled());
      _publishDownloadNotice();
      return;
    }
    final podcast = await ref
        .read(databaseProvider)
        .getPodcast(episode.podcastId);
    _labels[episode.id] = _EpisodeLabel(episode.title, podcast?.title);
    _publishDownloadNotice(force: true);
    try {
      await ref
          .read(downloadServiceProvider)
          .download(
            episode,
            directory: ref.read(settingsProvider).downloadDirectory,
            onProgress: (progress) {
              if (!state.containsKey(episode.id)) return;
              final clamped = progress.clamp(0, 1).toDouble();
              state = {...state, episode.id: clamped};
              _publishDownloadNotice();
            },
          );
      final label = _labels.remove(episode.id);
      _successTitle = label?.title ?? episode.title;
      _successPodcast = label?.podcast;
      if (ref.read(settingsProvider).enqueueDownloads) {
        await ref.read(databaseProvider).addToQueue(episode.id);
      }
      // L'épisode reste dans la carte pendant l'ajout à la file. Le compter
      // seulement après l'avoir retirée, sinon un progrès concurrent le
      // compte deux fois et l'anneau redescend.
      _finish(episode.id, null);
      _succeeded += 1;
      _publishDownloadNotice();
      unawaited(_analyzeDownloaded(episode.id));
    } on DownloadCancelled {
      _labels.remove(episode.id);
      _finish(episode.id, const DownloadCancelled());
      _publishDownloadNotice();
    } catch (error) {
      final label = _labels.remove(episode.id);
      final written = state[episode.id] ?? 0;
      _failed += 1;
      _failedWritten += written;
      _failures.removeWhere((failure) => failure.episode.id == episode.id);
      _failures.add(
        DownloadFailure(
          episode: episode,
          message: downloadErrorText(error),
          written: written,
        ),
      );
      _publishFailures();
      _failureMessage ??= downloadErrorText(error);
      _failureTitle = label?.title ?? episode.title;
      _failurePodcast = label?.podcast;
      _finish(episode.id, error);
      _publishDownloadNotice();
    }
  }

  /// Empreinte du fichier terminé, puis recherche des passages du podcast.
  /// La file traite un épisode à la fois, y compris les URI `content:`.
  Future<void> _analyzeDownloaded(int episodeId) async {
    try {
      if (!ref.mounted) return;
      await ref
          .read(audioAnalysisProvider.notifier)
          .enqueueEpisode(episodeId, force: true, automatic: true);
    } catch (error, stack) {
      debugPrint('Analyse audio: $error\n$stack');
    }
  }

  void _pump() {
    final limit = ref.read(settingsProvider).simultaneousDownloads;
    while (state.length < limit && _waiting.isNotEmpty) {
      final job = _waiting.removeAt(0);
      _publishWaiting();
      if (state.containsKey(job.episode.id)) continue;
      final resume = job.resumeFrom.clamp(0, 1).toDouble();
      state = {...state, job.episode.id: resume};
      unawaited(_run(job));
    }
  }

  DownloadFailure? _releaseFailure(int episodeId) {
    final index = _failures.indexWhere(
      (failure) => failure.episode.id == episodeId,
    );
    if (index < 0) return null;
    final failure = _failures.removeAt(index);
    _publishFailures();
    if (_batchOpen) {
      if (_failed > 0) _failed -= 1;
      final written = _failedWritten - failure.written;
      _failedWritten = written < 0 ? 0 : written;
    }
    return failure;
  }

  void _publishFailures() {
    ref.read(downloadFailuresProvider.notifier).setFailures(List.of(_failures));
  }

  void _publishWaiting() {
    ref.read(downloadWaitingCountProvider.notifier).setCount(_waiting.length);
    ref.read(downloadWaitingIdsProvider.notifier).setIds({
      for (final job in _waiting) job.episode.id,
    });
  }

  void _publishDownloadNotice({bool force = false}) {
    final active = state.length + _waiting.length;
    if (active == 0) {
      _closeDownloadBatch();
      return;
    }
    if (!_batchOpen) {
      _batchOpen = true;
      _succeeded = 0;
      _failed = 0;
      _failedWritten = 0;
      _skipped = 0;
      _failureMessage = null;
      _successTitle = null;
      _successPodcast = null;
      _failureTitle = null;
      _failurePodcast = null;
      _postedPercent = null;
      _postedRemaining = null;
      _postedFailed = null;
    }
    _publishTally();
    if (!ref.read(settingsProvider).notifyDownloadActivity) return;
    final batch = _progressBatch();
    final percent = (batch.progress * 100).round();
    if (!force &&
        percent == _postedPercent &&
        batch.remaining == _postedRemaining &&
        _failed == _postedFailed) {
      return;
    }
    _postedPercent = percent;
    _postedRemaining = batch.remaining;
    _postedFailed = _failed;
    unawaited(ref.read(downloadNotificationsProvider).showProgress(batch));
  }

  DownloadBatch _progressBatch() {
    final batch = downloadActivityProgress(
      running: state.values,
      waiting: _waiting.length,
      finished: _succeeded,
      failed: _failed,
      failedWritten: _failedWritten,
      skipped: _skipped,
    );
    final focus = batch.total == 1 ? _focusLabel() : null;
    return DownloadBatch(
      remaining: batch.total,
      progress: batch.progress,
      title: focus?.title,
      podcast: focus?.podcast,
      succeeded: _succeeded,
      failed: _failed,
    );
  }

  void _publishTally() {
    ref
        .read(downloadBatchTallyProvider.notifier)
        .setCounts(
          finished: _succeeded,
          failed: _failed,
          failedWritten: _failedWritten,
          skipped: _skipped,
        );
  }

  _EpisodeLabel? _focusLabel() {
    if (state.length == 1 && _waiting.isEmpty) {
      return _labels[state.keys.single];
    }
    if (state.isEmpty && _waiting.length == 1) {
      return _labels[_waiting.single.episode.id];
    }
    return null;
  }

  void _closeDownloadBatch() {
    if (!_batchOpen) return;
    _batchOpen = false;
    final succeeded = _succeeded;
    final failed = _failed;
    final failureMessage = _failureMessage;
    final successTitle = _successTitle;
    final successPodcast = _successPodcast;
    final failureTitle = _failureTitle;
    final failurePodcast = _failurePodcast;
    _succeeded = 0;
    _failed = 0;
    _failedWritten = 0;
    _skipped = 0;
    _publishTally();
    _failureMessage = null;
    _successTitle = null;
    _successPodcast = null;
    _failureTitle = null;
    _failurePodcast = null;
    if (succeeded == 0 && failed == 0) {
      unawaited(ref.read(downloadNotificationsProvider).dismiss());
      return;
    }
    final summary = DownloadBatch(
      remaining: 0,
      progress: 1,
      title: succeeded == 1 && failed == 0
          ? successTitle
          : failed == 1 && succeeded == 0
          ? failureTitle
          : null,
      podcast: succeeded == 1 && failed == 0
          ? successPodcast
          : failed == 1 && succeeded == 0
          ? failurePodcast
          : null,
      succeeded: succeeded,
      failed: failed,
      failureMessage: failureMessage,
    );
    if (ref.mounted) {
      ref
          .read(activityMessagesProvider.notifier)
          .add(downloadBatchOutcomeBody(summary));
    }
    final settings = ref.read(settingsProvider);
    final notifyDone = settings.notifyDownloadActivity && succeeded > 0;
    final notifyFail = settings.notifyDownloadErrors && failed > 0;
    final notifications = ref.read(downloadNotificationsProvider);
    if (!notifyDone && !notifyFail) {
      unawaited(notifications.dismiss());
      return;
    }
    final shownSucceeded = notifyDone ? succeeded : 0;
    final shownFailed = notifyFail ? failed : 0;
    final singleSuccess = shownSucceeded == 1 && shownFailed == 0;
    final singleFailure = shownFailed == 1 && shownSucceeded == 0;
    unawaited(
      notifications.showFinished(
        DownloadBatch(
          remaining: 0,
          progress: 1,
          title: singleSuccess
              ? successTitle
              : singleFailure
              ? failureTitle
              : null,
          podcast: singleSuccess
              ? successPodcast
              : singleFailure
              ? failurePodcast
              : null,
          succeeded: shownSucceeded,
          failed: shownFailed,
          failureMessage: notifyFail ? failureMessage : null,
        ),
      ),
    );
  }

  Future<void> deleteDownload(Episode episode) async {
    await ref.read(downloadServiceProvider).deleteDownload(episode);
    if (ref.read(settingsProvider).dequeueDeletedDownloads) {
      await ref.read(databaseProvider).removeFromQueue(episode.id);
    }
  }

  Future<int> deleteAllDownloads() async {
    final episodes = await ref.read(databaseProvider).downloadedEpisodes();
    for (final episode in episodes) {
      await deleteDownload(episode);
    }
    return episodes.length;
  }

  void _clear(int episodeId) {
    if (!state.containsKey(episodeId)) return;
    final next = Map<int, double>.of(state)..remove(episodeId);
    state = next;
    _pump();
  }

  void _finish(int episodeId, Object? error) {
    if (state.containsKey(episodeId)) {
      final next = Map<int, double>.of(state)..remove(episodeId);
      state = next;
    }
    final done = _pending.remove(episodeId);
    if (done != null && !done.isCompleted) {
      if (error == null) {
        done.complete();
      } else {
        done.completeError(error);
      }
    }
    _pump();
  }
}
