import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/download_controller.dart';
import '../../data/download_service.dart';
import '../../data/feed_service.dart';
import '../../data/online_status.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../player/player_controller.dart';
import '../../player/player_sheet_controller.dart';
import '../../settings/settings_controller.dart';
import '../playlist_membership.dart';
import '../router.dart';
import 'app_bottom_sheet.dart';
import 'brand.dart';
import 'cover.dart';
import 'episode_share_sheet.dart';
import 'marquee_text.dart';
import 'messages.dart';

enum EpisodeMenuAction { queue, played, favorite, download, share }

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
  return showAppModalBottomSheet<void>(
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
          label: context.tr(carMode ? 'Exit car mode' : 'Car mode'),
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
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
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
                              MarqueeText(
                                text: episode.title,
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

Future<bool> _confirmMobileDataDownload(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('Mobile data')),
      content: Text(context.tr('This download will use mobile data.')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.tr('Download')),
        ),
      ],
    ),
  );
  return accepted ?? false;
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
          final blocked = mobileDataBlocksDownload(
            allowMobileData: ref.read(settingsProvider).allowMobileData,
            mobileDataActive: await ref.read(mobileDataProbeProvider)(),
          );
          if (blocked) {
            if (!context.mounted) return;
            final accepted = await _confirmMobileDataDownload(context);
            if (!accepted || !context.mounted) return;
          }
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
