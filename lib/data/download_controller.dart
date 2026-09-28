import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'providers.dart';

final downloadProgressProvider =
    NotifierProvider<DownloadProgressNotifier, Map<int, double>>(
      DownloadProgressNotifier.new,
    );

class DownloadProgressNotifier extends Notifier<Map<int, double>> {
  @override
  Map<int, double> build() => const {};

  Future<void> download(Episode episode) async {
    if (state.containsKey(episode.id) || episode.downloadPath != null) return;
    state = {...state, episode.id: 0};
    try {
      await ref.read(downloadServiceProvider).download(
        episode,
        onProgress: (progress) {
          if (!state.containsKey(episode.id)) return;
          state = {...state, episode.id: progress.clamp(0, 1)};
        },
      );
    } catch (_) {
      final next = Map<int, double>.of(state)..remove(episode.id);
      state = next;
      rethrow;
    }
    final next = Map<int, double>.of(state)..remove(episode.id);
    state = next;
  }
}
