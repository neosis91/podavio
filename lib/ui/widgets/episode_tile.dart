import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/download_controller.dart';
import '../../data/feed_service.dart';
import '../../data/providers.dart';
import '../../player/playback_source.dart';
import '../../player/player_controller.dart';
import '../../player/player_sheet_controller.dart';
import '../../settings/settings_controller.dart';
import '../playlist_membership.dart';
import '../router.dart';
import 'brand.dart';
import 'episode_actions_sheet.dart';
import 'highlighted_text.dart';
import 'list_metrics.dart';
import 'marquee_text.dart';
import 'playing_cover.dart';

export 'episode_actions_sheet.dart'
    show EpisodeMenuAction, runEpisodeAction, showEpisodeActionsSheet;
export 'episode_share_sheet.dart'
    show
        shareEpisode,
        shareEpisodeAsMessage,
        shareEpisodeAudioUrl,
        showShareEpisodeSheet;

class EpisodeTile extends ConsumerWidget {
  const EpisodeTile({
    super.key,
    required this.entry,
    this.showPodcast = true,
    this.reorderIndex,
    this.highlightQuery = '',
    this.queueStyle = false,
    this.playbackSource,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
    this.selecting = false,
    this.selected = false,
    this.onLongPress,
    this.onToggleSelect,
  });

  final EpisodeEntry entry;
  final bool showPodcast;
  final int? reorderIndex;
  final String highlightQuery;

  /// Ligne proche de la file du lecteur : pochette, titre, podcast, menu.
  final bool queueStyle;

  /// Liste à reprendre dans le lecteur quand la lecture part de cette ligne.
  final PlaybackSource? playbackSource;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;
  final bool selecting;
  final bool selected;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelect;

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
      listenFraction = (position.inMilliseconds / duration.inMilliseconds)
          .clamp(0.0, 1.0);
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

    if (queueStyle) {
      return _QueueStyleRow(
        entry: entry,
        playing: playing,
        progress: progress,
        preferPodcastCover: preferPodcastCover,
        reorderIndex: selecting ? null : reorderIndex,
        highlightQuery: highlightQuery,
        showPodcast: showPodcast,
        selecting: selecting,
        selected: selected,
        onLongPress: onLongPress,
        onTap: () {
          if (selecting) {
            onToggleSelect?.call();
            return;
          }
          ref
              .read(playerProvider.notifier)
              .playOrPauseEntry(entry, source: playbackSource);
        },
        onCancelDownload: () =>
            ref.read(downloadProgressProvider.notifier).cancel(episode.id),
        onMore: selecting
            ? null
            : () => showEpisodeActionsSheet(
                context,
                ref,
                entry,
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
                onRemove: onRemove,
              ),
      );
    }

    final inCustomPlaylist =
        ref
            .watch(customPlaylistEpisodeIdsProvider)
            .asData
            ?.value
            .contains(episode.id) ??
        false;
    final statusIcons = <Widget>[
      if (episode.downloadPath != null)
        Icon(
          Icons.download_for_offline,
          size: 16,
          color: theme.colorScheme.onSurface,
        ),
      if (episode.favorite)
        Icon(Icons.favorite, size: 16, color: favoriteHeartColor),
      if (episode.queueIndex != null || inCustomPlaylist)
        IconTheme(
          data: IconThemeData(color: theme.colorScheme.onSurface, size: 16),
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

        final selectedHighlight = theme.colorScheme.secondaryContainer
            .withValues(alpha: 0.45);
        return Material(
          color: selecting && selected
              ? selectedHighlight
              : playing
              ? playingHighlight
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              if (selecting) {
                onToggleSelect?.call();
                return;
              }
              context.push(AppRoutes.episode(episode.id));
            },
            onLongPress: onLongPress,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                reorderIndex != null || selecting
                    ? 4
                    : metrics.horizontalPadding,
                metrics.verticalPadding,
                4,
                metrics.verticalPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (selecting)
                    SizedBox(
                      width: 40,
                      height: coverSize,
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => onToggleSelect?.call(),
                      ),
                    )
                  else if (reorderIndex != null)
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
                    episodeId: episode.id,
                    label: episode.title,
                    colorKey: entry.podcast.title,
                    url: entry.imageUrl(preferPodcastCover: preferPodcastCover),
                    localPath: entry.imagePath(
                      preferPodcastCover: preferPodcastCover,
                    ),
                    httpHeaders: podcastAuthHeaders(
                      username: entry.podcast.authUsername,
                      password: entry.podcast.authPassword,
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
                        MarqueeText(
                          text: episode.title,
                          query: highlightQuery,
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
                      await ref
                          .read(playerProvider.notifier)
                          .playEntry(entry, source: playbackSource);
                    },
                    onMenuAction: (action) {
                      if (action == EpisodeMenuAction.queue) {
                        showPlaylistMembershipSheet(context, ref, entry);
                        return;
                      }
                      runEpisodeAction(context, ref, entry, action);
                    },
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
            const PopupMenuItem(
              value: EpisodeMenuAction.queue,
              child: Row(
                children: [
                  PlaylistAddIcon(),
                  SizedBox(width: 12),
                  Text('Playlists'),
                ],
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
    );
  }
}

/// Jaquette avec barre de progression fine en dessous (largeur = côté du carré).
class _EpisodeCoverWithProgress extends StatelessWidget {
  const _EpisodeCoverWithProgress({
    required this.episodeId,
    required this.label,
    required this.colorKey,
    required this.url,
    required this.localPath,
    required this.httpHeaders,
    required this.coverSize,
    required this.listenFraction,
    required this.progressBarHeight,
  });

  final int episodeId;
  final String label;
  final String colorKey;
  final String? url;
  final String? localPath;
  final Map<String, String>? httpHeaders;
  final double coverSize;
  final double? listenFraction;
  final double progressBarHeight;

  @override
  Widget build(BuildContext context) {
    final fraction = listenFraction;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayingEpisodeCover(
          episodeId: episodeId,
          label: label,
          colorKey: colorKey,
          url: url,
          localPath: localPath,
          httpHeaders: httpHeaders,
          size: coverSize,
          radius: 8,
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

/// Podcast, date de sortie, durée, et logos téléchargé / favori / playlist.
class EpisodeListSubtitle extends ConsumerWidget {
  const EpisodeListSubtitle({
    super.key,
    required this.entry,
    this.showPodcast = true,
    this.highlightQuery = '',
    this.style,
  });

  final EpisodeEntry entry;
  final bool showPodcast;
  final String highlightQuery;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = entry.episode;
    final scheme = Theme.of(context).colorScheme;
    final textStyle =
        style ??
        Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant);
    final seconds = episode.durationSeconds;
    final duration = seconds == null
        ? null
        : formatClock(Duration(seconds: seconds));
    final dateLabel = formatListDate(episode.publishedAt);
    final inCustomPlaylist =
        ref
            .watch(customPlaylistEpisodeIdsProvider)
            .asData
            ?.value
            .contains(episode.id) ??
        false;
    final inPlaylist = episode.queueIndex != null || inCustomPlaylist;
    final downloaded = episode.downloadPath != null;
    if (!showPodcast &&
        dateLabel.isEmpty &&
        duration == null &&
        !downloaded &&
        !episode.favorite &&
        !inPlaylist) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (showPodcast)
          Flexible(
            child: HighlightedText(
              text: entry.podcast.title,
              query: highlightQuery,
              maxLines: 1,
              style: textStyle,
            ),
          ),
        if (dateLabel.isNotEmpty) ...[
          if (showPodcast) Text(' · ', style: textStyle),
          Text(dateLabel, style: textStyle),
        ],
        if (duration != null) ...[
          if (showPodcast || dateLabel.isNotEmpty)
            Text(' · ', style: textStyle),
          Text(duration, style: textStyle),
        ],
        if (downloaded) ...[
          const SizedBox(width: 6),
          Icon(Icons.download_for_offline, size: 16, color: scheme.onSurface),
        ],
        if (episode.favorite) ...[
          const SizedBox(width: 6),
          Icon(Icons.favorite, size: 16, color: favoriteHeartColor),
        ],
        if (inPlaylist) ...[
          const SizedBox(width: 6),
          IconTheme(
            data: IconThemeData(color: scheme.onSurface, size: 16),
            child: const PlaylistPlayIcon(size: 16),
          ),
        ],
      ],
    );
  }
}

class _QueueStyleRow extends StatelessWidget {
  const _QueueStyleRow({
    required this.entry,
    required this.playing,
    required this.progress,
    required this.preferPodcastCover,
    required this.reorderIndex,
    required this.highlightQuery,
    required this.showPodcast,
    required this.onTap,
    required this.onCancelDownload,
    required this.onMore,
    this.selecting = false,
    this.selected = false,
    this.onLongPress,
  });

  final EpisodeEntry entry;
  final bool playing;
  final double? progress;
  final bool preferPodcastCover;
  final int? reorderIndex;
  final String highlightQuery;
  final bool showPodcast;
  final VoidCallback onTap;
  final VoidCallback onCancelDownload;
  final VoidCallback? onMore;
  final bool selecting;
  final bool selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final episode = entry.episode;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: episode.played ? scheme.onSurfaceVariant : scheme.onSurface,
    );
    final podcastStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final selectedHighlight = scheme.secondaryContainer.withValues(alpha: 0.45);
    final row = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.fromLTRB(selecting ? 8 : 20, 6, 8, 6),
        child: Row(
          children: [
            if (selecting)
              Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
              ),
            PlayingEpisodeCover(
              episodeId: episode.id,
              label: episode.title,
              colorKey: entry.podcast.title,
              url: entry.imageUrl(preferPodcastCover: preferPodcastCover),
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
                    query: highlightQuery,
                    style: titleStyle,
                  ),
                  EpisodeListSubtitle(
                    entry: entry,
                    showPodcast: showPodcast,
                    highlightQuery: highlightQuery,
                    style: podcastStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final dragIndex = reorderIndex;
    return Material(
      color: selecting && selected
          ? selectedHighlight
          : playing
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          children: [
            Expanded(
              child: dragIndex == null
                  ? row
                  : ReorderableDelayedDragStartListener(
                      index: dragIndex,
                      child: row,
                    ),
            ),
            if (progress != null)
              DownloadProgressRing(
                progress: progress!,
                onCancel: onCancelDownload,
              ),
            if (onMore != null)
              IconButton(
                tooltip: 'Actions',
                onPressed: onMore,
                icon: const MoreVertIcon(),
              ),
          ],
        ),
      ),
    );
  }
}

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
        minimumSize: Size(
          buttonConstraints.minWidth,
          buttonConstraints.minHeight,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: ring,
    );
  }
}
