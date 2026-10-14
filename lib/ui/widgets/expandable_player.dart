import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../player/player_controller.dart';
import '../../player/player_sheet_controller.dart';
import '../../settings/settings_controller.dart';
import '../player_page.dart';
import 'brand.dart';
import 'cover.dart';

/// Hauteur de la pilule mini (hors inset bas géré par le positionnement).
const miniPlayerHeight = 56.0;

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
          final margin = 16 * (1 - t);

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
                      color: Color.lerp(
                        scheme.surfaceContainer,
                        tone?.background ?? scheme.surface,
                        t,
                      ),
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          miniPlayerHeight / 2 * (1 - t),
                        ),
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
                                  expanded: t > 0.05,
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
    final episodeId = ref.watch(playerProvider.select((s) => s.episodeId));
    final favorite = episodeId == null
        ? false
        : (ref.watch(episodeProvider(episodeId)).value?.episode.favorite ??
              false);
    final buttons = ref.watch(
      settingsProvider.select((s) => s.miniPlayerButtons),
    );
    final skipBack = ref.watch(
      settingsProvider.select((s) => s.skipBackSeconds),
    );
    final skipForward = ref.watch(
      settingsProvider.select((s) => s.skipForwardSeconds),
    );
    final hasNext = buttons.isOn('nextEpisode')
        ? (ref.watch(hasNextInQueueProvider).value ?? false)
        : false;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final player = ref.read(playerProvider.notifier);
    final total = duration.inMilliseconds;
    final progress = total == 0
        ? 0.0
        : (position.inMilliseconds / total).clamp(0.0, 1.0);
    final neutral = scheme.surfaceContainerHighest;
    final controls = [
      for (final id in buttons.visible)
        switch (id) {
          'favorite' => _RoundControl(
            tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            background: neutral,
            onPressed: episodeId == null
                ? null
                : () => ref
                      .read(databaseProvider)
                      .setFavorite(episodeId, favorite: !favorite),
            icon: Icon(
              favorite ? Icons.favorite : Icons.favorite_border,
              size: 26,
              color: favorite ? favoriteHeartColor : scheme.onSurface,
            ),
          ),
          'skipBack' => _RoundControl(
            tooltip: 'Reculer de $skipBack s',
            background: neutral,
            onPressed: () => player.skipBy(-skipBack),
            icon: SkipIcon.back(size: 22),
          ),
          'skipForward' => _RoundControl(
            tooltip: 'Avancer de $skipForward s',
            background: neutral,
            onPressed: () => player.skipBy(skipForward),
            icon: SkipIcon.forward(size: 22),
          ),
          'nextEpisode' => _RoundControl(
            tooltip: hasNext
                ? 'Épisode suivant'
                : 'Pas d’épisode suivant dans la file d’attente',
            background: neutral,
            onPressed: hasNext ? player.playNextInQueue : null,
            icon: Opacity(
              opacity: hasNext ? 1 : 0.38,
              child: SkipIcon.next(size: 22),
            ),
          ),
          'close' => _RoundControl(
            tooltip: 'Fermer le lecteur',
            background: neutral,
            onPressed: player.dismiss,
            icon: Icon(Icons.close, size: 22, color: scheme.onSurface),
          ),
          _ => _RoundControl(
            tooltip: playing ? 'Pause (Espace)' : 'Lecture (Espace)',
            background: scheme.primary,
            onPressed: player.toggle,
            icon: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              size: 28,
              color: scheme.onPrimary,
            ),
          ),
        },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const titleMin = 88.0;
          final buttonsWidth =
              (controls.length * 40 + (controls.length - 1) * 8).toDouble();
          final room = constraints.maxWidth - 40 - 10 - 8 - titleMin;
          final buttonMax = math.max(40.0, math.min(buttonsWidth, room));
          return Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: _WavyProgressRing(
                        progress: progress,
                        playing: playing,
                      ),
                    ),
                    PodcastCover(
                      url: imageUrl,
                      localPath: imagePath,
                      size: 26,
                      radius: 13,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: 'Ouvrir la lecture',
                  child: InkWell(
                    onTap: onOpen,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          error ?? podcastTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: buttonMax),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < controls.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        controls[i],
                      ],
                    ],
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

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.tooltip,
    required this.background,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final Color background;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 40, height: 40, child: Center(child: icon)),
        ),
      ),
    );
  }
}

/// Anneau de progression autour de la pochette : plat en pause, ondulé en lecture.
class _WavyProgressRing extends StatefulWidget {
  const _WavyProgressRing({required this.progress, required this.playing});

  final double progress;
  final bool playing;

  @override
  State<_WavyProgressRing> createState() => _WavyProgressRingState();
}

class _WavyProgressRingState extends State<_WavyProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.playing) _wave.repeat();
  }

  @override
  void didUpdateWidget(covariant _WavyProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!widget.playing && _wave.isAnimating) {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wavy = widget.playing && widget.progress > 0;
    return AnimatedBuilder(
      animation: _wave,
      builder: (context, _) {
        return CustomPaint(
          painter: _WavyRingPainter(
            progress: widget.progress,
            phase: _wave.value * math.pi * 2,
            amplitude: wavy ? 2.2 : 0,
            color: scheme.primary,
            trackColor: scheme.surfaceContainerHighest,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _WavyRingPainter extends CustomPainter {
  const _WavyRingPainter({
    required this.progress,
    required this.phase,
    required this.amplitude,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double phase;
  final double amplitude;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);
    if (progress <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    final sweep = math.pi * 2 * progress;
    const start = -math.pi / 2;
    if (amplitude <= 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      return;
    }

    final path = Path();
    final steps = math.max(24, (progress * 80).round());
    for (var i = 0; i <= steps; i++) {
      final angle = start + sweep * (i / steps);
      final wave = math.sin(angle * 8 + phase) * amplitude;
      final point = Offset(
        center.dx + (radius + wave) * math.cos(angle),
        center.dy + (radius + wave) * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavyRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
