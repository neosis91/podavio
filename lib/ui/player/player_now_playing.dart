part of '../player_page.dart';

class _PlayerNowPlaying extends ConsumerWidget {
  const _PlayerNowPlaying({
    required this.episodeId,
    required this.onOpenNotes,
    this.carMode = false,
  });

  final int episodeId;
  final VoidCallback onOpenNotes;
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
    final chaptersUrl = ref
        .watch(episodeProvider(episodeId))
        .value
        ?.episode
        .chaptersUrl;
    final showChapters = !carMode &&
        (chapters.isNotEmpty ||
            (chaptersUrl != null && chaptersUrl.trim().isNotEmpty));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final playing = ref.watch(playerProvider.select((s) => s.playing));
    final activeChapter =
        carMode ? null : currentChapterFor(chapters, position);
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
                        fixedSize: Size(side, side),
                        iconSize: iconSize,
                      ),
                      onPressed: () =>
                          ref.read(playerProvider.notifier).toggle(),
                      icon: PlayPauseIcon(
                        playing: playing,
                        size: iconSize,
                      ),
                    ),
                  );
                }
                // Marges L/R hors image pour le double-tap saut.
                const sideGutter = 64.0;
                final maxByWidth = (constraints.maxWidth - 2 * sideGutter)
                    .clamp(48.0, 320.0)
                    .toDouble();
                final sideCap =
                    compact ? math.min(200.0, maxByWidth) : maxByWidth;
                final side = constraints.biggest.shortestSide
                    .clamp(0.0, sideCap)
                    .toDouble();
                if (side < 48) return const SizedBox.shrink();
                return SizedBox(
                  width: constraints.maxWidth,
                  height: side,
                  child: _CoverPlayGestures(
                    playing: playing,
                    child: PodcastCover(
                      url: imageUrl,
                      localPath: imagePath,
                      size: side,
                      radius: 24,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: compact ? 8 : 16),
          if (!carMode) ...[
            Text(
              podcastTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!carMode && releaseDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              releaseDate,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (!carMode &&
              activeChapter != null &&
              activeChapter.title.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              activeChapter.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (!carMode) ...[
            SizedBox(height: compact ? 4 : 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onOpenNotes,
                  icon: const InfoIcon(size: 20),
                  label: const Text('Notes'),
                ),
                if (showChapters)
                  TextButton.icon(
                    onPressed: () => showChaptersSheet(
                      context: context,
                      ref: ref,
                      episodeId: episodeId,
                    ),
                    icon: const Icon(Icons.list_alt, size: 20),
                    label: const Text('Chapitres'),
                  ),
              ],
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

/// Gestes autour de la couverture : tap sur l’image = lecture/pause ;
/// double-tap dans les marges L/R = saut ; swipe horizontal sur l’image = saut.
class _CoverPlayGestures extends ConsumerStatefulWidget {
  const _CoverPlayGestures({
    required this.playing,
    required this.child,
  });

  final bool playing;
  final Widget child;

  @override
  ConsumerState<_CoverPlayGestures> createState() => _CoverPlayGesturesState();
}

class _CoverPlayGesturesState extends ConsumerState<_CoverPlayGestures> {
  static const _swipeThresholdPx = 40.0;

  double _dragDx = 0;
  String? _feedbackLabel;
  /// `true` = marge droite (avance), `false` = marge gauche (recul).
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
    _flashFeedback(
      '$sign${seconds.abs()} s',
      onRight: seconds > 0,
    );
  }

  void _skipBack() {
    _skip(-ref.read(settingsProvider).skipBackSeconds);
  }

  void _skipForward() {
    _skip(ref.read(settingsProvider).skipForwardSeconds);
  }

  void _skipFromSwipe() {
    if (_dragDx.abs() < _swipeThresholdPx) return;
    if (_dragDx < 0) {
      _skipBack();
    } else {
      _skipForward();
    }
  }

  Widget _sideHitTarget({
    required bool onRight,
    required VoidCallback onDoubleTap,
  }) {
    final showFeedback =
        _feedbackLabel != null && _feedbackOnRight == onRight;
    final theme = Theme.of(context);
    return Expanded(
      child: Tooltip(
        message: onRight ? 'Double-tap : avancer' : 'Double-tap : reculer',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: onDoubleTap,
          child: Center(
            child: showFeedback
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        _feedbackLabel!,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sideHitTarget(onRight: false, onDoubleTap: _skipBack),
        Tooltip(
          message: widget.playing ? 'Pause' : 'Lecture',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            onHorizontalDragStart: (_) => _dragDx = 0,
            onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,
            onHorizontalDragEnd: (_) => _skipFromSwipe(),
            child: widget.child,
          ),
        ),
        _sideHitTarget(onRight: true, onDoubleTap: _skipForward),
      ],
    );
  }
}

