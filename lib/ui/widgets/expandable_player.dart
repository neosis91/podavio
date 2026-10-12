import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cover_tone.dart';
import '../../core/format.dart';
import '../../player/player_controller.dart';
import '../../player/player_sheet_controller.dart';
import '../../settings/settings_controller.dart';
import '../player_page.dart';
import 'brand.dart';
import 'cover.dart';

/// Hauteur de la barre mini (hors inset bas géré par le positionnement).
const miniPlayerHeight = 64.0;

/// Lecteur type « expandable mini player » : mini ↔ plein écran avec drag.
class ExpandablePlayer extends ConsumerStatefulWidget {
  const ExpandablePlayer({
    super.key,
    required this.bottomInset,
    this.leftInset = 0,
    this.topInset = 0,
  });

  /// Espace sous le lecteur (barre de nav + safe area).
  final double bottomInset;

  /// Espace à gauche (rail de navigation sur grand écran).
  final double leftInset;

  /// Espace en haut (safe area quand le rail est affiché).
  final double topInset;

  @override
  ConsumerState<ExpandablePlayer> createState() => _ExpandablePlayerState();
}

class _ExpandablePlayerState extends ConsumerState<ExpandablePlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _dragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 360),
      curve: target > _controller.value
          ? Curves.easeOutCubic
          : Curves.easeInCubic,
    );
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details, double extent) {
    if (extent <= 0) return;
    if (!_dragging) setState(() => _dragging = true);
    final delta = -details.primaryDelta! / extent;
    _controller.value = (_controller.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final vx = details.primaryVelocity ?? 0;
    final target = vx < -600
        ? 1.0
        : vx > 600
        ? 0.0
        : (_controller.value >= 0.3 ? 1.0 : 0.0);
    _finishDrag(target);
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _finishDrag(_controller.value >= 0.3 ? 1.0 : 0.0);
  }

  void _finishDrag(double target) {
    setState(() => _dragging = false);
    _animateTo(target);
    if (target >= 1) {
      ref.read(playerSheetProvider.notifier).expand();
    } else {
      ref.read(playerSheetProvider.notifier).collapse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasEpisode = ref.watch(
      playerProvider.select((state) => state.hasEpisode),
    );
    ref.listen(playerSheetProvider, (prev, next) {
      if (prev?.id == next.id) return;
      if (!_dragging) _animateTo(next.expand ? 1 : 0);
    });
    ref.listen(playerProvider.select((s) => s.hasEpisode), (prev, next) {
      if (next != true) {
        _dragging = false;
        _animateTo(0);
      }
    });

    if (!hasEpisode) return const SizedBox.shrink();

    final size = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final tone = watchPlayerCoverTone(ref);
    // Course du haut de la carte, du mini-lecteur jusqu’au haut de l’écran.
    final extent = (size.height - widget.bottomInset - miniPlayerHeight).clamp(
      1.0,
      size.height,
    );

    return Positioned(
      left: widget.leftInset,
      right: 0,
      top: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final bottom = widget.bottomInset * (1 - t);
          final span = size.height - bottom;
          final height = (miniPlayerHeight + (span - miniPlayerHeight) * t)
              .clamp(miniPlayerHeight, span);
          final margin = 12 * (1 - t);

          return Padding(
            padding: EdgeInsets.only(
              left: margin,
              right: margin,
              bottom: bottom,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: height,
                child: BackButtonListener(
                  onBackButtonPressed: () async {
                    if (_controller.value <= 0.05) return false;
                    if (closePlayerPlaylistIfOpen(ref)) return true;
                    ref.read(playerSheetProvider.notifier).collapse();
                    return true;
                  },
                  child: MediaQuery.removePadding(
                    context: context,
                    removeBottom: bottom > 0,
                    removeLeft: widget.leftInset > 0,
                    removeTop: widget.topInset > 0 && t < 1,
                    // Drag sur la mini-barre (expand) et le header (collapse) :
                    // pas de GestureDetector parent (conflit avec le PageView vertical).
                    // `_dragging` empêche IgnorePointer de couper le geste à mi-course.
                    child: Material(
                      elevation: 0,
                      color:
                          tone?.background ??
                          Color.lerp(
                            scheme.surfaceContainerHigh,
                            scheme.surface,
                            t,
                          ),
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18 * (1 - t)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: t < 0.5 && !_dragging,
                              child: Opacity(
                                opacity: Curves.easeOut.transform(
                                  ((t - 0.08) / 0.92).clamp(0.0, 1.0),
                                ),
                                child: PlayerPage(
                                  embedded: true,
                                  onCollapse: () => ref
                                      .read(playerSheetProvider.notifier)
                                      .collapse(),
                                  onHeaderDragStart: _onDragStart,
                                  onHeaderDragUpdate: (details) =>
                                      _onDragUpdate(details, extent),
                                  onHeaderDragEnd: _onDragEnd,
                                  onHeaderDragCancel: _onDragCancel,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: miniPlayerHeight,
                            child: IgnorePointer(
                              ignoring: t > 0.5 && !_dragging,
                              child: Opacity(
                                opacity: (1 - t / 0.4).clamp(0.0, 1.0),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onVerticalDragStart: _onDragStart,
                                  onVerticalDragUpdate: (details) =>
                                      _onDragUpdate(details, extent),
                                  onVerticalDragEnd: _onDragEnd,
                                  onVerticalDragCancel: _onDragCancel,
                                  child: Theme(
                                    data: tone == null
                                        ? Theme.of(context)
                                        : miniPlayerTheme(tone.background),
                                    child: _MiniPlayerBar(
                                      onOpen: () => ref
                                          .read(playerSheetProvider.notifier)
                                          .expand(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniPlayerBar extends ConsumerWidget {
  const _MiniPlayerBar({required this.onOpen});

  final VoidCallback onOpen;

  static const _btnConstraints = BoxConstraints(minWidth: 36, minHeight: 48);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(playerProvider.select((s) => s.title));
    final podcastTitle = ref.watch(
      playerProvider.select((s) => s.podcastTitle),
    );
    final imageUrl = ref.watch(playerProvider.select((s) => s.imageUrl));
    final imagePath = ref.watch(playerProvider.select((s) => s.imagePath));
    final playing = ref.watch(playerProvider.select((s) => s.playing));
    final position = ref.watch(playerProvider.select((s) => s.position));
    final duration = ref.watch(playerProvider.select((s) => s.duration));
    final speed = ref.watch(playerProvider.select((s) => s.speed));
    final error = ref.watch(playerProvider.select((s) => s.error));
    final skipBack = ref.watch(
      settingsProvider.select((s) => s.skipBackSeconds),
    );
    final skipForward = ref.watch(
      settingsProvider.select((s) => s.skipForwardSeconds),
    );
    final miniButtons = ref.watch(
      settingsProvider.select((s) => s.miniPlayerButtons),
    );
    final hasNext = miniButtons.nextEpisode
        ? (ref.watch(hasNextInQueueProvider).value ?? false)
        : false;
    final timeRespectsSpeed = ref.watch(
      settingsProvider.select((s) => s.timeRespectsSpeed),
    );
    final scheme = Theme.of(context).colorScheme;
    final onCard = scheme.onSurface;
    final onCardMuted = scheme.onSurfaceVariant;
    final player = ref.read(playerProvider.notifier);
    final total = duration.inMilliseconds;
    final progress = total == 0
        ? 0.0
        : (position.inMilliseconds / total).clamp(0.0, 1.0);
    final displayPosition = durationAtSpeed(
      position,
      timeRespectsSpeed ? speed : 1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Tooltip(
                  message: 'Ouvrir la lecture',
                  child: InkWell(
                    onTap: onOpen,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: PodcastCover(
                              url: imageUrl,
                              localPath: imagePath,
                              size: null,
                              radius: 8,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: onCard,
                                  ),
                                ),
                                Text(
                                  error ??
                                      '$podcastTitle · ${formatClock(displayPosition)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: onCardMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (miniButtons.skipBack)
                IconButton(
                  tooltip: 'Reculer de $skipBack s',
                  visualDensity: VisualDensity.compact,
                  constraints: _btnConstraints,
                  onPressed: () => player.skipBy(-skipBack),
                  icon: SkipIcon.back(size: 22),
                ),
              IconButton(
                tooltip: playing ? 'Pause (Espace)' : 'Lecture (Espace)',
                visualDensity: VisualDensity.compact,
                constraints: _btnConstraints,
                onPressed: player.toggle,
                icon: PlayPauseIcon(playing: playing, size: 26, color: onCard),
              ),
              if (miniButtons.skipForward)
                IconButton(
                  tooltip: 'Avancer de $skipForward s',
                  visualDensity: VisualDensity.compact,
                  constraints: _btnConstraints,
                  onPressed: () => player.skipBy(skipForward),
                  icon: SkipIcon.forward(size: 22),
                ),
              if (miniButtons.nextEpisode)
                IconButton(
                  tooltip: hasNext
                      ? 'Épisode suivant'
                      : 'Pas d’épisode suivant dans la playlist',
                  visualDensity: VisualDensity.compact,
                  constraints: _btnConstraints,
                  onPressed: hasNext ? player.playNextInQueue : null,
                  icon: SkipIcon.next(size: 22),
                ),
              if (miniButtons.close)
                IconButton(
                  tooltip: 'Fermer le lecteur',
                  visualDensity: VisualDensity.compact,
                  constraints: _btnConstraints,
                  onPressed: player.dismiss,
                  icon: Icon(Icons.close, size: 22, color: onCardMuted),
                ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          color: onCard,
          backgroundColor: onCard.withValues(alpha: 0.24),
        ),
      ],
    );
  }
}
