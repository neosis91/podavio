import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cover_tone.dart';
import '../../data/feed_service.dart';
import '../../data/providers.dart';
import '../../player/player_controller.dart';
import '../../settings/settings_controller.dart';
import '../widgets/brand.dart';
import '../widgets/empty_state.dart';
import 'player_controls.dart';
import 'player_now_playing.dart';
import 'player_panel.dart';
import 'player_sheets.dart';

class _CoverToneKey {
  const _CoverToneKey(this.path, this.url, this.username, this.password);

  final String path;
  final String url;
  final String username;
  final String password;

  @override
  bool operator ==(Object other) {
    return other is _CoverToneKey &&
        other.path == path &&
        other.url == url &&
        other.username == username &&
        other.password == password;
  }

  @override
  int get hashCode => Object.hash(path, url, username, password);
}

final _coverToneProvider = FutureProvider.family<CoverTone?, _CoverToneKey>((
  ref,
  key,
) {
  final eco = ref.watch(
    settingsProvider.select((settings) => settings.ecoMode),
  );
  return loadCoverTone(
    path: key.path,
    url: key.url,
    headers: podcastAuthHeaders(username: key.username, password: key.password),
    allowDownload: !eco,
  );
});

CoverTone? watchPlayerCoverTone(WidgetRef ref) {
  final episodeId = ref.watch(
    playerProvider.select((state) => state.episodeId),
  );
  if (episodeId == null) return null;
  final imagePath =
      ref.watch(playerProvider.select((state) => state.imagePath))?.trim() ??
      '';
  final imageUrl =
      ref.watch(playerProvider.select((state) => state.imageUrl))?.trim() ?? '';
  final credentials = ref.watch(
    episodeProvider(episodeId).select((async) {
      final podcast = async.value?.podcast;
      return '${podcast?.authUsername ?? ''}\u0000${podcast?.authPassword ?? ''}';
    }),
  );
  final credentialParts = credentials.split('\u0000');
  return ref
      .watch(
        _coverToneProvider(
          _CoverToneKey(
            imagePath,
            imageUrl,
            credentialParts.first,
            credentialParts.length > 1 ? credentialParts[1] : '',
          ),
        ),
      )
      .value;
}

class PlayerPage extends ConsumerWidget {
  const PlayerPage({
    super.key,
    this.onCollapse,
    this.embedded = false,
    this.expanded = false,
    this.onHeaderDragStart,
    this.onHeaderDragUpdate,
    this.onHeaderDragEnd,
    this.onHeaderDragCancel,
  });

  /// Si fourni, remplace le pop navigateur (lecteur expansible).
  final VoidCallback? onCollapse;

  /// Affiché dans le sheet : fond transparent géré par le parent.
  final bool embedded;

  /// Le lecteur couvre l’écran : le retour système le réduit au lieu de quitter.
  final bool expanded;

  final GestureDragStartCallback? onHeaderDragStart;
  final GestureDragUpdateCallback? onHeaderDragUpdate;
  final GestureDragEndCallback? onHeaderDragEnd;
  final GestureDragCancelCallback? onHeaderDragCancel;

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
            icon: const SkipIcon.collapse(size: 26),
          ),
        ),
        body: const EmptyState(
          title: 'Aucune lecture',
          message: 'Lancez un épisode pour ouvrir le lecteur.',
        ),
      );
    }

    final carMode = ref.watch(playerProvider.select((state) => state.carMode));
    final tintFromCover = ref.watch(
      settingsProvider.select((settings) => settings.tintFromCover),
    );
    final tone = tintFromCover ? watchPlayerCoverTone(ref) : null;
    final fallback = embedded
        ? Colors.transparent
        : Theme.of(context).colorScheme.surface;
    final appBar = AppBar(
      leading: IconButton(
        tooltip: 'Réduire',
        onPressed: () => _collapse(context),
        icon: const SkipIcon.collapse(size: 26),
      ),
      actions: carMode
          ? [
              IconButton(
                tooltip: 'Quitter le mode voiture',
                onPressed: () {
                  ref.read(playerProvider.notifier).setCarMode(false);
                },
                icon: const Icon(Icons.directions_car),
              ),
            ]
          : [
              const PlayerCastAction(),
              const PlayerSpeedAction(),
              const PlayerSleepAction(),
              PlayerEpisodeActions(episodeId: episodeId),
            ],
    );

    final showPlaylist =
        ref.watch(playerPanelProvider) == PlayerPanel.playlist && !carMode;
    final blockBack = showPlaylist || (embedded && expanded);
    return _CoverBackdrop(
      tone: tone,
      fallback: fallback,
      child: PopScope(
        canPop: !blockBack,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (closePlayerPlaylistIfOpen(ref)) return;
          onCollapse?.call();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: PreferredSize(
                preferredSize: appBar.preferredSize,
                child: PlayerCollapseHeader(
                  onVerticalDragStart: onHeaderDragStart,
                  onVerticalDragUpdate: onHeaderDragUpdate,
                  onVerticalDragEnd: onHeaderDragEnd,
                  onVerticalDragCancel: onHeaderDragCancel,
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
                        child: _PageCollapseDrag(
                          immediate: true,
                          onDragStart: onHeaderDragStart,
                          onDragUpdate: onHeaderDragUpdate,
                          onDragEnd: onHeaderDragEnd,
                          onDragCancel: onHeaderDragCancel,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: _PlayerStage(episodeId: episodeId),
                            ),
                          ),
                        ),
                      ),
                      if (showTransport)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 720,
                                ),
                                child: const PlayerTransport(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (!carMode)
              _QueueSheet(background: tone?.background, themed: !tintFromCover),
          ],
        ),
      ),
    );
  }
}

/// La file monte et redescend comme le grand lecteur.
class _QueueSheet extends ConsumerStatefulWidget {
  const _QueueSheet({required this.background, required this.themed});

  final Color? background;

  /// Vrai quand la teinte de la pochette est coupée : le fond reste le thème.
  final bool themed;

  @override
  ConsumerState<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends ConsumerState<_QueueSheet>
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(playerPanelProvider) == PlayerPanel.playlist) {
        _animateTo(1);
      }
    });
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
    final velocity = details.primaryVelocity ?? 0;
    final target = velocity < -600
        ? 1.0
        : velocity > 600
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
    final open = ref.read(playerPanelProvider) == PlayerPanel.playlist;
    final notifier = ref.read(playerPanelProvider.notifier);
    if (target >= 1) {
      if (open) {
        _animateTo(1);
      } else {
        notifier.toggle();
      }
    } else if (open) {
      notifier.close();
    } else {
      _animateTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerPanelProvider, (previous, next) {
      if (_dragging) return;
      _animateTo(next == PlayerPanel.playlist ? 1 : 0);
    });

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final extent = constraints.maxHeight;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              if (t == 0) {
                return const IgnorePointer(child: SizedBox.expand());
              }
              return Align(
                alignment: Alignment.bottomCenter,
                child: IgnorePointer(
                  ignoring: t < 0.5 && !_dragging,
                  child: SizedBox(
                    height: extent * t,
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(18 * (1 - t)),
                        ),
                      ),
                      // La file est mise en page à pleine hauteur, puis coupée.
                      // Sinon la colonne déborde tant que le panneau est encore bas.
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: extent,
                        maxHeight: extent,
                        child: _PlaylistOverlay(
                          background: widget.background,
                          themed: widget.themed,
                          sheetFullyOpen: () => _controller.value >= 0.999,
                          onDragStart: _onDragStart,
                          onDragUpdate: (details) =>
                              _onDragUpdate(details, extent),
                          onDragEnd: _onDragEnd,
                          onDragCancel: _onDragCancel,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlaylistOverlay extends StatelessWidget {
  const _PlaylistOverlay({
    required this.background,
    required this.themed,
    required this.sheetFullyOpen,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  final Color? background;
  final bool themed;
  final bool Function() sheetFullyOpen;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final gradient = themed
        ? LinearGradient(colors: [surface, surface])
        : background == null
        ? coverPlayerGradient(const Color(0xFF121212))
        : coverPlayerGradient(background!);
    return _PageCollapseDrag(
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      onDragCancel: onDragCancel,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final maxContent = width >= 840
                  ? math.min(width - 64, 1120.0)
                  : width;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContent),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: PlayerQueue(
                      sheetFullyOpen: sheetFullyOpen,
                      onDragStart: onDragStart,
                      onDragUpdate: onDragUpdate,
                      onDragEnd: onDragEnd,
                      onDragCancel: onDragCancel,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Glisser vers le bas réduit le lecteur en suivant le doigt.
/// Dans la file, l’appui long sert à réordonner. Le glissé vers le bas
/// ferme la file seulement s’il part du haut de la liste.
class _PageCollapseDrag extends StatefulWidget {
  const _PageCollapseDrag({
    required this.child,
    this.immediate = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
  });

  final Widget child;

  /// Vrai sur le grand lecteur : le swipe vers le bas suffit.
  final bool immediate;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;
  final GestureDragCancelCallback? onDragCancel;

  @override
  State<_PageCollapseDrag> createState() => _PageCollapseDragState();
}

class _PageCollapseDragState extends State<_PageCollapseDrag> {
  Offset? _last;
  var _claimed = false;
  var _collapsing = false;

  void _reset() {
    _last = null;
    _claimed = false;
    _collapsing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onDragUpdate == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: widget.immediate ? widget.onDragStart : null,
      onVerticalDragUpdate: widget.immediate ? widget.onDragUpdate : null,
      onVerticalDragEnd: widget.immediate ? widget.onDragEnd : null,
      onVerticalDragCancel: widget.immediate ? widget.onDragCancel : null,
      onLongPressStart: widget.immediate
          ? null
          : (details) {
              Feedback.forLongPress(context);
              _last = details.globalPosition;
              _claimed = false;
              _collapsing = false;
            },
      onLongPressMoveUpdate: widget.immediate
          ? null
          : (details) {
              if (!_claimed) {
                final delta = details.offsetFromOrigin;
                if (delta.distance < kTouchSlop) return;
                _claimed = true;
                // Vers le bas : réduire. Ailleurs : laisser réordonner la file.
                if (delta.dy <= delta.dx.abs()) {
                  startQueueReorder();
                  return;
                }
                _collapsing = true;
                widget.onDragStart?.call(
                  DragStartDetails(
                    globalPosition: details.globalPosition,
                    localPosition: details.localPosition,
                  ),
                );
              }
              if (!_collapsing) return;
              final last = _last ?? details.globalPosition;
              final dy = details.globalPosition.dy - last.dy;
              _last = details.globalPosition;
              widget.onDragUpdate?.call(
                DragUpdateDetails(
                  globalPosition: details.globalPosition,
                  localPosition: details.localPosition,
                  delta: Offset(0, dy),
                  primaryDelta: dy,
                ),
              );
            },
      onLongPressEnd: widget.immediate
          ? null
          : (details) {
              final collapsing = _collapsing;
              _reset();
              if (!collapsing) return;
              widget.onDragEnd?.call(
                DragEndDetails(
                  velocity: details.velocity,
                  primaryVelocity: details.velocity.pixelsPerSecond.dy,
                ),
              );
            },
      onLongPressCancel: widget.immediate
          ? null
          : () {
              final collapsing = _collapsing;
              _reset();
              if (collapsing) widget.onDragCancel?.call();
            },
      child: widget.child,
    );
  }
}

class _CoverBackdrop extends StatefulWidget {
  const _CoverBackdrop({
    required this.tone,
    required this.fallback,
    required this.child,
  });

  final CoverTone? tone;
  final Color fallback;
  final Widget child;

  @override
  State<_CoverBackdrop> createState() => _CoverBackdropState();
}

class _CoverBackdropState extends State<_CoverBackdrop> {
  Duration _duration = Duration.zero;

  @override
  void didUpdateWidget(covariant _CoverBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.tone?.background;
    final next = widget.tone?.background;
    _duration = previous != null && next != null && previous != next
        ? const Duration(milliseconds: 450)
        : Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    final gradient = widget.tone == null
        ? LinearGradient(colors: [widget.fallback, widget.fallback])
        : coverPlayerGradient(widget.tone!.background);
    final theme = widget.tone == null
        ? Theme.of(context)
        : playbackTheme(widget.tone!.background);
    return AnimatedContainer(
      duration: _duration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(gradient: gradient),
      child: Theme(data: theme, child: widget.child),
    );
  }
}

class _PlayerStage extends ConsumerWidget {
  const _PlayerStage({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carMode = ref.watch(playerProvider.select((state) => state.carMode));
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: PlayerNowPlaying(episodeId: episodeId, carMode: carMode),
    );
  }
}
