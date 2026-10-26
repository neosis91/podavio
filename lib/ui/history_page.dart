import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../l10n/l10n.dart';
import '../data/feed_service.dart';
import '../data/providers.dart';
import '../player/playback_source.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'widgets/playing_cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_list.dart';
import 'widgets/episode_tile.dart';
import 'widgets/marquee_text.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return EpisodeListScaffold(
      title: Text(context.tr('Recent plays')),
      queueStyle: true,
      query: const EpisodeQuery(historyOnly: true),
      bulkActions: const EpisodeBulkActions(favorite: true, download: true),
      empty: const EmptyState(
        title: 'Aucune lecture récente',
        message: 'Les épisodes que vous lancez apparaîtront ici.',
      ),
    );
  }
}

/// Compact history row used by the library hub shelf.
class HistoryEpisodeRow extends ConsumerWidget {
  const HistoryEpisodeRow({
    super.key,
    required this.entry,
    this.showMenu = false,
  });

  final EpisodeEntry entry;
  final bool showMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final episode = entry.episode;
    final preferPodcastCover = ref.watch(
      settingsProvider.select((s) => s.preferPodcastCover),
    );
    final current = ref.watch(
      playerProvider.select((state) => state.episodeId == episode.id),
    );
    return Material(
      color: current
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 15),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => ref
                    .read(playerProvider.notifier)
                    .playOrPauseEntry(
                      entry,
                      source: PlaybackSource.fromQuery(
                        const EpisodeQuery(historyOnly: true),
                      ),
                    ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    PlayingEpisodeCover(
                      episodeId: episode.id,
                      url: entry.imageUrl(
                        preferPodcastCover: preferPodcastCover,
                      ),
                      localPath: entry.imagePath(
                        preferPodcastCover: preferPodcastCover,
                      ),
                      httpHeaders: podcastAuthHeaders(
                        username: entry.podcast.authUsername,
                        password: entry.podcast.authPassword,
                      ),
                      size: 48,
                      radius: 4,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarqueeText(
                            text: episode.title,
                            style: theme.textTheme.titleSmall,
                          ),
                          EpisodeListSubtitle(
                            entry: entry,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showMenu)
              IconButton(
                tooltip: 'Actions',
                onPressed: () => showEpisodeActionsSheet(context, ref, entry),
                icon: const Icon(Icons.more_vert),
              ),
          ],
        ),
      ),
    );
  }
}
