import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import 'activity_messages.dart';
import 'app_database.dart';
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

class DownloadWaitingCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setCount(int value) {
    if (state == value) return;
    state = value;
  }
}

class _QueuedDownload {
  const _QueuedDownload({required this.episode, required this.automatic});

  final Episode episode;
  final bool automatic;
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
  var _batchOpen = false;
  var _succeeded = 0;
  var _failed = 0;
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
      return;
    }
    ref.read(downloadServiceProvider).cancel(episodeId);
    _labels.remove(episodeId);
    _clear(episodeId);
    _publishDownloadNotice();
  }

  /// Met [episode] en file. Le futur se termine quand ce fichier est fini,
  /// pas quand un créneau se libère.
  Future<void> download(Episode episode, {bool automatic = false}) {
    if (episode.downloadPath != null) return Future.value();
    final existing = _pending[episode.id];
    if (existing != null) return existing.future;
    final done = Completer<void>();
    _pending[episode.id] = done;
    _labels[episode.id] = _EpisodeLabel(episode.title, null);
    _waiting.add(_QueuedDownload(episode: episode, automatic: automatic));
    _publishWaiting();
    _pump();
    _publishDownloadNotice();
    return done.future;
  }

  Future<void> _run(_QueuedDownload job) async {
    final episode = job.episode;
    if (job.automatic &&
        mobileDataBlocksDownload(
          allowMobileData: ref.read(settingsProvider).allowMobileData,
          mobileDataActive: await ref.read(mobileDataProbeProvider)(),
        )) {
      _labels.remove(episode.id);
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
      _succeeded += 1;
      _successTitle = label?.title ?? episode.title;
      _successPodcast = label?.podcast;
      if (ref.read(settingsProvider).enqueueDownloads) {
        await ref.read(databaseProvider).addToQueue(episode.id);
      }
      _finish(episode.id, null);
      _publishDownloadNotice();
    } on DownloadCancelled {
      _labels.remove(episode.id);
      _finish(episode.id, const DownloadCancelled());
      _publishDownloadNotice();
    } catch (error) {
      final label = _labels.remove(episode.id);
      _failed += 1;
      _failureMessage ??= downloadErrorText(error);
      _failureTitle = label?.title ?? episode.title;
      _failurePodcast = label?.podcast;
      _finish(episode.id, error);
      _publishDownloadNotice();
    }
  }

  void _pump() {
    final limit = ref.read(settingsProvider).simultaneousDownloads;
    while (state.length < limit && _waiting.isNotEmpty) {
      final job = _waiting.removeAt(0);
      _publishWaiting();
      if (state.containsKey(job.episode.id)) continue;
      state = {...state, job.episode.id: 0};
      unawaited(_run(job));
    }
  }

  void _publishWaiting() {
    ref.read(downloadWaitingCountProvider.notifier).setCount(_waiting.length);
  }

  void _publishDownloadNotice({bool force = false}) {
    final remaining = state.length + _waiting.length;
    if (remaining == 0) {
      _closeDownloadBatch();
      return;
    }
    if (!_batchOpen) {
      _batchOpen = true;
      _succeeded = 0;
      _failed = 0;
      _failureMessage = null;
      _successTitle = null;
      _successPodcast = null;
      _failureTitle = null;
      _failurePodcast = null;
      _postedPercent = null;
      _postedRemaining = null;
      _postedFailed = null;
    }
    if (!ref.read(settingsProvider).notifyDownloadActivity) return;
    final batch = _progressBatch(remaining);
    final percent = (batch.progress * 100).round();
    if (!force &&
        percent == _postedPercent &&
        remaining == _postedRemaining &&
        _failed == _postedFailed) {
      return;
    }
    _postedPercent = percent;
    _postedRemaining = remaining;
    _postedFailed = _failed;
    unawaited(ref.read(downloadNotificationsProvider).showProgress(batch));
  }

  DownloadBatch _progressBatch(int remaining) {
    final written = state.values.fold<double>(0, (sum, value) => sum + value);
    final focus = _focusLabel();
    return DownloadBatch(
      remaining: remaining,
      progress: written / remaining,
      title: focus?.title,
      podcast: focus?.podcast,
      failed: _failed,
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
