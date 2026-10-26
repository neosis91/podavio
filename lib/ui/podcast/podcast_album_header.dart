import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../data/feed_service.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../podcasts/podcast_feed_actions.dart';
import '../widgets/brand.dart';
import '../widgets/cover.dart';

/// Haut de page d’une émission. En portrait : jaquette pleine largeur.
class PodcastAlbumHeader extends ConsumerWidget {
  const PodcastAlbumHeader({
    super.key,
    required this.podcast,
    required this.showPause,
    required this.onPlay,
    required this.onAbout,
  });

  final Podcast podcast;
  final bool showPause;
  final VoidCallback? onPlay;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(podcastEpisodeCountProvider(podcast.id))
        .asData
        ?.value;
    final headers = podcastAuthHeaders(
      username: podcast.authUsername,
      password: podcast.authPassword,
    );
    final theme = Theme.of(context);
    final chrome = _CoverChrome(
      count: count,
      countStyle: theme.textTheme.bodyMedium,
      showPause: showPause,
      onPlay: onPlay,
      onAbout: onAbout,
      subscribed: podcast.subscribed,
      onSubscribe: () => subscribeToFeed(
        context,
        ref,
        podcast.feedUrl,
        openPodcast: false,
      ),
    );

    return _PortraitArtwork(
      podcast: podcast,
      headers: headers,
      chrome: chrome,
    );
  }
}

/// Paysage : pochette à gauche, liste à droite.
/// Sous la pochette : nombre d’épisodes, pastille lecture, puis info.
class PodcastLandscapeFrame extends ConsumerWidget {
  const PodcastLandscapeFrame({
    super.key,
    required this.podcast,
    required this.showPause,
    required this.onPlay,
    required this.onAbout,
    required this.listColor,
    required this.episodes,
  });

  final Podcast podcast;
  final bool showPause;
  final VoidCallback? onPlay;
  final VoidCallback onAbout;
  final Color listColor;
  final Widget episodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(podcastEpisodeCountProvider(podcast.id))
        .asData
        ?.value;
    final headers = podcastAuthHeaders(
      username: podcast.authUsername,
      password: podcast.authPassword,
    );
    final media = MediaQuery.of(context);
    final top = media.viewPadding.top + kToolbarHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : media.size.height;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : media.size.width;
        final available = (height - top).clamp(0.0, height);
        // 32 de marge, 12 sous la pochette, 40 pour la rangée d’actions.
        final side = (available - 84).clamp(0.0, width * 0.45);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: side + 24,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, top + 16, 8, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox.square(
                        dimension: side,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            PodcastCover(
                              url: podcast.imageUrl,
                              localPath: podcast.imagePath,
                              label: podcast.title,
                              httpHeaders: headers,
                              radius: 0,
                              expand: true,
                              fit: BoxFit.cover,
                            ),
                            if (!podcast.subscribed)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: _SubscribePill(
                                  onTap: () => subscribeToFeed(
                                    context,
                                    ref,
                                    podcast.feedUrl,
                                    openPodcast: false,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _UnderCoverBar(
                      count: count,
                      showPause: showPause,
                      onPlay: onPlay,
                      onAbout: onAbout,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child: ColoredBox(color: listColor, child: episodes),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Pleine largeur, hauteur égale à la largeur. Les actions reposent sur la pochette.
class _PortraitArtwork extends StatelessWidget {
  const _PortraitArtwork({
    required this.podcast,
    required this.headers,
    required this.chrome,
  });

  final Podcast podcast;
  final Map<String, String>? headers;
  final Widget chrome;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PodcastCover(
            url: podcast.imageUrl,
            localPath: podcast.imagePath,
            label: podcast.title,
            httpHeaders: headers,
            radius: 0,
            expand: true,
            fit: BoxFit.cover,
          ),
          const _ArtworkShade(),
          chrome,
        ],
      ),
    );
  }
}

/// Ombre légère en bas de la pochette, pour détacher boutons et texte.
class _ArtworkShade extends StatelessWidget {
  const _ArtworkShade();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0x99000000)],
            stops: [0.62, 1],
          ),
        ),
      ),
    );
  }
}

class _CoverChrome extends StatelessWidget {
  const _CoverChrome({
    required this.count,
    required this.countStyle,
    required this.showPause,
    required this.onPlay,
    required this.onAbout,
    required this.subscribed,
    required this.onSubscribe,
  });

  final int? count;
  final TextStyle? countStyle;
  final bool showPause;
  final VoidCallback? onPlay;
  final VoidCallback onAbout;
  final bool subscribed;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium;
    return Stack(
      children: [
        Positioned(
          top: 12,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!subscribed) ...[
                _Pill(
                  onTap: onSubscribe,
                  color: Colors.white.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'S’abonner',
                          style: labelStyle?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Tooltip(
                message: 'À propos',
                child: _Pill(
                  onTap: onAbout,
                  color: Colors.white,
                  child: const SizedBox.square(
                    dimension: 36,
                    child: Center(
                      child: IconTheme(
                        data: IconThemeData(color: Colors.black, size: 18),
                        child: InfoIcon(size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    count == 1 ? '1 épisode' : '$count épisodes',
                    textAlign: TextAlign.center,
                    style: countStyle?.copyWith(color: Colors.white),
                  ),
                ),
              _Pill(
                onTap: onPlay,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showPause ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.tr(showPause ? 'Pause' : 'Play'),
                        style: labelStyle?.copyWith(color: Colors.black),
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

/// Sous la pochette : nombre d’épisodes, puis pastille lecture et info.
class _UnderCoverBar extends StatelessWidget {
  const _UnderCoverBar({
    required this.count,
    required this.showPause,
    required this.onPlay,
    required this.onAbout,
  });

  final int? count;
  final bool showPause;
  final VoidCallback? onPlay;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final countColor = surface.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    final countStyle = Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(
          child: Text(
            count == null
                ? ''
                : count == 1
                ? '1 épisode'
                : '$count épisodes',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: countStyle?.copyWith(color: countColor),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: showPause ? 'Pause' : 'Lire',
          child: Material(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black54,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPlay,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  showPause ? Icons.pause : Icons.play_arrow,
                  size: 28,
                  color: onPlay == null ? Colors.black38 : Colors.black,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'À propos',
          child: _Pill(
            onTap: onAbout,
            color: Colors.white,
            child: const SizedBox.square(
              dimension: 36,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(color: Colors.black, size: 18),
                  child: InfoIcon(size: 18),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubscribePill extends StatelessWidget {
  const _SubscribePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium;
    return _Pill(
      onTap: onTap,
      color: Colors.white.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(
              'S’abonner',
              style: labelStyle?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.onTap, required this.color, required this.child});

  final VoidCallback? onTap;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 2,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: child,
        ),
      ),
    );
  }
}
