import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'download_service.dart';
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
    _clear(episodeId);
  }

  Future<void> download(Episode episode) async {
    if (state.containsKey(episode.id) || episode.downloadPath != null) return;
    state = {...state, episode.id: 0};
    try {
      await ref
          .read(downloadServiceProvider)
          .download(
            episode,
            onProgress: (progress) {
              if (!state.containsKey(episode.id)) return;
              state = {...state, episode.id: progress.clamp(0, 1)};
            },
          );
    } on DownloadCancelled {
      _clear(episode.id);
      rethrow;
    } catch (_) {
      _clear(episode.id);
      rethrow;
    }
    _clear(episode.id);
  }

  void _clear(int episodeId) {
    if (!state.containsKey(episodeId)) return;
    final next = Map<int, double>.of(state)..remove(episodeId);
    state = next;
  }
}
