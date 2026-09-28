import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../data/app_database.dart';
import '../data/providers.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_tile.dart';
import 'widgets/messages.dart';

class PodcastPage extends ConsumerWidget {
  const PodcastPage({super.key, required this.podcastId});

  final int podcastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcast = ref.watch(podcastProvider(podcastId));
    final query = EpisodeQuery(podcastId: podcastId);
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
          body: episodes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              title: 'Épisodes indisponibles',
              message: error.toString(),
            ),
            data: (window) => NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 800) {
                  ref.read(episodesProvider(query).notifier).loadMore();
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: () => _refresh(context, ref, item.feedUrl),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'preferred') {
                              ref
                                  .read(databaseProvider)
                                  .setPodcastPreferred(
                                    item.id,
                                    preferred: !item.preferred,
                                  );
                              return;
                            }
                            _unsubscribe(context, ref, item);
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
                            const PopupMenuItem(
                              value: 'unsubscribe',
                              child: Text('Se désabonner'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PodcastCover(
                              url: item.imageUrl,
                              size: 112,
                              radius: 16,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  if (item.author.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(item.author),
                                  ],
                                  if (item.refreshedAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Actualisé le ${formatDate(item.refreshedAt)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (item.description.trim().isNotEmpty)
                      SliverToBoxAdapter(
                        child: _ShowNotes(html: item.description),
                      ),
                    if (window.entries.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          title: 'Aucun épisode',
                          message:
                              'Ce flux ne contient pas encore d’épisode audio.',
                        ),
                      )
                    else
                      SliverList.separated(
                        itemCount:
                            window.entries.length + (window.hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index >= window.entries.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return EpisodeTile(
                            entry: window.entries[index],
                            showPodcast: false,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refresh(
    BuildContext context,
    WidgetRef ref,
    String feedUrl,
  ) async {
    try {
      await ref.read(feedServiceProvider).refresh(feedUrl);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se désabonner ?'),
        content: Text(
          '« ${item.title} » et ses épisodes seront retirés de Podavio. Les fichiers téléchargés seront aussi supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se désabonner'),
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

class _ShowNotes extends StatefulWidget {
  const _ShowNotes({required this.html});

  final String html;

  @override
  State<_ShowNotes> createState() => _ShowNotesState();
}

class _ShowNotesState extends State<_ShowNotes> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = plainText(widget.html);
    if (text.isEmpty) return const SizedBox.shrink();
    final long = text.length > 180;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: _expanded ? 8 : 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (long)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Réduire' : 'Lire la suite'),
            ),
        ],
      ),
    );
  }
}
