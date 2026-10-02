part of '../player_page.dart';

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

