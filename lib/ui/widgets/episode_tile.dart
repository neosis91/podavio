import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/download_controller.dart';
import '../../data/providers.dart';
import '../../player/player_controller.dart';
import '../router.dart';
import 'cover.dart';
import 'messages.dart';

class EpisodeTile extends ConsumerWidget {
  const EpisodeTile({super.key, required this.entry, this.showPodcast = true});

  final EpisodeEntry entry;
  final bool showPodcast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = entry.episode;
    final theme = Theme.of(context);
    final progress = ref.watch(
      downloadProgressProvider.select((items) => items[episode.id]),
    );
    final playing = ref.watch(
      playerProvider.select((state) => state.episodeId == episode.id),
    );
    final duration = episode.durationSeconds == null
        ? null
        : Duration(seconds: episode.durationSeconds!);
    final position = Duration(milliseconds: episode.positionMs);
    final details = <String>[
      if (showPodcast) entry.podcast.title,
      formatDate(episode.publishedAt),
      if (duration != null) formatClock(duration),
      if (!episode.played && position > Duration.zero && duration != null)
        'reste ${formatClock(duration - position)}',
    ].where((part) => part.isNotEmpty).join(' · ');

    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: PodcastCover(url: entry.imageUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: episode.played
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: episode.played ? muted : theme.colorScheme.onSurface,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
                if (episode.downloadPath != null ||
                    episode.favorite ||
                    episode.queueIndex != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (episode.downloadPath != null)
                          Icon(
                            Icons.download_done,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        if (episode.favorite)
                          Icon(
                            Icons.favorite,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        if (episode.queueIndex != null)
                          Icon(
                            Icons.queue_music,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 12),
                    child: LinearProgressIndicator(
                      value: progress == 0 ? null : progress,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: playing ? 'Ouvrir le lecteur' : 'Lire',
            onPressed: () async {
              if (playing) {
                context.push(AppRoutes.player);
                return;
              }
              await ref.read(playerProvider.notifier).playEntry(entry);
            },
            icon: Icon(playing ? Icons.graphic_eq : Icons.play_arrow),
          ),
          PopupMenuButton<EpisodeMenuAction>(
            tooltip: 'Actions',
            onSelected: (action) =>
                runEpisodeAction(context, ref, entry, action),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: EpisodeMenuAction.queue,
                child: Text(
                  episode.queueIndex == null
                      ? 'Ajouter à la file'
                      : 'Retirer de la file',
                ),
              ),
              PopupMenuItem(
                value: EpisodeMenuAction.played,
                child: Text(
                  episode.played ? 'Marquer comme non lu' : 'Marquer comme lu',
                ),
              ),
              PopupMenuItem(
                value: EpisodeMenuAction.favorite,
                child: Text(
                  episode.favorite
                      ? 'Retirer des favoris'
                      : 'Ajouter aux favoris',
                ),
              ),
              PopupMenuItem(
                value: EpisodeMenuAction.download,
                child: Text(
                  episode.downloadPath == null
                      ? 'Télécharger'
                      : 'Supprimer le téléchargement',
                ),
              ),
              const PopupMenuItem(
                value: EpisodeMenuAction.share,
                child: Text('Partager'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum EpisodeMenuAction { queue, played, favorite, download, share }

Future<void> shareEpisode(EpisodeEntry entry) {
  final notes = plainText(entry.episode.description);
  final excerpt = notes.length > 180 ? '${notes.substring(0, 180)}…' : notes;
  final text = [
    entry.episode.title,
    entry.podcast.title,
    if (excerpt.isNotEmpty) excerpt,
    entry.episode.audioUrl,
  ].join('\n');
  return SharePlus.instance.share(
    ShareParams(text: text, title: entry.episode.title),
  );
}

Future<void> runEpisodeAction(
  BuildContext context,
  WidgetRef ref,
  EpisodeEntry entry,
  EpisodeMenuAction action,
) async {
  final database = ref.read(databaseProvider);
  final episode = entry.episode;
  try {
    switch (action) {
      case EpisodeMenuAction.queue:
        if (episode.queueIndex == null) {
          await database.addToQueue(episode.id);
        } else {
          await database.removeFromQueue(episode.id);
        }
      case EpisodeMenuAction.played:
        await database.setPlayed(episode.id, played: !episode.played);
      case EpisodeMenuAction.favorite:
        await database.setFavorite(episode.id, favorite: !episode.favorite);
      case EpisodeMenuAction.download:
        if (episode.downloadPath == null) {
          await ref.read(downloadProgressProvider.notifier).download(episode);
          if (context.mounted) showMessage(context, 'Épisode téléchargé');
        } else {
          await ref.read(downloadServiceProvider).deleteDownload(episode);
          if (context.mounted) showMessage(context, 'Téléchargement supprimé');
        }
      case EpisodeMenuAction.share:
        final full = await database.getEpisode(episode.id);
        await shareEpisode(full ?? entry);
    }
  } catch (error) {
    if (context.mounted) showMessage(context, errorText(error));
  }
}
