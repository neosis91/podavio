import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
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

class DownloadProgressNotifier extends Notifier<Map<int, double>> {
  final _waiting = <_QueuedDownload>[];
  final _pending = <int, Completer<void>>{};

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
      unawaited(ref.read(downloadNotificationsProvider).dismiss(episodeId));
      _finish(episodeId, const DownloadCancelled());
      return;
    }
    ref.read(downloadServiceProvider).cancel(episodeId);
    unawaited(ref.read(downloadNotificationsProvider).dismiss(episodeId));
    _clear(episodeId);
  }

  /// Met [episode] en file. Le futur se termine quand ce fichier est fini,
  /// pas quand un créneau se libère.
  Future<void> download(Episode episode, {bool automatic = false}) {
    if (episode.downloadPath != null) return Future.value();
    final existing = _pending[episode.id];
    if (existing != null) return existing.future;
    final done = Completer<void>();
    _pending[episode.id] = done;
    _waiting.add(_QueuedDownload(episode: episode, automatic: automatic));
    _publishWaiting();
    _pump();
    return done.future;
  }

  Future<void> _run(_QueuedDownload job) async {
    final episode = job.episode;
    if (job.automatic &&
        mobileDataBlocksDownload(
          allowMobileData: ref.read(settingsProvider).allowMobileData,
          mobileDataActive: await ref.read(mobileDataProbeProvider)(),
        )) {
      _finish(episode.id, null);
      return;
    }
    if (!state.containsKey(episode.id)) {
      _finish(episode.id, const DownloadCancelled());
      return;
    }
    final notifications = ref.read(downloadNotificationsProvider);
    final podcast = await ref
        .read(databaseProvider)
        .getPodcast(episode.podcastId);
    final notice = DownloadNotice(
      episodeId: episode.id,
      title: episode.title,
      podcast: podcast?.title,
    );
    var lastPercent = -1;
    _showDownloadProgress(notifications, notice);
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
              final percent = (clamped * 100).round();
              if (percent == lastPercent) return;
              lastPercent = percent;
              _showDownloadProgress(
                notifications,
                DownloadNotice(
                  episodeId: notice.episodeId,
                  title: notice.title,
                  podcast: notice.podcast,
                  progress: clamped,
                ),
              );
            },
          );
      if (ref.read(settingsProvider).notifyDownloadActivity) {
        await notifications.showFinished(notice);
      } else {
        await notifications.dismiss(episode.id);
      }
      if (ref.read(settingsProvider).enqueueDownloads) {
        await ref.read(databaseProvider).addToQueue(episode.id);
      }
      _finish(episode.id, null);
    } on DownloadCancelled {
      await notifications.dismiss(episode.id);
      _finish(episode.id, const DownloadCancelled());
    } catch (error) {
      if (ref.read(settingsProvider).notifyDownloadErrors) {
        await notifications.showFailed(notice, downloadErrorText(error));
      } else {
        await notifications.dismiss(episode.id);
      }
      _finish(episode.id, error);
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

  void _showDownloadProgress(
    DownloadNotifications notifications,
    DownloadNotice notice,
  ) {
    if (!ref.read(settingsProvider).notifyDownloadActivity) return;
    unawaited(notifications.showProgress(notice));
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
