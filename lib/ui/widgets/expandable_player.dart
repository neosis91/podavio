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
    final bottom = widget.bottomInset;
    final maxHeight = (size.height - bottom - widget.topInset).clamp(
      miniPlayerHeight,
      size.height,
    );
    final scheme = Theme.of(context).colorScheme;
    final extent = maxHeight - miniPlayerHeight;

    return Positioned(
      left: widget.leftInset,
      right: 0,
      bottom: bottom,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final height = miniPlayerHeight + extent * t;

          return SizedBox(
            height: height.clamp(miniPlayerHeight, maxHeight),
            child: BackButtonListener(
              onBackButtonPressed: () async {
                if (_controller.value <= 0.05) return false;
                ref.read(playerSheetProvider.notifier).collapse();
                return true;
              },
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: bottom > 0,
                removeLeft: widget.leftInset > 0,
                removeTop: widget.topInset > 0,
                // Drag sur la mini-barre (expand) et le header (collapse) :
                // pas de GestureDetector parent (conflit avec le PageView vertical).
                // `_dragging` empêche IgnorePointer de couper le geste à mi-course.
                child: Material(
                  elevation: 6 + 6 * t,
                  color: Color.lerp(
                    scheme.surfaceContainer,
                    scheme.surface,
                    t,
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
                              child: _MiniPlayerBar(
                                onOpen: () => ref
                                    .read(playerSheetProvider.notifier)
                                    .expand(),
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
          );
        },
      ),
    );
  }
}

class _MiniPlayerBar extends ConsumerWidget {
  const _MiniPlayerBar({required this.onOpen});

  final VoidCallback onOpen;

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
    final error = ref.watch(playerProvider.select((s) => s.error));
    final scheme = Theme.of(context).colorScheme;
    final total = duration.inMilliseconds;
    final progress = total == 0
        ? 0.0
        : (position.inMilliseconds / total).clamp(0.0, 1.0);

    return Column(
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
                            url: imageUrl,
                            localPath: imagePath,
                            size: null,
                            radius: 0,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  error ??
                                      '$podcastTitle · ${formatClock(position)}',
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
                tooltip: playing ? 'Pause (Espace)' : 'Lecture (Espace)',
                onPressed: () => ref.read(playerProvider.notifier).toggle(),
                icon: PlayPauseIcon(playing: playing, size: 28),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
