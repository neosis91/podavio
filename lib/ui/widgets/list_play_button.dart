import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../player/playback_source.dart';
import '../../player/player_controller.dart';

/// Lance le premier épisode de [query], comme un appui sur sa ligne.
///
/// Pastille ronde, comme le bouton lecture du mini-lecteur : pause quand
/// cet épisode est celui en cours de lecture.
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
    final current = ref.watch(
      playerProvider.select((state) => (state.episodeId, state.playing)),
    );
    final playing = first != null && current.$1 == first.episode.id && current.$2;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: playing ? 'Pause' : 'Lire',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: scheme.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: first == null
                ? null
                : () => ref
                      .read(playerProvider.notifier)
                      .playOrPauseEntry(
                        first,
                        source: PlaybackSource.fromQuery(query),
                      ),
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                playing ? Icons.pause : Icons.play_arrow,
                size: 28,
                color: first == null
                    ? scheme.onPrimary.withValues(alpha: 0.38)
                    : scheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
