part of '../player_page.dart';

enum _PlayerPanel { cover, playlist }

class _PlayerPanelNotifier extends Notifier<_PlayerPanel> {
  @override
  _PlayerPanel build() => _PlayerPanel.cover;

  void toggle() {
    state = state == _PlayerPanel.cover
        ? _PlayerPanel.playlist
        : _PlayerPanel.cover;
  }

  void close() => state = _PlayerPanel.cover;
}

/// Ferme la playlist du grand lecteur. Renvoie vrai si elle était ouverte.
bool closePlayerPlaylistIfOpen(WidgetRef ref) {
  if (ref.read(_playerPanelProvider) != _PlayerPanel.playlist) return false;
  ref.read(_playerPanelProvider.notifier).close();
  return true;
}

final _playerPanelProvider =
    NotifierProvider<_PlayerPanelNotifier, _PlayerPanel>(
      _PlayerPanelNotifier.new,
    );

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
  return loadCoverTone(
    path: key.path,
    url: key.url,
    headers: podcastAuthHeaders(username: key.username, password: key.password),
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
    this.onHeaderDragStart,
    this.onHeaderDragUpdate,
    this.onHeaderDragEnd,
    this.onHeaderDragCancel,
  });

  /// Si fourni, remplace le pop navigateur (lecteur expansible).
  final VoidCallback? onCollapse;

  /// Affiché dans le sheet : fond transparent géré par le parent.
  final bool embedded;

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
    final tone = watchPlayerCoverTone(ref);
    final fallback = embedded
        ? Colors.transparent
        : Theme.of(context).colorScheme.surface;
    final appBar = AppBar(
      leading: IconButton(
        tooltip: 'Réduire',
        onPressed: () => _collapse(context),
        icon: const SkipIcon.collapse(),
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
              _ShareAction(episodeId: episodeId),
              _PlayerActions(episodeId: episodeId),
            ],
    );

    final showPlaylist =
        ref.watch(_playerPanelProvider) == _PlayerPanel.playlist && !carMode;
    return _CoverBackdrop(
      tone: tone,
      fallback: fallback,
      child: PopScope(
        canPop: !showPlaylist,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) closePlayerPlaylistIfOpen(ref);
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
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: _PlayerStage(episodeId: episodeId),
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
                                child: const _PlayerTransport(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (showPlaylist)
              Positioned.fill(
                child: _PlaylistOverlay(background: tone?.background),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistOverlay extends StatelessWidget {
  const _PlaylistOverlay({required this.background});

  final Color? background;

  @override
  Widget build(BuildContext context) {
    final gradient = background == null
        ? coverPlayerGradient(const Color(0xFF121212))
        : coverPlayerGradient(background!);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: _PlayerQueue(),
            ),
          ),
        ),
      ),
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

/// Zone de drag pour réduire le lecteur (swipe bas depuis le header).
class PlayerCollapseHeader extends StatelessWidget {
  const PlayerCollapseHeader({
    super.key,
    required this.child,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
  });

  final Widget child;
  final GestureDragStartCallback? onVerticalDragStart;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragEndCallback? onVerticalDragEnd;
  final GestureDragCancelCallback? onVerticalDragCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: onVerticalDragStart,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      onVerticalDragCancel: onVerticalDragCancel,
      child: child,
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
      child: _PlayerNowPlaying(episodeId: episodeId, carMode: carMode),
    );
  }
}
