import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../settings/settings_controller.dart';

/// Compteurs jaquettes / tri Compteur / filtre « supérieur à zéro ».
/// Si Compteur = aucun : map vide sauf besoin tri/filtre → non lus.
final podcastCounterCountsProvider = StreamProvider<Map<int, int>>((ref) {
  final mode = ref.watch(settingsProvider.select((s) => s.podcastCounter));
  final sort = ref.watch(settingsProvider.select((s) => s.podcastSort));
  final counterAboveZero = ref.watch(
    settingsProvider.select((s) => s.podcastFilters.counterAboveZero),
  );
  final forBadge = mode != PodcastCounter.none;
  final forMetric = sort == PodcastSort.counter || counterAboveZero;
  if (!forBadge && !forMetric) {
    return Stream.value(const <int, int>{});
  }

  final database = ref.watch(databaseProvider);
  final queryMode = mode == PodcastCounter.none ? PodcastCounter.unread : mode;
  return switch (queryMode) {
    PodcastCounter.none => Stream.value(const <int, int>{}),
    PodcastCounter.unread => database.watchEpisodeCountsByPodcast(
      unreadOnly: true,
    ),
    PodcastCounter.downloaded => database.watchEpisodeCountsByPodcast(
      downloadsOnly: true,
    ),
    PodcastCounter.downloadedUnread => database.watchEpisodeCountsByPodcast(
      unreadOnly: true,
      downloadsOnly: true,
    ),
    PodcastCounter.queue => database.watchEpisodeCountsByPodcast(
      queuedOnly: true,
    ),
  };
});

/// Épisodes lus par podcast (uniquement si tri « Nombre lus »).
final podcastPlayedCountsProvider = StreamProvider<Map<int, int>>((ref) {
  final sort = ref.watch(settingsProvider.select((s) => s.podcastSort));
  if (sort != PodcastSort.played) {
    return Stream.value(const <int, int>{});
  }
  return ref
      .watch(databaseProvider)
      .watchEpisodeCountsByPodcast(playedOnly: true);
});
