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

class DownloadProgressNotifier extends Notifier<Map<int, double>> {
  @override
  Map<int, double> build() => const {};

  void cancel(int episodeId) {
    ref.read(downloadServiceProvider).cancel(episodeId);
    unawaited(ref.read(downloadNotificationsProvider).dismiss(episodeId));
    _clear(episodeId);
  }

  Future<void> download(Episode episode, {bool automatic = false}) async {
    if (state.containsKey(episode.id) || episode.downloadPath != null) return;
    if (automatic &&
        mobileDataBlocksDownload(
          allowMobileData: ref.read(settingsProvider).allowMobileData,
          mobileDataActive: await ref.read(mobileDataProbeProvider)(),
        )) {
      return;
    }
    state = {...state, episode.id: 0};
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
    } on DownloadCancelled {
      await notifications.dismiss(episode.id);
      _clear(episode.id);
      rethrow;
    } catch (error) {
      if (ref.read(settingsProvider).notifyDownloadErrors) {
        await notifications.showFailed(notice, downloadErrorText(error));
      } else {
        await notifications.dismiss(episode.id);
      }
      _clear(episode.id);
      rethrow;
    }
    _clear(episode.id);
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
  }
}
