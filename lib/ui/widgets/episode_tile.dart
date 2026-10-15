import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../l10n/l10n.dart';
import '../../data/app_database.dart';
import '../../data/download_controller.dart';
import '../../data/feed_service.dart';
import '../../data/download_service.dart';
import '../../data/providers.dart';
import '../../player/playback_source.dart';
import '../../player/player_controller.dart';
import '../../player/player_sheet_controller.dart';
import '../../settings/settings_controller.dart';
import '../playlist_membership.dart';
import '../router.dart';
import 'brand.dart';
import 'cover.dart';
import 'playing_cover.dart';
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
    this.queueStyle = false,
    this.playbackSource,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
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
        reorderIndex: reorderIndex,
        highlightQuery: highlightQuery,
        showPodcast: showPodcast,
        onTap: () => ref
            .read(playerProvider.notifier)
            .playOrPauseEntry(entry, source: playbackSource),
        onCancelDownload: () =>
            ref.read(downloadProgressProvider.notifier).cancel(episode.id),
        onMore: () => showEpisodeActionsSheet(
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
                    episodeId: episode.id,
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
    required this.url,
    required this.localPath,
    required this.httpHeaders,
    required this.coverSize,
    required this.listenFraction,
    required this.progressBarHeight,
  });

  final int episodeId;
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

enum EpisodeMenuAction { queue, played, favorite, download, share }

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
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final episode = entry.episode;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final podcastStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
        child: Row(
          children: [
            PlayingEpisodeCover(
              episodeId: episode.id,
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
                  HighlightedText(
                    text: episode.title,
                    query: highlightQuery,
                    maxLines: 1,
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
      color: playing
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

Future<void> shareEpisode(EpisodeEntry entry) {
  return shareEpisodeAsMessage(entry, position: null);
}

Future<void> shareEpisodeAsMessage(EpisodeEntry entry, {Duration? position}) {
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
                  ? (value) => setState(() => _includePosition = value ?? false)
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

Future<void> showEpisodeActionsSheet(
  BuildContext context,
  WidgetRef ref,
  EpisodeEntry entry, {
  VoidCallback? onMoveUp,
  VoidCallback? onMoveDown,
  VoidCallback? onRemove,
  bool fromPlayer = false,
  VoidCallback? onSpeed,
  VoidCallback? onSleep,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    builder: (sheetContext) {
      final sheet = _EpisodeActionsSheet(
        episodeId: entry.episode.id,
        fallback: entry,
        fromPlayer: fromPlayer,
        onOpenEpisode: () {
          Navigator.pop(sheetContext);
          if (fromPlayer) ref.read(playerSheetProvider.notifier).collapse();
          context.push(AppRoutes.episode(entry.episode.id));
        },
        onOpenPodcast: (podcastId) {
          Navigator.pop(sheetContext);
          if (fromPlayer) ref.read(playerSheetProvider.notifier).collapse();
          context.push(AppRoutes.podcast(podcastId));
        },
        onShare: (current) async {
          Navigator.pop(sheetContext);
          await showShareEpisodeSheet(context, ref, current);
        },
        onPlaylists: (current) async {
          Navigator.pop(sheetContext);
          await showPlaylistMembershipSheet(context, ref, current);
        },
        onMoveUp: onMoveUp == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                onMoveUp();
              },
        onMoveDown: onMoveDown == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                onMoveDown();
              },
        onRemove: onRemove == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                onRemove();
              },
        onSpeed: onSpeed == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                onSpeed();
              },
        onSleep: onSleep == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                onSleep();
              },
      );
      if (!fromPlayer) return sheet;
      final theme = _themeAbovePlayer(context);
      if (theme == null) return sheet;
      return Theme(data: theme, child: sheet);
    },
  );
}

/// Thème de l’application, au-dessus du thème teinté par la pochette.
ThemeData? _themeAbovePlayer(BuildContext context) {
  var seenTheme = false;
  ThemeData? outer;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is! Theme) return true;
    if (!seenTheme) {
      seenTheme = true;
      return true;
    }
    outer = widget.data;
    return false;
  });
  return outer;
}

class _EpisodeActionsSheet extends ConsumerWidget {
  const _EpisodeActionsSheet({
    required this.episodeId,
    required this.fallback,
    required this.onOpenEpisode,
    required this.onOpenPodcast,
    required this.onShare,
    required this.onPlaylists,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
    this.onSpeed,
    this.onSleep,
    this.fromPlayer = false,
  });

  final int episodeId;
  final EpisodeEntry fallback;
  final bool fromPlayer;
  final VoidCallback onOpenEpisode;
  final ValueChanged<int> onOpenPodcast;
  final Future<void> Function(EpisodeEntry entry) onShare;
  final Future<void> Function(EpisodeEntry entry) onPlaylists;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;
  final VoidCallback? onSpeed;
  final VoidCallback? onSleep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry =
        ref.watch(episodeProvider(episodeId)).asData?.value ?? fallback;
    final episode = entry.episode;
    final progress = ref.watch(
      downloadProgressProvider.select((items) => items[episode.id]),
    );
    final downloading = progress != null;
    final preferPodcastCover = ref.watch(
      settingsProvider.select((settings) => settings.preferPodcastCover),
    );
    final playingId = ref.watch(
      playerProvider.select((state) => state.episodeId),
    );
    final carMode = ref.watch(playerProvider.select((state) => state.carMode));
    final speed = fromPlayer
        ? ref.watch(playerProvider.select((state) => state.speed))
        : null;
    final sleepDetail = fromPlayer
        ? ref.watch(playerProvider.select(_playerSleepDetail))
        : null;
    final website = fromPlayer ? _podcastWebsite(entry.podcast.link) : null;

    final actions = <Widget>[
      _SheetAction(
        icon: Icon(
          episode.favorite ? Icons.favorite : Icons.favorite_border,
          size: 30,
          color: episode.favorite ? favoriteHeartColor : null,
        ),
        iconPadding: 10,
        label: context.tr(episode.favorite ? 'Liked' : 'Like'),
        onTap: () => ref
            .read(databaseProvider)
            .setFavorite(episode.id, favorite: !episode.favorite),
      ),
      _SheetAction(
        icon: Icon(
          downloading
              ? Icons.downloading
              : episode.downloadPath != null
              ? Icons.download_for_offline
              : Icons.download_for_offline_outlined,
          color: episode.downloadPath != null ? const Color(0xFF00A0CB) : null,
        ),
        label: context.tr(
          downloading
              ? 'Downloading'
              : episode.downloadPath != null
              ? 'Saved'
              : 'Download',
        ),
        detail: progress == null ? null : '${(progress * 100).round()} %',
        onTap: downloading
            ? null
            : () => runEpisodeAction(
                context,
                ref,
                entry,
                EpisodeMenuAction.download,
              ),
      ),
      if (playingId != episode.id)
        _SheetAction(
          icon: const Icon(Icons.play_circle),
          label: context.tr('Play next'),
          onTap: () async {
            await ref
                .read(databaseProvider)
                .queueNext(episode.id, afterEpisodeId: playingId);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      _SheetAction(
        icon: const PlaylistAddIcon(),
        label: context.tr('Playlists'),
        onTap: () => onPlaylists(entry),
      ),
      _SheetAction(
        icon: const SubscriptionsIcon(),
        label: entry.podcast.title,
        onTap: () => onOpenPodcast(entry.podcast.id),
      ),
      _SheetAction(
        icon: const ShareIcon(),
        label: context.tr('Share'),
        onTap: () async {
          final full = await ref.read(databaseProvider).getEpisode(episode.id);
          if (!context.mounted) return;
          await onShare(full ?? entry);
        },
      ),
      if (onMoveUp != null)
        _SheetAction(
          icon: const MoveUpIcon(),
          label: context.tr('Move up'),
          onTap: onMoveUp,
        ),
      if (onMoveDown != null)
        _SheetAction(
          icon: const MoveDownIcon(),
          label: context.tr('Move down'),
          onTap: onMoveDown,
        ),
      if (onRemove != null)
        _SheetAction(
          icon: const DeleteIcon(),
          label: context.tr('Delete'),
          onTap: onRemove,
        ),
      if (onSpeed != null && speed != null)
        _SheetAction(
          icon: const Icon(Icons.speed),
          label: context.tr('Speed'),
          detail: _playbackSpeedLabel(speed),
          onTap: onSpeed,
        ),
      if (onSleep != null)
        _SheetAction(
          icon: const TimerIcon(),
          label: context.tr('Sleep timer'),
          detail: sleepDetail,
          onTap: onSleep,
        ),
      if (fromPlayer)
        _SheetAction(
          icon: Icon(
            carMode ? Icons.directions_car : Icons.directions_car_outlined,
          ),
          label: context.tr(
            carMode ? 'Exit car mode' : 'Car mode',
          ),
          onTap: () {
            ref.read(playerProvider.notifier).setCarMode(!carMode);
            Navigator.pop(context);
          },
        ),
      if (website != null)
        _SheetAction(
          icon: const LinkIcon(),
          label: context.tr('Open website'),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(context);
            final opened = await launchUrl(
              website,
              mode: LaunchMode.externalApplication,
            );
            if (!opened) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Impossible d’ouvrir le site web'),
                ),
              );
            }
          },
        ),
    ];

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const SizedBox(width: 32, height: 4),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onOpenEpisode,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                    child: Row(
                      children: [
                        PodcastCover(
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
                          size: 44,
                          radius: 6,
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
                                style: theme.textTheme.labelSmall,
                              ),
                              Text(
                                entry.podcast.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: scheme.outlineVariant,
                  ),
                ),
                const SizedBox(height: 2),
                ...actions,
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconPadding = 12,
    this.detail,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final double iconPadding;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final color = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.all(iconPadding),
              child: IconTheme(
                data: IconThemeData(color: color, size: 24),
                child: icon,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: color),
              ),
            ),
            if (detail != null) ...[
              const SizedBox(width: 8),
              Text(
                detail!,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _playbackSpeedLabel(double speed) {
  final text = speed == speed.roundToDouble()
      ? speed.toInt().toString()
      : speed.toString();
  return '$text×';
}

/// Temps restant du minuteur, ou « Fin de l’épisode ». `null` s’il est arrêté.
String? _playerSleepDetail(PlayerUiState state) {
  if (state.sleepAtEnd) return 'Fin de l’épisode';
  final remaining = state.sleepRemaining;
  if (remaining == null) return null;
  return formatClock(remaining);
}

Uri? _podcastWebsite(String? link) {
  final raw = link?.trim();
  if (raw == null || raw.isEmpty) return null;
  final withScheme = raw.contains('://') ? raw : 'https://$raw';
  final uri = Uri.tryParse(withScheme);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
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
