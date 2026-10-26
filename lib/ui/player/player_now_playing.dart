import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/feed_service.dart';
import '../../data/providers.dart';
import '../../player/player_controller.dart';
import '../../settings/settings_controller.dart';
import '../widgets/brand.dart';
import '../widgets/cover.dart';
import 'player_chapter.dart';
import 'player_controls.dart';

class PlayerNowPlaying extends ConsumerWidget {
  const PlayerNowPlaying({
    super.key,
    required this.episodeId,
    this.carMode = false,
  });

  final int episodeId;
  final bool carMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(playerProvider.select((state) => state.title));
    final podcastTitle = ref.watch(
      playerProvider.select((state) => state.podcastTitle),
    );
    final imageUrl = ref.watch(
      playerProvider.select((state) => state.imageUrl),
    );
    final imagePath = ref.watch(
      playerProvider.select((state) => state.imagePath),
    );
    final error = ref.watch(playerProvider.select((state) => state.error));
    final publishedAt = ref
        .watch(episodeProvider(episodeId))
        .value
        ?.episode
        .publishedAt;
    final releaseDate = formatReleaseDate(publishedAt);
    final chaptersAsync = ref.watch(chaptersProvider(episodeId));
    final chapters = chaptersAsync.value ?? const <EpisodeChapter>[];
    final podcast = ref.watch(episodeProvider(episodeId)).value?.podcast;
    final position = ref.watch(playerProvider.select((s) => s.position));
    final playing = ref.watch(playerProvider.select((s) => s.playing));
    final activeChapter = carMode
        ? null
        : currentChapterFor(chapters, position);
    final theme = Theme.of(context);

    Widget content({required bool compact}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (carMode) {
                  final side = constraints.biggest.shortestSide
                      .clamp(96.0, 280.0)
                      .toDouble();
                  if (side < 96) return const SizedBox.shrink();
                  final iconSize = side * 0.45;
                  return Center(
                    child: IconButton.filled(
                      tooltip: playing ? 'Pause' : 'Lecture',
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.onSurface,
                        foregroundColor: theme.colorScheme.surface,
                        fixedSize: Size(side, side),
                        iconSize: iconSize,
                      ),
                      onPressed: () =>
                          ref.read(playerProvider.notifier).toggle(),
                      icon: PlayPauseIcon(
                        playing: playing,
                        size: iconSize,
                        color: theme.colorScheme.surface,
                      ),
                    ),
                  );
                }
                final maxByWidth = constraints.maxWidth
                    .clamp(48.0, 480.0)
                    .toDouble();
                final sideCap = compact
                    ? math.min(240.0, maxByWidth)
                    : maxByWidth;
                // Ne pas utiliser shortestSide seul : dans un Expanded haut,
                // un SizedBox(height: side) est forcé à minHeight = maxHeight
                // et la cover s’étire en rectangle.
                final side = math
                    .min(constraints.maxHeight, sideCap)
                    .clamp(0.0, sideCap)
                    .toDouble();
                if (side < 48) return const SizedBox.shrink();
                // Center assouplit les contraintes du Expanded (sinon la
                // hauteur min = zone entière et casse le carré).
                return Center(
                  child: _CoverPlayGestures(
                    playing: playing,
                    child: PodcastCover(
                      url: imageUrl,
                      localPath: imagePath,
                      label: title,
                      colorKey: podcastTitle,
                      httpHeaders: podcastAuthHeaders(
                        username: podcast?.authUsername,
                        password: podcast?.authPassword,
                      ),
                      size: side,
                      radius: 16,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: compact ? 8 : 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: carMode
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    if (!carMode)
                      Text(
                        podcastTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      title,
                      textAlign: carMode ? TextAlign.center : TextAlign.start,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!carMode && releaseDate.isNotEmpty)
                      Text(
                        releaseDate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (!carMode &&
                        activeChapter != null &&
                        activeChapter.title.isNotEmpty)
                      Text(
                        activeChapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (!carMode) PlayerFavoriteAction(episodeId: episodeId),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: carMode ? TextAlign.center : TextAlign.start,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        // Pendant l’animation d’ouverture, la hauteur peut être très faible.
        if (height < 240) {
          return ClipRect(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth,
                height: 280,
                child: content(compact: true),
              ),
            ),
          );
        }
        return content(compact: false);
      },
    );
  }
}

/// Tap = lecture/pause. Double-tap à gauche ou à droite = saut temporel.
/// Glisser horizontalement = épisode précédent ou suivant.
class _CoverPlayGestures extends ConsumerStatefulWidget {
  const _CoverPlayGestures({required this.playing, required this.child});

  final bool playing;
  final Widget child;

  @override
  ConsumerState<_CoverPlayGestures> createState() => _CoverPlayGesturesState();
}

class _CoverPlayGesturesState extends ConsumerState<_CoverPlayGestures> {
  static const _swipeThresholdPx = 48.0;

  double _dragDx = 0;
  Offset? _doubleTapPosition;
  String? _feedbackLabel;

  /// `true` = moitié droite, `false` = moitié gauche.
  bool _feedbackOnRight = true;
  Timer? _feedbackTimer;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _flashFeedback(String label, {required bool onRight}) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackLabel = label;
      _feedbackOnRight = onRight;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _feedbackLabel = null);
    });
  }

  void _toggle() => ref.read(playerProvider.notifier).toggle();

  void _skip(int seconds) {
    ref.read(playerProvider.notifier).skipBy(seconds);
    final sign = seconds < 0 ? '−' : '+';
    _flashFeedback('$sign${seconds.abs()} s', onRight: seconds > 0);
  }

  void _skipBack() {
    _skip(-ref.read(settingsProvider).skipBackSeconds);
  }

  void _skipForward() {
    _skip(ref.read(settingsProvider).skipForwardSeconds);
  }

  void _previousEpisode() {
    final position = ref.read(playerProvider).position;
    final restart = position.inMilliseconds > 3000;
    ref.read(playerProvider.notifier).playPreviousInQueue();
    _flashFeedback(restart ? 'Début' : 'Précédent', onRight: false);
  }

  void _nextEpisode() {
    final hasNext = ref.read(hasNextInQueueProvider).value ?? false;
    if (!hasNext) return;
    ref.read(playerProvider.notifier).playNextInQueue();
    _flashFeedback('Suivant', onRight: true);
  }

  void _skipFromSwipe() {
    final dx = _dragDx;
    setState(() => _dragDx = 0);
    if (dx.abs() < _swipeThresholdPx) return;
    if (dx < 0) {
      _nextEpisode();
    } else {
      _previousEpisode();
    }
  }

  void _onDoubleTap() {
    final box = context.findRenderObject();
    final width = box is RenderBox ? box.size.width : 0.0;
    final x = _doubleTapPosition?.dx ?? width / 2;
    if (x < width / 2) {
      _skipBack();
    } else {
      _skipForward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = _dragDx.clamp(-56.0, 56.0);
    return Tooltip(
      message: widget.playing ? 'Pause' : 'Lecture',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onDoubleTapDown: (details) =>
            _doubleTapPosition = details.localPosition,
        onDoubleTap: _onDoubleTap,
        onHorizontalDragStart: (_) => _dragDx = 0,
        onHorizontalDragUpdate: (details) {
          setState(() => _dragDx += details.delta.dx);
        },
        onHorizontalDragEnd: (_) => _skipFromSwipe(),
        onHorizontalDragCancel: () => setState(() => _dragDx = 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(offset: Offset(shift, 0), child: widget.child),
            if (_feedbackLabel != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: _feedbackOnRight
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            _feedbackLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
