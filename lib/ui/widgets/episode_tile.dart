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
import 'highlighted_text.dart';
import 'list_metrics.dart';
import 'messages.dart';

class EpisodeTile extends ConsumerWidget {
  const EpisodeTile({
    super.key,
    required this.entry,
    this.showPodcast = true,
    this.reorderIndex,
    this.highlightQuery = '',
  });

  final EpisodeEntry entry;
  final bool showPodcast;
  final int? reorderIndex;
  final String highlightQuery;

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
    final density = ref.watch(
      settingsProvider.select((s) => s.episodeListDensity),
    );
    final preferPodcastCover = ref.watch(
      settingsProvider.select((s) => s.preferPodcastCover),
    );
    final duration = episode.durationSeconds == null
        ? null
        : Duration(seconds: episode.durationSeconds!);
    final position = Duration(milliseconds: episode.positionMs);
    final double? listenFraction;
    if (!episode.played &&
        position > Duration.zero &&
        duration != null &&
        duration > Duration.zero) {
      listenFraction =
          (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    } else {
      listenFraction = null;
    }
    final showListenProgress = listenFraction != null;
    final dateLabel = formatListDate(episode.publishedAt);
    final metaParts = <String>[
      if (dateLabel.isNotEmpty) dateLabel,
      if (duration != null) formatClock(duration),
      // « reste » uniquement page podcast, et seulement sans barre de progression.
      if (!showPodcast &&
          !showListenProgress &&
          !episode.played &&
          position > Duration.zero &&
          duration != null)
        'reste ${formatClock(duration - position)}',
    ];
    final metaSuffix = metaParts.join(' · ');

    final statusIcons = <Widget>[
      if (episode.favorite)
        Icon(Icons.favorite, size: 16, color: theme.colorScheme.primary),
      if (episode.queueIndex != null)
        IconTheme(
          data: IconThemeData(color: theme.colorScheme.primary, size: 16),
          child: const PlaylistPlayIcon(size: 16),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = EpisodeTileMetrics.resolve(
          width: constraints.maxWidth,
          textTheme: theme.textTheme,
          textScaler: MediaQuery.textScalerOf(context),
          density: density,
          played: episode.played,
          onSurface: theme.colorScheme.onSurface,
          muted: theme.colorScheme.onSurfaceVariant,
        );
        final coverSize = metrics.coverSize;
        final playingHighlight = theme.colorScheme.primaryContainer.withValues(
          alpha: 0.35,
        );

        return Material(
          color: playing ? playingHighlight : Colors.transparent,
          child: InkWell(
            onTap: () => context.push(AppRoutes.episode(episode.id)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                reorderIndex != null ? 4 : metrics.horizontalPadding,
                metrics.verticalPadding,
                4,
                metrics.verticalPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (reorderIndex != null)
                    Tooltip(
                      message: 'Déplacer',
                      child: ReorderableDragStartListener(
                        index: reorderIndex!,
                        child: SizedBox(
                          width: 40,
                          height: coverSize,
                          child: const Center(child: DragIndicatorIcon()),
                        ),
                      ),
                    ),
                  _EpisodeCoverWithProgress(
                    url: entry.imageUrl(preferPodcastCover: preferPodcastCover),
                    localPath: entry.imagePath(
                      preferPodcastCover: preferPodcastCover,
                    ),
                    coverSize: coverSize,
                    listenFraction: listenFraction,
                    progressBarHeight: metrics.progressBarHeight,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HighlightedText(
                          text: episode.title,
                          query: highlightQuery,
                          maxLines: 2,
                          style: metrics.titleStyle,
                        ),
                        SizedBox(height: metrics.gap),
                        _EpisodeMetaRow(
                          showPodcast: showPodcast,
                          podcastTitle: entry.podcast.title,
                          metaSuffix: metaSuffix,
                          style: metrics.metaStyle,
                          statusIcons: statusIcons,
                          highlightQuery: highlightQuery,
                        ),
                      ],
                    ),
                  ),
                  _EpisodeTileTrailing(
                    metrics: metrics,
                    progress: progress,
                    downloaded: episode.downloadPath != null,
                    playing: playing,
                    episode: episode,
                    onCancelDownload: () => ref
                        .read(downloadProgressProvider.notifier)
                        .cancel(episode.id),
                    onPlay: () async {
                      if (playing) {
                        openPlayer(ref);
                        return;
                      }
                      await ref.read(playerProvider.notifier).playEntry(entry);
                    },
                    onMenuAction: (action) =>
                        runEpisodeAction(context, ref, entry, action),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Actions trailing : anneau DL (+ % hors étroit), play si téléchargé, sinon menu.
class _EpisodeTileTrailing extends StatelessWidget {
  const _EpisodeTileTrailing({
    required this.metrics,
    required this.progress,
    required this.downloaded,
    required this.playing,
    required this.episode,
    required this.onCancelDownload,
    required this.onPlay,
    required this.onMenuAction,
  });

  final EpisodeTileMetrics metrics;
  final double? progress;
  final bool downloaded;
  final bool playing;
  final Episode episode;
  final VoidCallback onCancelDownload;
  final VoidCallback onPlay;
  final ValueChanged<EpisodeMenuAction> onMenuAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = progress;

    if (value != null) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (metrics.showDownloadPercent) ...[
              Text(
                '${(value.clamp(0, 1) * 100).round()} %',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
            ],
            DownloadProgressRing(
              progress: value,
              size: metrics.progressRingSize,
              onCancel: onCancelDownload,
              visualDensity: metrics.trailingVisualDensity,
              constraints: metrics.trailingConstraints,
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (downloaded)
          IconButton(
            tooltip: playing ? 'Ouvrir le lecteur' : 'Lire',
            onPressed: onPlay,
            visualDensity: metrics.trailingVisualDensity,
            constraints: metrics.trailingConstraints,
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.square(metrics.trailingMinSize),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(playing ? Icons.graphic_eq : Icons.play_arrow),
          ),
        PopupMenuButton<EpisodeMenuAction>(
          tooltip: 'Actions',
          onSelected: onMenuAction,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.square(metrics.trailingMinSize),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: metrics.trailingVisualDensity,
          ),
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
    );
  }
}

/// Jaquette avec barre de progression fine en dessous (largeur = côté du carré).
class _EpisodeCoverWithProgress extends StatelessWidget {
  const _EpisodeCoverWithProgress({
    required this.url,
    required this.localPath,
    required this.coverSize,
    required this.listenFraction,
    required this.progressBarHeight,
  });

  final String? url;
  final String? localPath;
  final double coverSize;
  final double? listenFraction;
  final double progressBarHeight;

  @override
  Widget build(BuildContext context) {
    final fraction = listenFraction;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PodcastCover(
          url: url,
          localPath: localPath,
          size: coverSize,
        ),
        if (fraction != null) ...[
          const SizedBox(height: 2),
          SizedBox(
            width: coverSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: progressBarHeight,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Ligne méta alignée à gauche : podcast · date · durée [· reste] + icônes.
/// Le podcast est ellipsisé en premier ; méta et icônes restent à sa suite.
class _EpisodeMetaRow extends StatelessWidget {
  const _EpisodeMetaRow({
    required this.showPodcast,
    required this.podcastTitle,
    required this.metaSuffix,
    required this.style,
    required this.statusIcons,
    this.highlightQuery = '',
  });

  final bool showPodcast;
  final String podcastTitle;
  final String metaSuffix;
  final TextStyle style;
  final List<Widget> statusIcons;
  final String highlightQuery;

  @override
  Widget build(BuildContext context) {
    final hasMeta = metaSuffix.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (showPodcast)
                Flexible(
                  child: HighlightedText(
                    text: podcastTitle.isEmpty ? ' ' : podcastTitle,
                    query: highlightQuery,
                    maxLines: 1,
                    style: style,
                  ),
                )
              else if (hasMeta)
                Flexible(
                  child: Text(
                    metaSuffix,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                )
              else
                const Text(' '),
              if (showPodcast && hasMeta)
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    ' · $metaSuffix',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
            ],
          ),
        ),
        if (statusIcons.isNotEmpty) ...[
          const SizedBox(width: 8),
          ..._spacedIcons(statusIcons),
        ],
      ],
    );
  }
}

List<Widget> _spacedIcons(List<Widget> icons) {
  if (icons.length <= 1) return icons;
  final out = <Widget>[icons.first];
  for (var i = 1; i < icons.length; i++) {
    out
      ..add(const SizedBox(width: 6))
      ..add(icons[i]);
  }
  return out;
}

enum EpisodeMenuAction { queue, played, favorite, download, share }

class DownloadProgressRing extends StatelessWidget {
  const DownloadProgressRing({
    super.key,
    required this.progress,
    this.onCancel,
    this.showClose = false,
    this.size = 28,
    this.visualDensity = VisualDensity.compact,
    this.constraints,
  });

  final double progress;
  final VoidCallback? onCancel;
  final bool showClose;
  final double size;
  final VisualDensity visualDensity;
  final BoxConstraints? constraints;

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
    final buttonConstraints =
        constraints ?? BoxConstraints.tightFor(width: size, height: size);
    return IconButton(
      tooltip: 'Annuler le téléchargement',
      onPressed: cancel,
      padding: EdgeInsets.zero,
      visualDensity: visualDensity,
      constraints: buttonConstraints,
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size(buttonConstraints.minWidth, buttonConstraints.minHeight),
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
