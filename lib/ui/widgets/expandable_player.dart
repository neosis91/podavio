import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../player/player_controller.dart';
import '../../player/player_sheet_controller.dart';
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
    )..addListener(() => setState(() {}));
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

  void _onDragUpdate(DragUpdateDetails details, double extent) {
    if (extent <= 0) return;
    _dragging = true;
    final delta = -details.primaryDelta! / extent;
    _controller.value = (_controller.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final vx = details.primaryVelocity ?? 0;
    if (vx < -600) {
      _animateTo(1);
      return;
    }
    if (vx > 600) {
      _animateTo(0);
      return;
    }
    _animateTo(_controller.value >= 0.45 ? 1 : 0);
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
      if (next != true) _animateTo(0);
    });

    if (!hasEpisode) return const SizedBox.shrink();

    final size = MediaQuery.sizeOf(context);
    final t = _controller.value;
    // Toujours au-dessus du menu bas / à droite du rail ; seule la hauteur s’étend.
    final bottom = widget.bottomInset;
    final maxHeight = (size.height - bottom - widget.topInset).clamp(
      miniPlayerHeight,
      size.height,
    );
    final height = miniPlayerHeight + (maxHeight - miniPlayerHeight) * t;
    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      left: widget.leftInset,
      right: 0,
      bottom: bottom,
      height: height.clamp(miniPlayerHeight, maxHeight),
      child: BackButtonListener(
        onBackButtonPressed: () async {
          if (_controller.value <= 0.05) return false;
          _animateTo(0);
          return true;
        },
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: bottom > 0,
          removeLeft: widget.leftInset > 0,
          removeTop: widget.topInset > 0,
          child: Material(
            elevation: 6 + 6 * t,
            color: Color.lerp(scheme.surfaceContainer, scheme.surface, t),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: t < 0.15,
                    child: Opacity(
                      opacity: Curves.easeOut.transform(
                        ((t - 0.12) / 0.88).clamp(0.0, 1.0),
                      ),
                      child: PlayerPage(
                        embedded: true,
                        onCollapse: () =>
                            ref.read(playerSheetProvider.notifier).collapse(),
                        onHeaderDragUpdate: (details) => _onDragUpdate(
                          details,
                          maxHeight - miniPlayerHeight,
                        ),
                        onHeaderDragEnd: _onDragEnd,
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
                    ignoring: t > 0.2,
                    child: Opacity(
                      opacity: (1 - t / 0.35).clamp(0.0, 1.0),
                      child: _MiniPlayerBar(
                        onOpen: () =>
                            ref.read(playerSheetProvider.notifier).expand(),
                        onVerticalDragUpdate: (details) => _onDragUpdate(
                          details,
                          maxHeight - miniPlayerHeight,
                        ),
                        onVerticalDragEnd: _onDragEnd,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerBar extends ConsumerWidget {
  const _MiniPlayerBar({
    required this.onOpen,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  final VoidCallback onOpen;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final scheme = Theme.of(context).colorScheme;
    final total = player.duration.inMilliseconds;
    final progress = total == 0
        ? 0.0
        : (player.position.inMilliseconds / total).clamp(0.0, 1.0);

    return GestureDetector(
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress, minHeight: 2),
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
                          AspectRatio(
                            aspectRatio: 1,
                            child: PodcastCover(
                              url: player.imageUrl,
                              localPath: player.imagePath,
                              size: null,
                              radius: 0,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    player.error ??
                                        '${player.podcastTitle} · ${formatClock(player.position)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_up,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: player.playing
                      ? 'Pause (Espace)'
                      : 'Lecture (Espace)',
                  onPressed: () => ref.read(playerProvider.notifier).toggle(),
                  icon: PlayPauseIcon(playing: player.playing, size: 28),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
