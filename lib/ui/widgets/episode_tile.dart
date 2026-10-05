import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/download_controller.dart';
import '../../data/download_service.dart';
import '../../data/providers.dart';
import '../../player/player_controller.dart';
import '../../player/player_sheet_controller.dart';
import '../../settings/settings_controller.dart';
import '../router.dart';
import 'brand.dart';
import 'cover.dart';
import 'messages.dart';

class EpisodeTile extends ConsumerWidget {
  const EpisodeTile({
    super.key,
    required this.entry,
    this.showPodcast = true,
    this.reorderIndex,
  });

  final EpisodeEntry entry;
  final bool showPodcast;
  final int? reorderIndex;

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
    final preferPodcastCover = ref.watch(
      settingsProvider.select((s) => s.preferPodcastCover),
    );
    return InkWell(
      onTap: () => context.push(AppRoutes.episode(episode.id)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(reorderIndex != null ? 4 : 16, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (reorderIndex != null)
              Tooltip(
                message: 'Déplacer',
                child: ReorderableDragStartListener(
                  index: reorderIndex!,
                  child: const SizedBox(
                    width: 40,
                    height: 48,
                    child: Center(child: DragIndicatorIcon()),
                  ),
                ),
              ),
            PodcastCover(
              url: entry.imageUrl(preferPodcastCover: preferPodcastCover),
              localPath: entry.imagePath(preferPodcastCover: preferPodcastCover),
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
                      color: episode.played
                          ? muted
                          : theme.colorScheme.onSurface,
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
                  if (episode.favorite || episode.queueIndex != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (episode.favorite)
                            Icon(
                              Icons.favorite,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          if (episode.queueIndex != null)
                            IconTheme(
                              data: IconThemeData(
                                color: theme.colorScheme.primary,
                                size: 16,
                              ),
                              child: const PlaylistPlayIcon(size: 16),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress.clamp(0, 1) * 100).round()} %',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 6),
                    DownloadProgressRing(
                      progress: progress,
                      onCancel: () => ref
                          .read(downloadProgressProvider.notifier)
                          .cancel(episode.id),
                    ),
                  ],
                ),
              )
            else if (episode.downloadPath != null)
              IconButton(
                tooltip: playing ? 'Ouvrir le lecteur' : 'Lire',
                onPressed: () async {
                  if (playing) {
                    openPlayer(ref);
                    return;
                  }
                  await ref.read(playerProvider.notifier).playEntry(entry);
                },
                icon: Icon(playing ? Icons.graphic_eq : Icons.play_arrow),
              )
            else
              IconButton(
                tooltip: 'Télécharger',
                onPressed: () => runEpisodeAction(
                  context,
                  ref,
                  entry,
                  EpisodeMenuAction.download,
                ),
                icon: const Icon(Icons.download_outlined),
              ),
            if (progress == null)
              PopupMenuButton<EpisodeMenuAction>(
                tooltip: 'Actions',
                onSelected: (action) =>
                    runEpisodeAction(context, ref, entry, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: EpisodeMenuAction.queue,
                    child: Row(
                      children: [
                        if (episode.queueIndex == null)
                          const PlaylistAddIcon()
                        else
                          const PlaylistRemoveIcon(),
                        const SizedBox(width: 12),
                        Text(
                          episode.queueIndex == null
                              ? 'Ajouter à la playlist'
                              : 'Retirer de la playlist',
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: EpisodeMenuAction.played,
                    child: Text(
                      episode.played
                          ? 'Marquer comme non lu'
                          : 'Marquer comme lu',
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
      ),
    );
  }
}

enum EpisodeMenuAction { queue, played, favorite, download, share }

class DownloadProgressRing extends StatelessWidget {
  const DownloadProgressRing({
    super.key,
    required this.progress,
    this.onCancel,
    this.showClose = false,
    this.size = 28,
  });

  final double progress;
  final VoidCallback? onCancel;
  final bool showClose;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ring = SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            value: progress == 0 ? null : progress,
          ),
          if (showClose || onCancel != null)
            Icon(Icons.close, size: size * 0.42),
        ],
      ),
    );
    final cancel = onCancel;
    if (cancel == null) return ring;
    return IconButton(
      tooltip: 'Annuler le téléchargement',
      onPressed: cancel,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.square(size),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: ring,
    );
  }
}

Future<void> shareEpisode(EpisodeEntry entry) {
  return shareEpisodeAsMessage(entry, position: null);
}

Future<void> shareEpisodeAsMessage(
  EpisodeEntry entry, {
  Duration? position,
}) {
  final text = [
    entry.episode.title,
    entry.podcast.title,
    if (position != null && position > Duration.zero)
      'Position : ${formatClock(position)}',
    entry.episode.audioUrl,
  ].join('\n');
  return SharePlus.instance.share(
    ShareParams(text: text, title: entry.episode.title),
  );
}

Future<void> shareEpisodeAudioUrl(EpisodeEntry entry) {
  return SharePlus.instance.share(
    ShareParams(text: entry.episode.audioUrl, title: entry.episode.title),
  );
}

Future<void> showShareEpisodeSheet(
  BuildContext context,
  WidgetRef ref,
  EpisodeEntry entry,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _ShareEpisodeSheet(entry: entry),
  );
}

class _ShareEpisodeSheet extends ConsumerStatefulWidget {
  const _ShareEpisodeSheet({required this.entry});

  final EpisodeEntry entry;

  @override
  ConsumerState<_ShareEpisodeSheet> createState() => _ShareEpisodeSheetState();
}

class _ShareEpisodeSheetState extends ConsumerState<_ShareEpisodeSheet> {
  var _includePosition = false;

  Duration get _position {
    final player = ref.read(playerProvider);
    if (player.episodeId == widget.entry.episode.id) {
      return player.position;
    }
    return Duration(milliseconds: widget.entry.episode.positionMs);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final position = _position;
    final positionLabel = formatClock(position);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Partager', style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'Message',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ListTile(
              leading: const ShareIcon(),
              title: const Text('Titre et lien'),
              subtitle: const Text('Idéal pour un message'),
              onTap: () async {
                final includePosition = _includePosition;
                final pos = _position;
                Navigator.pop(context);
                await shareEpisodeAsMessage(
                  widget.entry,
                  position: includePosition ? pos : null,
                );
              },
            ),
            CheckboxListTile(
              value: _includePosition,
              onChanged: position > Duration.zero
                  ? (value) =>
                        setState(() => _includePosition = value ?? false)
                  : null,
              title: const Text('Inclure la position de lecture'),
              subtitle: Text(
                position > Duration.zero ? positionLabel : 'Aucune position',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Text(
                'Fichier',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Lien du fichier'),
              subtitle: Text(
                widget.entry.episode.audioUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                Navigator.pop(context);
                await shareEpisodeAudioUrl(widget.entry);
              },
            ),
          ],
        ),
      ),
    );
  }
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
          await ref
              .read(downloadProgressProvider.notifier)
              .deleteDownload(episode);
          if (context.mounted) showMessage(context, 'Téléchargement supprimé');
        }
      case EpisodeMenuAction.share:
        final full = await database.getEpisode(episode.id);
        if (!context.mounted) return;
        await showShareEpisodeSheet(context, ref, full ?? entry);
    }
  } on DownloadCancelled {
    return;
  } catch (error) {
    if (context.mounted) showMessage(context, errorText(error));
  }
}
