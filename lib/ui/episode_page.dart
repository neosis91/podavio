import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/app_database.dart';
import '../data/download_controller.dart';
import '../data/feed_service.dart';
import '../data/providers.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'playlist_membership.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_tile.dart';
import 'widgets/show_notes.dart';

class EpisodePage extends ConsumerWidget {
  const EpisodePage({super.key, required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = ref.watch(episodeProvider(episodeId));
    return episode.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          title: 'Épisode indisponible',
          message: error.toString(),
        ),
      ),
      data: (entry) {
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              title: 'Épisode introuvable',
              message: 'Cet épisode n’est plus dans la bibliothèque.',
            ),
          );
        }
        return _EpisodeDetail(entry: entry);
      },
    );
  }
}

class _EpisodeDetail extends ConsumerWidget {
  const _EpisodeDetail({required this.entry});

  final EpisodeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final episode = entry.episode;
    final player = ref.watch(playerProvider);
    final current = player.episodeId == episode.id;
    final playing = current && player.playing;
    final progress = ref.watch(
      downloadProgressProvider.select((items) => items[episode.id]),
    );
    final duration = episode.durationSeconds == null
        ? null
        : Duration(seconds: episode.durationSeconds!);
    final position = current
        ? player.position
        : Duration(milliseconds: episode.positionMs);
    final total = current && player.duration > Duration.zero
        ? player.duration
        : duration;
    final fraction = total == null || total == Duration.zero
        ? null
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final hasNotes = plainText(episode.description).isNotEmpty;
    final meta = [
      formatDate(episode.publishedAt),
      if (total != null) formatClock(total),
      if (!episode.played && position > Duration.zero && total != null)
        'reste ${formatClock(total - position)}',
    ].where((part) => part.isNotEmpty).join(' · ');
    final downloaded = episode.downloadPath != null;
    final playLabel = playing
        ? 'Pause'
        : position > Duration.zero
        ? 'Reprendre'
        : downloaded
        ? 'Lecture'
        : 'Streaming';
    final usePlayPause = playing || downloaded || position > Duration.zero;
    final preferPodcastCover = ref.watch(
      settingsProvider.select((s) => s.preferPodcastCover),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.podcast.title, overflow: TextOverflow.ellipsis),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Center(
                child: PodcastCover(
                  url: entry.imageUrl(preferPodcastCover: preferPodcastCover),
                  localPath: entry.imagePath(
                    preferPodcastCover: preferPodcastCover,
                  ),
                  httpHeaders: podcastAuthHeaders(
                    username: entry.podcast.authUsername,
                    password: entry.podcast.authPassword,
                  ),
                  size: 200,
                  radius: 16,
                ),
              ),
              const SizedBox(height: 20),
              Text(episode.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => context.push(AppRoutes.podcast(entry.podcast.id)),
                child: Text(
                  entry.podcast.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _togglePlayback(ref, current),
                      icon: usePlayPause
                          ? PlayPauseIcon(playing: playing, size: 20)
                          : const Icon(Icons.podcasts),
                      label: Text(playLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _downloadButton(context, ref, progress)),
                ],
              ),
              if (fraction != null && position > Duration.zero) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: fraction, minHeight: 4),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  _DetailAction(
                    icon: const PlaylistAddIcon(),
                    label: 'Playlists',
                    selected:
                        episode.queueIndex != null ||
                        (ref
                                .watch(customPlaylistIdsProvider(episode.id))
                                .asData
                                ?.value
                                .isNotEmpty ??
                            false),
                    onPressed: () =>
                        showPlaylistMembershipSheet(context, ref, entry),
                  ),
                  _DetailAction(
                    icon: Icon(
                      episode.favorite
                          ? Icons.favorite
                          : Icons.favorite_outline,
                      color: episode.favorite ? favoriteHeartColor : null,
                    ),
                    label: 'Favori',
                    selected: episode.favorite,
                    onPressed: () => runEpisodeAction(
                      context,
                      ref,
                      entry,
                      EpisodeMenuAction.favorite,
                    ),
                  ),
                  _DetailAction(
                    icon: Icon(
                      episode.played
                          ? Icons.mark_email_unread_outlined
                          : Icons.check_circle_outline,
                    ),
                    label: episode.played ? 'Non lu' : 'Lu',
                    selected: episode.played,
                    onPressed: () => runEpisodeAction(
                      context,
                      ref,
                      entry,
                      EpisodeMenuAction.played,
                    ),
                  ),
                  _DetailAction(
                    icon: const Icon(Icons.share_outlined),
                    label: 'Partager',
                    onPressed: () => runEpisodeAction(
                      context,
                      ref,
                      entry,
                      EpisodeMenuAction.share,
                    ),
                  ),
                ],
              ),
              if (hasNotes) ...[
                const SizedBox(height: 24),
                Text('Notes', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ShowNotes(
                  html: episode.description,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _downloadButton(
    BuildContext context,
    WidgetRef ref,
    double? progress,
  ) {
    if (progress != null) {
      final label = progress == 0
          ? 'Téléchargement'
          : '${(progress * 100).round()} %';
      return OutlinedButton.icon(
        onPressed: () => ref
            .read(downloadProgressProvider.notifier)
            .cancel(entry.episode.id),
        icon: DownloadProgressRing(
          progress: progress,
          size: 22,
          showClose: true,
        ),
        label: Text(label),
      );
    }
    final downloaded = entry.episode.downloadPath != null;
    return OutlinedButton.icon(
      onPressed: () =>
          runEpisodeAction(context, ref, entry, EpisodeMenuAction.download),
      icon: Icon(downloaded ? Icons.delete_outline : Icons.download_outlined),
      label: Text(downloaded ? 'Supprimer' : 'Télécharger'),
    );
  }

  Future<void> _togglePlayback(WidgetRef ref, bool current) async {
    final player = ref.read(playerProvider.notifier);
    if (current) {
      await player.toggle();
      return;
    }
    await player.playEntry(entry);
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 88,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              IconTheme(
                data: IconThemeData(color: color, size: 24),
                child: icon,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
