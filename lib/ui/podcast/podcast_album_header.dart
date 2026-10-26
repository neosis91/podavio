import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../data/feed_service.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../podcasts/podcast_feed_actions.dart';
import '../widgets/brand.dart';
import '../widgets/cover.dart';

/// Haut de page d’une émission. En portrait : jaquette SimpMusic / Apple Music.
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
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : media.size.width;
        final height = media.size.height;
        final portrait = width < height;
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

        if (portrait) {
          return _PortraitArtwork(
            podcast: podcast,
            headers: headers,
            width: width,
            height: height,
            chrome: chrome,
          );
        }
        return _LandscapeArtwork(
          podcast: podcast,
          headers: headers,
          width: width,
          height: height,
          chrome: chrome,
        );
      },
    );
  }
}

/// Demi-écran, bord à bord. Les actions reposent sur la pochette.
class _PortraitArtwork extends StatelessWidget {
  const _PortraitArtwork({
    required this.podcast,
    required this.headers,
    required this.width,
    required this.height,
    required this.chrome,
  });

  final Podcast podcast;
  final Map<String, String>? headers;
  final double width;
  final double height;
  final Widget chrome;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height / 2,
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

class _LandscapeArtwork extends StatelessWidget {
  const _LandscapeArtwork({
    required this.podcast,
    required this.headers,
    required this.width,
    required this.height,
    required this.chrome,
  });

  final Podcast podcast;
  final Map<String, String>? headers;
  final double width;
  final double height;
  final Widget chrome;

  @override
  Widget build(BuildContext context) {
    final side = math
        .min(height * 0.72, width * 0.42)
        .clamp(140.0, math.min(width, height) * 0.9);
    return SizedBox(
      height: side,
      child: Center(
        child: ClipRRect(
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
                const _ArtworkShade(),
                chrome,
              ],
            ),
          ),
        ),
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
