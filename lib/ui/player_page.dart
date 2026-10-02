import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../data/app_database.dart';
import '../data/providers.dart';
import '../player/player_controller.dart';
import '../player/player_sheet_controller.dart';
import '../settings/settings_controller.dart';
import 'router.dart';
import 'widgets/brand.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_tile.dart';
import 'widgets/messages.dart';

EpisodeChapter? currentChapterFor(
  List<EpisodeChapter> chapters,
  Duration position,
) {
  if (chapters.isEmpty) return null;
  final ms = position.inMilliseconds;
  EpisodeChapter? current;
  for (final chapter in chapters) {
    if (chapter.startMs <= ms) {
      current = chapter;
    } else {
      break;
    }
  }
  return current;
}

Future<void> showChaptersSheet({
  required BuildContext context,
  required WidgetRef ref,
  required int episodeId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ChaptersSheet(episodeId: episodeId),
  );
}

class PlayerPage extends ConsumerWidget {
  const PlayerPage({
    super.key,
    this.onCollapse,
    this.embedded = false,
    this.onHeaderDragUpdate,
    this.onHeaderDragEnd,
  });

  /// Si fourni, remplace le pop navigateur (lecteur expansible).
  final VoidCallback? onCollapse;

  /// Affiché dans le sheet : fond transparent géré par le parent.
  final bool embedded;

  final GestureDragUpdateCallback? onHeaderDragUpdate;
  final GestureDragEndCallback? onHeaderDragEnd;

  void _collapse(BuildContext context) {
    if (onCollapse != null) {
      onCollapse!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodeId = ref.watch(
      playerProvider.select((state) => state.episodeId),
    );
    if (episodeId == null) {
      return Scaffold(
        backgroundColor: embedded ? Colors.transparent : null,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Réduire',
            onPressed: () => _collapse(context),
            icon: const SkipIcon.collapse(),
          ),
        ),
        body: const EmptyState(
          title: 'Aucune lecture',
          message: 'Lancez un épisode pour ouvrir le lecteur.',
        ),
      );
    }

    final carMode = ref.watch(playerProvider.select((state) => state.carMode));
    final appBar = AppBar(
      leading: IconButton(
        tooltip: 'Réduire',
        onPressed: () => _collapse(context),
        icon: const SkipIcon.collapse(),
      ),
      title: carMode ? null : const Text('Lecture'),
      actions: [
        if (!carMode) ...[
          _FavoriteAction(episodeId: episodeId),
          const _SleepAction(),
          _ShareAction(episodeId: episodeId),
        ],
        _PlayerActions(episodeId: episodeId),
      ],
    );

    return Scaffold(
      backgroundColor: embedded ? Colors.transparent : null,
      appBar: PreferredSize(
        preferredSize: appBar.preferredSize,
        child: PlayerCollapseHeader(
          onVerticalDragUpdate: onHeaderDragUpdate,
          onVerticalDragEnd: onHeaderDragEnd,
          child: appBar,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Pendant l’expansion, la hauteur est trop faible pour la barre transport.
          final showTransport = constraints.maxHeight >= 200;
          return Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _PlayerStage(episodeId: episodeId),
                  ),
                ),
              ),
              if (showTransport)
                Material(
                  elevation: 3,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: const _PlayerTransport(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Zone de drag pour réduire le lecteur (swipe bas depuis le header).
class PlayerCollapseHeader extends StatelessWidget {
  const PlayerCollapseHeader({
    super.key,
    required this.child,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
  });

  final Widget child;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragEndCallback? onVerticalDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      child: child,
    );
  }
}

class _PlayerStage extends ConsumerStatefulWidget {
  const _PlayerStage({required this.episodeId});

  final int episodeId;

  @override
  ConsumerState<_PlayerStage> createState() => _PlayerStageState();
}

/// Pager vertical couverture ↔ notes (comme ViewPager2 d’AntennaPod).
class _PlayerStageState extends ConsumerState<_PlayerStage> {
  late final PageController _pageController;
  final _notesScroll = ScrollController();
  var _page = 0;
  var _pullingToCover = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _PlayerStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeId != widget.episodeId) {
      _page = 0;
      _pullingToCover = false;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      if (_notesScroll.hasClients) {
        _notesScroll.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _notesScroll.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToNotes() {
    return _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _snapNotesPager() async {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? 1;
    if (page <= 0.7) {
      await _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else if (page < 0.999) {
      await _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// En haut des notes, un tirage vers le bas pilote le PageView (retour couverture).
  bool _onNotesScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (!_pageController.hasClients) return false;

    final pagePosition = _pageController.position;
    final extent = pagePosition.viewportDimension;
    if (extent <= 0) return false;

    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.dragDetails != null) {
      _pullingToCover = true;
      final next = (pagePosition.pixels + notification.overscroll).clamp(
        0.0,
        extent,
      );
      if (next != pagePosition.pixels) {
        pagePosition.jumpTo(next);
      }
      return false;
    }

    if (_pullingToCover &&
        (notification is ScrollEndNotification ||
            (notification is UserScrollNotification &&
                notification.direction == ScrollDirection.idle))) {
      _pullingToCover = false;
      unawaited(_snapNotesPager());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final carMode = ref.watch(playerProvider.select((state) => state.carMode));
    ref.listen(playerProvider.select((state) => state.carMode), (prev, next) {
      if (next != true) return;
      _page = 0;
      _pullingToCover = false;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      if (_notesScroll.hasClients) {
        _notesScroll.jumpTo(0);
      }
    });
    if (carMode) {
      // Mode voiture : couverture seule, sans pager notes.
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: _PlayerNowPlaying(
          episodeId: widget.episodeId,
          onOpenNotes: () {},
          carMode: true,
        ),
      );
    }

    // Sur la couverture : swipe vertical pour ouvrir les notes.
    // Sur les notes : le ListView gère le scroll ; le tirage en haut
    // pilote le pager via [_onNotesScrollNotification].
    return PageView(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: _page == 0
          ? const PageScrollPhysics(parent: ClampingScrollPhysics())
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (page) {
        setState(() => _page = page);
        if (page == 0 && _notesScroll.hasClients) {
          _notesScroll.jumpTo(0);
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: _PlayerNowPlaying(
            episodeId: widget.episodeId,
            onOpenNotes: () {
              _goToNotes();
            },
          ),
        ),
        _PlayerNotesPage(
          episodeId: widget.episodeId,
          scrollController: _notesScroll,
          onScrollNotification: _onNotesScrollNotification,
        ),
      ],
    );
  }
}

class _PlayerNotesPage extends ConsumerWidget {
  const _PlayerNotesPage({
    required this.episodeId,
    required this.scrollController,
    required this.onScrollNotification,
  });

  final int episodeId;
  final ScrollController scrollController;
  final NotificationListenerCallback<ScrollNotification> onScrollNotification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notes =
        ref.watch(episodeProvider(episodeId)).value?.episode.description ?? '';
    final notesText = plainText(notes);

    return Material(
      color: scheme.surface,
      child: NotificationListener<ScrollNotification>(
        onNotification: onScrollNotification,
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            if (notesText.isEmpty)
              Text(
                'Aucune note pour cet épisode.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Text(notesText, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

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

class _PlayerTransport extends ConsumerWidget {
  const _PlayerTransport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final settings = ref.watch(settingsProvider);
    final carMode = player.carMode;
    final totalMs = player.duration.inMilliseconds;
    final positionMs = player.position.inMilliseconds.clamp(
      0,
      totalMs == 0 ? 0 : totalMs,
    );
    final hasNext = ref.watch(hasNextInQueueProvider).value ?? false;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final sideIconSize = carMode ? 48.0 : 36.0;
    final skipIconSize = carMode ? 56.0 : 36.0;
    const playIconSize = 36.0;
    const playButtonSize = 56.0;
    final gap = carMode ? 12.0 : 4.0;
    final skipGap = carMode ? 12.0 : 8.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          value: totalMs == 0 ? 0 : positionMs.toDouble(),
          max: totalMs == 0 ? 1 : totalMs.toDouble(),
          onChanged: totalMs == 0
              ? null
              : (value) => ref
                    .read(playerProvider.notifier)
                    .seek(Duration(milliseconds: value.round())),
        ),
        Row(
          children: [
            Text(formatClock(player.position)),
            const Spacer(),
            Text(
              settings.showRemainingTime
                  ? '−${formatClock(player.duration - player.position)}'
                  : formatClock(player.duration),
            ),
            IconButton(
              tooltip: 'Volume (− / =)',
              visualDensity: VisualDensity.compact,
              onPressed: () => _chooseVolume(context, ref),
              icon: Icon(_volumeIcon(player.volume)),
            ),
          ],
        ),
        SizedBox(height: carMode ? 12 : 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TransportControl(
                tooltip: 'Vitesse de lecture',
                label: _formatSpeed(player.speed),
                labelStyle: labelStyle,
                onPressed: () => _chooseSpeed(context, ref, player.speed),
                icon: Icon(Icons.speed, size: sideIconSize),
                iconSize: sideIconSize,
              ),
              SizedBox(width: gap),
              _TransportControl(
                tooltip:
                    'Reculer de ${settings.skipBackSeconds} s (J)',
                label: '−${settings.skipBackSeconds} s',
                labelStyle: labelStyle,
                onPressed: () => ref
                    .read(playerProvider.notifier)
                    .skipBy(-settings.skipBackSeconds),
                icon: SkipIcon.back(size: skipIconSize),
                iconSize: skipIconSize,
              ),
              if (!carMode) ...[
                SizedBox(width: skipGap),
                _TransportControl(
                  tooltip:
                      player.playing ? 'Pause (Espace)' : 'Lecture (Espace)',
                  label: '',
                  labelStyle: labelStyle,
                  filled: true,
                  iconSize: playButtonSize,
                  onPressed: () => ref.read(playerProvider.notifier).toggle(),
                  icon: PlayPauseIcon(
                    playing: player.playing,
                    size: playIconSize,
                  ),
                ),
              ],
              SizedBox(width: skipGap),
              _TransportControl(
                tooltip: 'Avancer de ${settings.skipForwardSeconds} s (L)',
                label: '+${settings.skipForwardSeconds} s',
                labelStyle: labelStyle,
                onPressed: () => ref
                    .read(playerProvider.notifier)
                    .skipBy(settings.skipForwardSeconds),
                icon: SkipIcon.forward(size: skipIconSize),
                iconSize: skipIconSize,
              ),
              SizedBox(width: gap),
              _TransportControl(
                tooltip: hasNext
                    ? 'Épisode suivant'
                    : 'Pas d’épisode suivant dans la playlist',
                label: '',
                labelStyle: labelStyle,
                onPressed: hasNext
                    ? () => ref.read(playerProvider.notifier).playNextInQueue()
                    : null,
                icon: SkipIcon.next(size: sideIconSize),
                iconSize: sideIconSize,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatSpeed(double speed) {
  final text = speed == speed.roundToDouble()
      ? speed.toInt().toString()
      : speed.toString();
  return '$text×';
}

String _formatVolume(double volume) {
  return '${(volume * 100).round()} %';
}

IconData _volumeIcon(double volume) {
  if (volume <= 0) return Icons.volume_off;
  if (volume < 0.34) return Icons.volume_mute;
  if (volume < 0.67) return Icons.volume_down;
  return Icons.volume_up;
}

class _TransportControl extends StatelessWidget {
  const _TransportControl({
    required this.icon,
    required this.label,
    required this.labelStyle,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.iconSize = 36,
  });

  final Widget icon;
  final String label;
  final TextStyle? labelStyle;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final button = filled
        ? IconButton.filled(
            tooltip: tooltip,
            iconSize: iconSize,
            onPressed: onPressed,
            icon: icon,
          )
        : IconButton(
            tooltip: tooltip,
            iconSize: iconSize,
            onPressed: onPressed,
            icon: icon,
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        SizedBox(
          height: 16,
          child: label.isEmpty
              ? null
              : Text(label, style: labelStyle, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class _SleepAction extends ConsumerWidget {
  const _SleepAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    return IconButton(
      tooltip: _sleepLabel(player),
      onPressed: () => _chooseSleep(context, ref),
      icon: const TimerIcon(size: 24),
    );
  }
}

class _FavoriteAction extends ConsumerWidget {
  const _FavoriteAction({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(episodeProvider(episodeId)).value;
    if (entry == null) return const SizedBox.shrink();
    final favorite = entry.episode.favorite;
    return IconButton(
      tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      onPressed: () => runEpisodeAction(
        context,
        ref,
        entry,
        EpisodeMenuAction.favorite,
      ),
      icon: Icon(favorite ? Icons.favorite : Icons.favorite_outline),
    );
  }
}

class _ShareAction extends ConsumerWidget {
  const _ShareAction({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(episodeProvider(episodeId)).value;
    if (entry == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Partager',
      onPressed: () => runEpisodeAction(
        context,
        ref,
        entry,
        EpisodeMenuAction.share,
      ),
      icon: const ShareIcon(size: 24),
    );
  }
}

class _PlayerActions extends ConsumerWidget {
  const _PlayerActions({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(episodeProvider(episodeId)).value;
    if (entry == null) return const SizedBox.shrink();
    final website = _podcastWebsite(entry.podcast.link);
    final carMode = ref.watch(playerProvider.select((state) => state.carMode));
    // Mode voiture : téléphone uniquement (même seuil que la grille podcasts).
    final showCarMode = MediaQuery.sizeOf(context).shortestSide < 600;
    return PopupMenuButton<_PlayerMenuAction>(
      onSelected: (action) => _onSelected(context, ref, entry, action),
      itemBuilder: (context) => [
        if (showCarMode)
          PopupMenuItem(
            value: _PlayerMenuAction.toggleCarMode,
            child: Row(
              children: [
                Icon(
                  carMode
                      ? Icons.directions_car
                      : Icons.directions_car_outlined,
                ),
                const SizedBox(width: 12),
                Text(carMode ? 'Quitter le mode voiture' : 'Mode voiture'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: _PlayerMenuAction.openPodcast,
          child: Row(
            children: [
              PodcastsIcon(),
              SizedBox(width: 12),
              Text('Ouvrir le podcast'),
            ],
          ),
        ),
        if (website != null)
          const PopupMenuItem(
            value: _PlayerMenuAction.openWebsite,
            child: Row(
              children: [
                LinkIcon(),
                SizedBox(width: 12),
                Text('Ouvrir le site web'),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    EpisodeEntry entry,
    _PlayerMenuAction action,
  ) async {
    switch (action) {
      case _PlayerMenuAction.toggleCarMode:
        final enabled = !ref.read(playerProvider).carMode;
        ref.read(playerProvider.notifier).setCarMode(enabled);
      case _PlayerMenuAction.openPodcast:
        ref.read(playerSheetProvider.notifier).collapse();
        if (context.mounted) {
          context.push(AppRoutes.podcast(entry.podcast.id));
        }
      case _PlayerMenuAction.openWebsite:
        final website = _podcastWebsite(entry.podcast.link);
        if (website == null) return;
        final opened = await launchUrl(
          website,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && context.mounted) {
          showMessage(context, 'Impossible d’ouvrir le site web');
        }
    }
  }
}

enum _PlayerMenuAction { toggleCarMode, openPodcast, openWebsite }

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

String _sleepLabel(PlayerUiState player) {
  if (player.sleepAtEnd) return 'Fin de l’épisode';
  final remaining = player.sleepRemaining;
  if (remaining == null) return 'Minuteur';
  return formatClock(remaining);
}

Future<void> _chooseSpeed(
  BuildContext context,
  WidgetRef ref,
  double current,
) async {
  const speeds = [0.8, 1.0, 1.2, 1.5, 1.8, 2.0, 2.5, 3.0];
  final selected = await showModalBottomSheet<double>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final speed in speeds)
            ListTile(
              title: Text('$speed×'),
              trailing: speed == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, speed),
            ),
        ],
      ),
    ),
  );
  if (selected != null) {
    await ref.read(playerProvider.notifier).setSpeed(selected);
  }
}

Future<void> _chooseVolume(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _VolumeSheet(),
  );
}

class _VolumeSheet extends ConsumerWidget {
  const _VolumeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerProvider.select((state) => state.volume));
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Volume', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_volumeIcon(volume)),
                Expanded(
                  child: Slider(
                    value: volume,
                    onChanged: (value) {
                      unawaited(
                        ref.read(playerProvider.notifier).setVolume(value),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _formatVolume(volume),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _chooseSleep(BuildContext context, WidgetRef ref) async {
  final choice = await showModalBottomSheet<_SleepChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Désactivé'),
            onTap: () => Navigator.pop(context, const _SleepChoice.off()),
          ),
          for (final minutes in [5, 15, 30, 45, 60])
            ListTile(
              title: Text('$minutes minutes'),
              onTap: () => Navigator.pop(
                context,
                _SleepChoice.duration(Duration(minutes: minutes)),
              ),
            ),
          ListTile(
            title: const Text('Fin de l’épisode'),
            onTap: () => Navigator.pop(context, const _SleepChoice.end()),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  ref
      .read(playerProvider.notifier)
      .setSleep(choice.duration, atEnd: choice.atEnd);
}

class _SleepChoice {
  const _SleepChoice.off() : duration = null, atEnd = false;
  const _SleepChoice.end() : duration = null, atEnd = true;
  const _SleepChoice.duration(this.duration) : atEnd = false;

  final Duration? duration;
  final bool atEnd;
}

class _ChaptersSheet extends ConsumerWidget {
  const _ChaptersSheet({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chaptersAsync = ref.watch(chaptersProvider(episodeId));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final chapters = chaptersAsync.value ?? const <EpisodeChapter>[];
    final active = currentChapterFor(chapters, position);
    final height = MediaQuery.sizeOf(context).height * 0.55;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Chapitres', style: theme.textTheme.titleMedium),
            ),
            Expanded(
              child: chaptersAsync.isLoading && chapters.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : chapters.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun chapitre pour cet épisode.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        final selected = identical(chapter, active) ||
                            chapter.id == active?.id;
                        final start = Duration(milliseconds: chapter.startMs);
                        return ListTile(
                          selected: selected,
                          leading: Text(
                            formatClock(start),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          title: Text(
                            chapter.title.isEmpty
                                ? 'Chapitre ${index + 1}'
                                : chapter.title,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            ref
                                .read(playerProvider.notifier)
                                .seek(start);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
