import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../player/player_controller.dart';
import '../router.dart';
import 'cover.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    if (!player.hasEpisode) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final total = player.duration.inMilliseconds;
    final progress = total == 0
        ? 0.0
        : (player.position.inMilliseconds / total).clamp(0.0, 1.0);

    return RepaintBoundary(
      child: Material(
        color: scheme.surfaceContainer,
        child: InkWell(
          onTap: () => context.push(AppRoutes.player),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress, minHeight: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    PodcastCover(url: player.imageUrl, size: 48, radius: 6),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            player.error ??
                                '${player.podcastTitle} · ${formatClock(player.position)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: player.playing ? 'Pause' : 'Lecture',
                      onPressed: () =>
                          ref.read(playerProvider.notifier).toggle(),
                      icon: Icon(
                        player.playing ? Icons.pause_circle : Icons.play_circle,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
