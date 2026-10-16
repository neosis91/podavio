import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/status_notifications.dart';
import '../../player/playback_source.dart';
import '../../settings/settings_controller.dart';
import '../router.dart';
import '../widgets/empty_state.dart';
import '../widgets/episode_tile.dart';
import '../widgets/messages.dart';
import 'podcast_header.dart';

class PodcastPage extends ConsumerStatefulWidget {
  const PodcastPage({super.key, required this.podcastId});

  final int podcastId;

  @override
  ConsumerState<PodcastPage> createState() => _PodcastPageState();
}

class _PodcastPageState extends ConsumerState<PodcastPage> {
  @override
  Widget build(BuildContext context) {
    final podcast = ref.watch(podcastProvider(widget.podcastId));
    final query = EpisodeQuery(podcastId: widget.podcastId);
    final episodes = ref.watch(episodesProvider(query));
    return podcast.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          title: 'Podcast introuvable',
          message: error.toString(),
        ),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              title: 'Podcast introuvable',
              message: 'Cet abonnement n’est plus dans la bibliothèque.',
            ),
          );
        }
        return Scaffold(
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is! ScrollUpdateNotification &&
                  notification is! ScrollEndNotification) {
                return false;
              }
              if (notification.metrics.extentAfter < 800) {
                ref.read(episodesProvider(query).notifier).loadMore();
              }
              return false;
            },
            child: supportsPullToRefresh
                ? RefreshIndicator(
                    onRefresh: () => _refresh(context, ref, item.feedUrl),
                    child: _podcastScrollView(
                      item: item,
                      episodes: episodes,
                      pullToRefresh: true,
                    ),
                  )
                : _podcastScrollView(
                    item: item,
                    episodes: episodes,
                    pullToRefresh: false,
                  ),
          ),
        );
      },
    );
  }

  Widget _podcastScrollView({
    required Podcast item,
    required AsyncValue<EpisodeWindow> episodes,
    required bool pullToRefresh,
  }) {
    return CustomScrollView(
      physics: pullToRefresh ? const AlwaysScrollableScrollPhysics() : null,
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(item.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Actualiser ce flux',
              onPressed: () => _refresh(context, ref, item.feedUrl),
              icon: const Icon(Icons.refresh),
            ),
            if (item.subscribed)
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'preferred':
                      ref
                          .read(databaseProvider)
                          .setPodcastPreferred(
                            item.id,
                            preferred: !item.preferred,
                          );
                    case 'autoDownload':
                      ref
                          .read(databaseProvider)
                          .setPodcastAutoDownload(
                            item.id,
                            autoDownload: !item.autoDownload,
                          );
                    case 'keepUpdated':
                      ref
                          .read(databaseProvider)
                          .setPodcastKeepUpdated(
                            item.id,
                            keepUpdated: !item.keepUpdated,
                          );
                    case 'unsubscribe':
                      _unsubscribe(context, ref, item);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'preferred',
                    child: Text(
                      item.preferred
                          ? 'Retirer des préférés'
                          : 'Marquer comme préféré',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'autoDownload',
                    child: Text(
                      item.autoDownload
                          ? 'Désactiver les téléchargements automatiques'
                          : 'Activer les téléchargements automatiques',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'keepUpdated',
                    child: Text(
                      item.keepUpdated
                          ? 'Ne plus maintenir à jour'
                          : 'Maintenir à jour',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'unsubscribe',
                    child: Text('Se désabonner'),
                  ),
                ],
              )
            else
              IconButton(
                tooltip: 'Retirer l’aperçu',
                onPressed: () => _unsubscribe(context, ref, item),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: PodcastHeader(
            podcast: item,
            onInfo: () => context.push(AppRoutes.podcastAbout(item.id)),
            onSettings: () => context.push(AppRoutes.podcastSettings(item.id)),
          ),
        ),
        ..._episodeSlivers(episodes),
      ],
    );
  }

  List<Widget> _episodeSlivers(AsyncValue<EpisodeWindow> episodes) {
    return episodes.when(
      loading: () => [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: 'Épisodes indisponibles',
            message: error.toString(),
          ),
        ),
      ],
      data: (window) => [
        if (window.entries.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              title: 'Aucun épisode',
              message: 'Ce flux ne contient pas encore d’épisode audio.',
            ),
          )
        else
          ..._episodeListSlivers(window),
      ],
    );
  }

  List<Widget> _episodeListSlivers(EpisodeWindow window) {
    return [
      SliverPadding(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        sliver: SliverList.builder(
          addAutomaticKeepAlives: false,
          itemCount: window.entries.length + (window.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= window.entries.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final entry = window.entries[index];
            return EpisodeTile(
              key: ValueKey(entry.episode.id),
              entry: entry,
              showPodcast: false,
              queueStyle: true,
              playbackSource: PlaybackSource(
                EpisodeQuery(podcastId: widget.podcastId, paginated: false),
              ),
            );
          },
        ),
      ),
    ];
  }

  Future<void> _refresh(
    BuildContext context,
    WidgetRef ref,
    String feedUrl,
  ) async {
    try {
      final saved = await ref.read(feedServiceProvider).refresh(feedUrl);
      final podcast = await ref
          .read(databaseProvider)
          .getPodcast(saved.podcastId);
      if (podcast != null &&
          shouldNotifyNewEpisodes(
            notifyNewEpisodes: ref.read(settingsProvider).notifyNewEpisodes,
            keepUpdated: podcast.keepUpdated,
            episodeNotification: podcast.episodeNotification,
            newCount: saved.newEpisodeIds.length,
          )) {
        await announceNewEpisodes(
          ref.read(statusNotificationsProvider),
          ref.read(settingsProvider),
          [
            NewEpisodeArrival(
              podcastId: podcast.id,
              title: podcast.title,
              count: saved.newEpisodeIds.length,
            ),
          ],
        );
      }
      if (context.mounted) showMessage(context, 'Flux actualisé');
    } catch (error) {
      if (context.mounted) showMessage(context, errorText(error));
    }
  }

  Future<void> _unsubscribe(
    BuildContext context,
    WidgetRef ref,
    Podcast item,
  ) async {
    final isPreview = !item.subscribed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPreview ? 'Retirer cet aperçu ?' : 'Se désabonner ?'),
        content: Text(
          isPreview
              ? '« ${item.title} » et ses épisodes seront retirés. Les fichiers téléchargés seront aussi supprimés.'
              : '« ${item.title} » et ses épisodes seront retirés de Podavio. Les fichiers téléchargés seront aussi supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isPreview ? 'Retirer' : 'Se désabonner'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final paths = await ref.read(databaseProvider).deletePodcast(item.id);
    await ref.read(downloadServiceProvider).deleteFiles(paths);
    if (context.mounted) Navigator.pop(context);
  }
}
