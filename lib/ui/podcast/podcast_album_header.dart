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
import 'cover_palette.dart';

/// Haut de page d’une émission. En portrait : jaquette SimpMusic / Apple Music.
class PodcastAlbumHeader extends ConsumerWidget {
  const PodcastAlbumHeader({
    super.key,
    required this.podcast,
    required this.background,
    required this.showPause,
    required this.onPlay,
    required this.onAbout,
  });

  final Podcast podcast;
  final Color background;
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
        final gutter = math.min(32.0, width * 0.06);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (portrait)
              _PortraitArtwork(
                podcast: podcast,
                headers: headers,
                background: background,
                width: width,
                height: height,
              )
            else
              _LandscapeArtwork(
                podcast: podcast,
                headers: headers,
                width: width,
                height: height,
              ),
            if (count != null)
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
                child: Text(
                  count == 1 ? '1 épisode' : '$count épisodes',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _PlayRow(
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
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Demi-écran, bord à bord, recadrage et fondu — comme SimpMusic.
class _PortraitArtwork extends StatelessWidget {
  const _PortraitArtwork({
    required this.podcast,
    required this.headers,
    required this.background,
    required this.width,
    required this.height,
  });

  final Podcast podcast;
  final Map<String, String>? headers;
  final Color background;
  final double width;
  final double height;

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
            httpHeaders: headers,
            radius: 0,
            expand: true,
            fit: BoxFit.cover,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: Container(
                height: height * 0.35,
                decoration: BoxDecoration(gradient: artworkScrim(background)),
              ),
            ),
          ),
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
  });

  final Podcast podcast;
  final Map<String, String>? headers;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final side = math
        .min(height * 0.72, width * 0.42)
        .clamp(140.0, math.min(width, height) * 0.9);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: PodcastCover(
          url: podcast.imageUrl,
          localPath: podcast.imagePath,
          httpHeaders: headers,
          size: side,
          radius: 12,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _PlayRow extends StatelessWidget {
  const _PlayRow({
    required this.showPause,
    required this.onPlay,
    required this.onAbout,
    required this.subscribed,
    required this.onSubscribe,
  });

  final bool showPause;
  final VoidCallback? onPlay;
  final VoidCallback onAbout;
  final bool subscribed;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final label = context.tr(showPause ? 'Pause' : 'Play');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPlay,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showPause ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                      size: 22,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'À propos',
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onAbout,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: const Center(
                  child: IconTheme(
                    data: IconThemeData(color: Colors.black, size: 22),
                    child: InfoIcon(size: 22),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!subscribed) ...[
          const SizedBox(width: 12),
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSubscribe,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 22),
                      const SizedBox(width: 4),
                      Text(
                        'S’abonner',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
