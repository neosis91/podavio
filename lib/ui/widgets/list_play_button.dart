import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../player/playback_source.dart';
import '../../player/player_controller.dart';
import 'brand.dart';

/// Lance le premier épisode de [query], comme un appui sur sa ligne.
class ListPlayButton extends ConsumerWidget {
  const ListPlayButton({super.key, required this.query});

  final EpisodeQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = ref
        .watch(episodesProvider(query))
        .asData
        ?.value
        .entries
        .firstOrNull;
    return IconButton(
      tooltip: 'Lire',
      onPressed: first == null
          ? null
          : () => ref
                .read(playerProvider.notifier)
                .playOrPauseEntry(
                  first,
                  source: PlaybackSource.fromQuery(query),
                ),
      icon: const PlayCircleIcon(),
    );
  }
}
