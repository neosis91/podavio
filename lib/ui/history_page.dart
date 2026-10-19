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
import 'widgets/episode_tile.dart';
import 'widgets/frosted_header.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FrostedScaffold(
      appBar: FrostedAppBar(title: Text(context.tr('Recent plays'))),
      body: const _HistoryList(),
    );
  }
}

class _HistoryList extends ConsumerStatefulWidget {
  const _HistoryList();

  @override
  ConsumerState<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends ConsumerState<_HistoryList> {
  static const _query = EpisodeQuery(historyOnly: true);
  EpisodeWindow? _previous;

  @override
  Widget build(BuildContext context) {
    final next = ref.watch(episodesProvider(_query));
    final loaded = next.asData?.value;
    if (loaded != null) _previous = loaded;
    final window = loaded ?? _previous;

    if (window == null) {
      return next.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          title: 'Impossible de charger les épisodes',
          message: error.toString(),
        ),
        data: (_) => const SizedBox.shrink(),
      );
    }

    if (window.entries.isEmpty) {
      return const EmptyState(
        title: 'Aucune lecture récente',
        message: 'Les épisodes que vous lancez apparaîtront ici.',
      );
    }

    final entries = window.entries;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is! ScrollUpdateNotification &&
            notification is! ScrollEndNotification) {
          return false;
        }
        if (notification.metrics.extentAfter < 800) {
          ref.read(episodesProvider(_query).notifier).loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: belowFrostedBar(context, EdgeInsets.zero),
        itemCount: entries.length + (window.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= entries.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return HistoryEpisodeRow(
            key: ValueKey(entries[index].episode.id),
            entry: entries[index],
          );
        },
      ),
    );
  }
}

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
                          Text(
                            episode.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
