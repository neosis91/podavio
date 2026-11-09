import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Ordre inversé de la liste d’épisodes, mémorisé par podcast.
final podcastListReversedProvider =
    NotifierProvider.family<PodcastListReversed, bool, int>(
      PodcastListReversed.new,
    );

class PodcastListReversed extends Notifier<bool> {
  PodcastListReversed(this.podcastId);

  final int podcastId;

  String get _key => 'podcastListReversed.$podcastId';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    final next = !state;
    state = next;
    await ref.read(sharedPreferencesProvider).setBool(_key, next);
  }
}
