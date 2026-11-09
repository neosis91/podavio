import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/app_database.dart';
import '../data/download_controller.dart';
import '../data/feed_service.dart';
import '../data/providers.dart';
import '../l10n/l10n.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'playlist_membership.dart';
import 'podcast/cover_palette.dart';
import 'podcast/podcast_album_header.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_tile.dart';
import 'widgets/frosted_header.dart';
import 'widgets/marquee_text.dart';

class EpisodePage extends ConsumerWidget {
  const EpisodePage({super.key, required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = ref.watch(episodeProvider(episodeId));
    return episode.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => FrostedScaffold(
        appBar: FrostedAppBar(),
        body: EmptyState(
          title: 'Épisode indisponible',
          message: error.toString(),
        ),
      ),
      data: (entry) {
        if (entry == null) {
          return FrostedScaffold(
            appBar: FrostedAppBar(),
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

class _EpisodeDetail extends ConsumerStatefulWidget {
  const _EpisodeDetail({required this.entry});

  final EpisodeEntry entry;

  @override
  ConsumerState<_EpisodeDetail> createState() => _EpisodeDetailState();
}

class _EpisodeDetailState extends ConsumerState<_EpisodeDetail> {
  final _scrollController = ScrollController();
  var _pastCover = false;

  EpisodeEntry get entry => widget.entry;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onCoverScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onCoverScroll());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onCoverScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final size = MediaQuery.sizeOf(context);
    final bar = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final past = _scrollController.offset > episodeCoverSide(size) - bar;
    if (past != _pastCover) setState(() => _pastCover = past);
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.podcast(entry.podcast.id));
  }

  void _toggleFavorite() {
    final episode = entry.episode;
    ref
        .read(databaseProvider)
        .setFavorite(episode.id, favorite: !episode.favorite);
  }

  @override
  Widget build(BuildContext context) {
    final episode = entry.episode;
    final player = ref.watch(playerProvider);
    final current = player.episodeId == episode.id;
    final playing = current && player.playing;
    final progress = ref.watch(
      downloadProgressProvider.select((items) => items[episode.id]),
    );
    final preferPodcastCover = ref.watch(
      settingsProvider.select((settings) => settings.preferPodcastCover),
    );
    final imageUrl = entry.imageUrl(preferPodcastCover: preferPodcastCover);
    final imagePath = entry.imagePath(preferPodcastCover: preferPodcastCover);
    final eco = ref.watch(
      settingsProvider.select((settings) => settings.ecoMode),
    );
    final background = eco
        ? Colors.black
        : ref
                  .watch(
                    podcastCoverColorProvider(
                      coverColorToken(path: imagePath, url: imageUrl),
                    ),
                  )
                  .asData
                  ?.value ??
              Colors.black;
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
    final meta = [
      formatDate(episode.publishedAt),
      if (total != null) formatClock(total),
      if (!episode.played && position > Duration.zero && total != null)
        'reste ${formatClock(total - position)}',
    ].where((part) => part.isNotEmpty).join(' · ');
    final playLabel = playing
        ? 'Pause'
        : position > Duration.zero
        ? 'Reprendre'
        : episode.downloadPath != null
        ? 'Lecture'
        : 'Streaming';

    final baseTheme = Theme.of(context);
    final immersiveScheme = ColorScheme.dark(
      primary: const Color(0xFF00B0FF),
      onPrimary: Colors.black,
      secondary: Colors.white70,
      surface: background,
      onSurface: Colors.white,
      onSurfaceVariant: Colors.white.withValues(alpha: 0.74),
      secondaryContainer: Colors.white.withValues(alpha: 0.18),
      onSecondaryContainer: Colors.white,
      primaryContainer: Colors.white.withValues(alpha: 0.16),
      onPrimaryContainer: Colors.white,
    );
    final lightOnPage = baseTheme.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );
    final pageTheme = baseTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: immersiveScheme,
      textTheme: lightOnPage,
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colors.white,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white,
        textColor: Colors.white,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: pageTheme,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: background),
          duration: const Duration(milliseconds: 500),
          builder: (context, color, child) {
            return FrostedScaffold(
              scrolled: _pastCover,
              appBar: FrostedAppBar(
                revealOnScroll: true,
                automaticallyImplyLeading: false,
                leading: BackButton(onPressed: _leave),
                title: MarqueeText(
                  text: episode.title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: Colors.white),
                ),
                actions: [
                  _HeartButton(
                    favorite: episode.favorite,
                    onPressed: _toggleFavorite,
                  ),
                ],
              ),
              body: ColoredBox(color: color ?? Colors.black, child: child),
            );
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _EpisodeCover(
                  entry: entry,
                  imageUrl: imageUrl,
                  imagePath: imagePath,
                  fadeColor: background,
                  meta: meta,
                  playLabel: playLabel,
                  playing: playing,
                  progress: progress,
                  onBack: _leave,
                  onFavorite: _toggleFavorite,
                  onPlay: () => _togglePlayback(current),
                  onDownload: () => _onDownload(progress),
                  onPlaylist: () =>
                      showPlaylistMembershipSheet(context, ref, entry),
                  onPlayed: () => runEpisodeAction(
                    context,
                    ref,
                    entry,
                    EpisodeMenuAction.played,
                  ),
                  onShare: () => runEpisodeAction(
                    context,
                    ref,
                    entry,
                    EpisodeMenuAction.share,
                  ),
                ),
              ),
              if (fraction != null && position > Duration.zero)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 4, 32, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 4,
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: PodcastDescription(html: episode.description),
              ),
              SliverToBoxAdapter(
                child: _EpisodePodcastShelf(podcast: entry.podcast),
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _togglePlayback(bool current) async {
    final player = ref.read(playerProvider.notifier);
    if (current) {
      await player.toggle();
      return;
    }
    await player.playEntry(entry);
  }

  void _onDownload(double? progress) {
    if (progress != null) {
      ref.read(downloadProgressProvider.notifier).cancel(entry.episode.id);
      return;
    }
    runEpisodeAction(context, ref, entry, EpisodeMenuAction.download);
  }
}

class _EpisodePodcastShelf extends StatelessWidget {
  const _EpisodePodcastShelf({required this.podcast});

  final Podcast podcast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Text(
            'Le podcast',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              SizedBox(
                width: 160,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.push(AppRoutes.podcast(podcast.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: Stack(
                          children: [
                            PodcastCover(
                              url: podcast.imageUrl,
                              localPath: podcast.imagePath,
                              label: podcast.title,
                              colorKey: podcast.title,
                              httpHeaders: podcastAuthHeaders(
                                username: podcast.authUsername,
                                password: podcast.authPassword,
                              ),
                              size: 160,
                              radius: 10,
                            ),
                            if (podcast.preferred)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface.withValues(
                                      alpha: 0.92,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: PreferredStarIcon(
                                      selected: true,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        podcast.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Côté de la jaquette carrée. En portrait elle prend toute la largeur.
double episodeCoverSide(Size size) {
  if (size.width > size.height) {
    return (size.height * 0.72).clamp(0.0, size.width);
  }
  return size.width;
}

class _EpisodeCover extends StatelessWidget {
  const _EpisodeCover({
    required this.entry,
    required this.imageUrl,
    required this.imagePath,
    required this.fadeColor,
    required this.meta,
    required this.playLabel,
    required this.playing,
    required this.progress,
    required this.onBack,
    required this.onFavorite,
    required this.onPlay,
    required this.onDownload,
    required this.onPlaylist,
    required this.onPlayed,
    required this.onShare,
  });

  final EpisodeEntry entry;
  final String? imageUrl;
  final String? imagePath;
  final Color fadeColor;
  final String meta;
  final String playLabel;
  final bool playing;
  final double? progress;
  final VoidCallback onBack;
  final VoidCallback onFavorite;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onPlaylist;
  final VoidCallback onPlayed;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final episode = entry.episode;
    final top = statusBarInset(context);
    final side = episodeCoverSide(MediaQuery.sizeOf(context));
    final headers = podcastAuthHeaders(
      username: entry.podcast.authUsername,
      password: entry.podcast.authPassword,
    );
    final downloaded = episode.downloadPath != null;

    return Column(
      children: [
        Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PodcastCover(
                  url: imageUrl,
                  localPath: imagePath,
                  label: episode.title,
                  colorKey: entry.podcast.title,
                  httpHeaders: headers,
                  radius: 0,
                  expand: true,
                  fit: BoxFit.contain,
                  ecoTintFromImage: true,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: side * 0.7,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: artworkScrim(fadeColor),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 16,
                  child: Column(
                    children: [
                      Text(
                        episode.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () =>
                            context.push(AppRoutes.podcast(entry.podcast.id)),
                        child: Text(
                          entry.podcast.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xC4FFFFFF)),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: top + 12,
                  left: 12,
                  child: _CoverIconButton(
                    tooltip: 'Retour',
                    onPressed: onBack,
                    icon: Icons.arrow_back,
                  ),
                ),
                Positioned(
                  top: top + 12,
                  right: 12,
                  child: _HeartButton(
                    favorite: episode.favorite,
                    onPressed: onFavorite,
                    size: 28,
                    circled: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CircleButton(
                  tooltip: 'Ajouter à la playlist',
                  onPressed: onPlaylist,
                  child: const PlaylistAddIcon(size: 22),
                ),
                const SizedBox(width: 12),
                _CircleButton(
                  tooltip: episode.played
                      ? 'Marquer comme non lu'
                      : 'Marquer comme lu',
                  onPressed: onPlayed,
                  child: Icon(
                    episode.played
                        ? Icons.mark_email_unread_outlined
                        : Icons.check_circle_outline,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                _PlayPill(
                  label: playLabel,
                  playing: playing,
                  onPressed: onPlay,
                ),
                const SizedBox(width: 12),
                _DownloadButton(
                  progress: progress,
                  downloaded: downloaded,
                  onPressed: onDownload,
                ),
                const SizedBox(width: 12),
                _CircleButton(
                  tooltip: 'Partager',
                  onPressed: onShare,
                  child: const ShareIcon(size: 22),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({
    required this.favorite,
    required this.onPressed,
    this.size = 24,
    this.circled = false,
  });

  final bool favorite;
  final VoidCallback onPressed;
  final double size;
  final bool circled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr(
        favorite ? 'Remove from favorites' : 'Add to favorites',
      ),
      onPressed: onPressed,
      style: circled
          ? IconButton.styleFrom(
              backgroundColor: coverControlColor,
              foregroundColor: Colors.white,
              fixedSize: const Size(48, 48),
              shape: const CircleBorder(),
            )
          : null,
      icon: Icon(
        favorite ? Icons.favorite : Icons.favorite_border,
        size: size,
        color: favorite ? favoriteHeartColor : Colors.white,
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white, size: 22),
            child: SizedBox(width: 48, height: 48, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

class _CoverIconButton extends StatelessWidget {
  const _CoverIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: coverControlColor,
        foregroundColor: Colors.white,
        fixedSize: const Size(48, 48),
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, color: Colors.white),
    );
  }
}

class _PlayPill extends StatelessWidget {
  const _PlayPill({
    required this.label,
    required this.playing,
    required this.onPressed,
  });

  final String label;
  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 110, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                    size: 22,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    required this.progress,
    required this.downloaded,
    required this.onPressed,
  });

  final double? progress;
  final bool downloaded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tooltip = progress != null
        ? progress == 0
              ? 'Téléchargement'
              : '${(progress! * 100).round()} %'
        : downloaded
        ? 'Supprimer'
        : 'Télécharger';
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: progress != null
                  ? DownloadProgressRing(
                      progress: progress!,
                      size: 22,
                      showClose: true,
                    )
                  : Icon(
                      downloaded
                          ? Icons.download_for_offline
                          : Icons.download_outlined,
                      size: 22,
                      color: downloaded ? downloadActiveColor : Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
