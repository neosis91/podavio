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
import '../../settings/settings_controller.dart';
import '../router.dart';
import 'brand.dart';
import 'episode_actions_sheet.dart';
import 'highlighted_text.dart';
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
    this.ecoFromShow = false,
  });

  final EpisodeEntry entry;
  final bool showPodcast;
  final int? reorderIndex;
  final String highlightQuery;

  /// Un appui lance la lecture. Sinon, il ouvre la page de l’épisode.
  /// La forme de la ligne suit la densité des listes.
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

  /// En mode éco, toutes les pochettes prennent la teinte de l’émission.
  final bool ecoFromShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = entry.episode;
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
    final ecoFromShow =
        this.ecoFromShow &&
        ref.watch(settingsProvider.select((s) => s.ecoMode));
    final playback = ref.watch(
      playerProvider.select((state) {
        if (state.episodeId != episode.id) return null;
        return (position: state.position, duration: state.duration);
      }),
    );
    final duration = playback != null && playback.duration > Duration.zero
        ? playback.duration
        : (episode.durationSeconds == null
              ? null
              : Duration(seconds: episode.durationSeconds!));
    final position =
        playback?.position ?? Duration(milliseconds: episode.positionMs);
    return _QueueStyleRow(
      entry: entry,
      density: density,
      playing: playing,
      progress: progress,
      preferPodcastCover: preferPodcastCover,
      ecoFromShow: ecoFromShow,
      reorderIndex: selecting ? null : reorderIndex,
      highlightQuery: highlightQuery,
      showPodcast: showPodcast,
      position: position,
      duration: duration,
      selecting: selecting,
      selected: selected,
      onLongPress: onLongPress,
      onTap: () {
        if (selecting) {
          onToggleSelect?.call();
          return;
        }
        if (queueStyle) {
          ref
              .read(playerProvider.notifier)
              .playOrPauseEntry(entry, source: playbackSource);
          return;
        }
        context.push(AppRoutes.episode(episode.id));
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

    final meta = [if (dateLabel.isNotEmpty) dateLabel, ?duration].join(' · ');
    final metaLabel = showPodcast && meta.isNotEmpty ? ' · $meta' : meta;
    return Row(
      children: [
        if (showPodcast)
          Flexible(
            child: HighlightedText(
              text: entry.podcast.title,
              query: highlightQuery,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        if (metaLabel.isNotEmpty)
          Flexible(
            child: Text(
              metaLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        if (downloaded) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.download_for_offline,
            size: 16,
            color: downloadActiveColor,
          ),
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

/// Barre toujours présente. À gauche le temps déjà lu, à droite le reste.
class _ListenProgress extends StatelessWidget {
  const _ListenProgress({
    required this.position,
    required this.duration,
    required this.played,
    required this.style,
  });

  final Duration position;
  final Duration? duration;
  final bool played;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final total = duration;
    final known = total != null && total > Duration.zero;
    final finished = played && position <= Duration.zero;
    final fraction = !known
        ? 0.0
        : finished
        ? 1.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final shown = !known
        ? Duration.zero
        : finished
        ? total
        : (position > total ? total : position);
    final remaining = !known
        ? Duration.zero
        : (total - shown) < Duration.zero
        ? Duration.zero
        : total - shown;

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: LinearProgressIndicator(value: fraction),
      ),
    );
    if (!known) return bar;
    return Row(
      children: [
        Text(formatClock(shown), style: style),
        const SizedBox(width: 8),
        Expanded(child: bar),
        const SizedBox(width: 8),
        Text('−${formatClock(remaining)}', style: style),
      ],
    );
  }
}

/// Ligne d’épisode selon la densité des listes.
///
/// Compact : pochette à gauche, titre et méta à côté.
/// Confortable : titre au-dessus, barre de progression sous la méta.
class EpisodeLine extends StatelessWidget {
  const EpisodeLine({
    super.key,
    required this.entry,
    required this.density,
    required this.preferPodcastCover,
    required this.position,
    required this.duration,
    this.coverSize = 48,
    this.showPodcast = true,
    this.highlightQuery = '',
    this.ecoFromShow = false,
    this.titleStyle,
    this.metaStyle,
  });

  final EpisodeEntry entry;
  final EpisodeListDensity density;
  final bool preferPodcastCover;
  final Duration position;
  final Duration? duration;
  final double coverSize;
  final bool showPodcast;
  final String highlightQuery;
  final bool ecoFromShow;
  final TextStyle? titleStyle;
  final TextStyle? metaStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final episode = entry.episode;
    final comfortable = density == EpisodeListDensity.comfortable;
    final title =
        titleStyle ??
        theme.textTheme.titleSmall?.copyWith(
          fontWeight: comfortable ? FontWeight.w600 : null,
          color: episode.played ? scheme.onSurfaceVariant : scheme.onSurface,
        );
    final meta =
        metaStyle ??
        theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final cover = PlayingEpisodeCover(
      episodeId: episode.id,
      label: episode.title,
      colorKey: entry.podcast.title,
      url: ecoFromShow
          ? entry.podcast.imageUrl
          : entry.imageUrl(preferPodcastCover: preferPodcastCover),
      localPath: ecoFromShow
          ? entry.podcast.imagePath
          : entry.imagePath(preferPodcastCover: preferPodcastCover),
      httpHeaders: podcastAuthHeaders(
        username: entry.podcast.authUsername,
        password: entry.podcast.authPassword,
      ),
      size: coverSize,
      radius: 4,
    );
    final subtitle = EpisodeListSubtitle(
      entry: entry,
      showPodcast: showPodcast,
      highlightQuery: highlightQuery,
      style: meta,
    );
    if (!comfortable) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          cover,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarqueeText(
                  text: episode.title,
                  query: highlightQuery,
                  style: title,
                ),
                subtitle,
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarqueeText(text: episode.title, query: highlightQuery, style: title),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            cover,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  subtitle,
                  const SizedBox(height: 6),
                  _ListenProgress(
                    position: position,
                    duration: duration,
                    played: episode.played,
                    style: meta,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QueueStyleRow extends StatelessWidget {
  const _QueueStyleRow({
    required this.entry,
    required this.density,
    required this.playing,
    required this.progress,
    required this.preferPodcastCover,
    required this.ecoFromShow,
    required this.reorderIndex,
    required this.highlightQuery,
    required this.showPodcast,
    required this.position,
    required this.duration,
    required this.onTap,
    required this.onCancelDownload,
    required this.onMore,
    this.selecting = false,
    this.selected = false,
    this.onLongPress,
  });

  final EpisodeEntry entry;
  final EpisodeListDensity density;
  final bool playing;
  final double? progress;
  final bool preferPodcastCover;
  final bool ecoFromShow;
  final int? reorderIndex;
  final String highlightQuery;
  final bool showPodcast;
  final Duration position;
  final Duration? duration;
  final VoidCallback onTap;
  final VoidCallback onCancelDownload;
  final VoidCallback? onMore;
  final bool selecting;
  final bool selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedHighlight = scheme.secondaryContainer.withValues(alpha: 0.45);
    final row = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.fromLTRB(selecting ? 8 : 20, 6, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (selecting) Checkbox(value: selected, onChanged: (_) => onTap()),
            Expanded(
              child: EpisodeLine(
                entry: entry,
                density: density,
                preferPodcastCover: preferPodcastCover,
                ecoFromShow: ecoFromShow,
                highlightQuery: highlightQuery,
                showPodcast: showPodcast,
                position: position,
                duration: duration,
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
