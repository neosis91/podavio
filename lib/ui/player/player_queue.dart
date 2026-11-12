import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../data/providers.dart';
import '../../player/playback_source.dart';
import '../../player/player_controller.dart';
import '../../settings/settings_controller.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/brand.dart';
import '../widgets/empty_state.dart';
import '../widgets/episode_tile.dart';
import 'player_panel.dart';
import 'queue_sheet_drag.dart';

class PlayerQueue extends ConsumerStatefulWidget {
  const PlayerQueue({
    super.key,
    required this.sheetFullyOpen,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  /// Vrai quand la file couvre le lecteur. Un glissement vers le bas la ferme.
  final bool Function() sheetFullyOpen;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  @override
  ConsumerState<PlayerQueue> createState() => _PlayerQueueState();
}

class _PlayerQueueState extends ConsumerState<PlayerQueue> {
  late final QueueSheetScrollController _scroll;
  final _nowPlayingKey = GlobalKey();
  List<int>? _orderIds;
  PlaybackSource? _orderSource;
  var _previousCount = 0;
  var _queueReady = false;
  var _revealed = false;
  var _revealScheduled = false;
  var _revealExtent = -1.0;
  var _loadingEarlier = false;

  @override
  void initState() {
    super.initState();
    _scroll = QueueSheetScrollController(
      sheetFullyOpen: () => widget.sheetFullyOpen(),
      onSheetStart: widget.onDragStart,
      onSheetDelta: (delta) {
        widget.onDragUpdate(
          DragUpdateDetails(
            delta: Offset(0, delta),
            primaryDelta: delta,
            globalPosition: Offset.zero,
          ),
        );
      },
      onSheetEnd: widget.onDragEnd,
      onSheetCancel: widget.onDragCancel,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scheduleReveal() {
    if (_revealed || !_queueReady || _revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      _revealCurrent();
    });
  }

  /// Amène l’épisode en cours en haut si les précédents le poussent hors écran.
  void _revealCurrent() {
    if (!mounted || _revealed) return;
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) {
      _scheduleReveal();
      return;
    }
    final position = _scroll.position;
    final update = advanceQueueReveal(
      state: QueueRevealState(
        revealed: _revealed,
        extent: _revealExtent,
        offset: position.pixels,
      ),
      maxExtent: position.maxScrollExtent,
      target: queueRevealTarget(
        previousCount: _previousCount,
        rowHeight: _queueWide(context) ? 84 : 60,
      ),
      viewport: position.viewportDimension,
      previousCount: _previousCount,
    );
    _revealed = update.state.revealed;
    _revealExtent = update.state.extent;
    final jump = update.jumpTo;
    if (jump != null) position.jumpTo(jump);
    if (update.reschedule) {
      _scheduleReveal();
      return;
    }
    if (jump == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _nowPlayingKey.currentContext;
      if (targetContext == null || !mounted) return;
      Scrollable.ensureVisible(targetContext, alignment: 0);
    });
  }

  /// Charge une page au-dessus et garde l’épisode affiché en place.
  Future<void> _loadEarlier(double pixels) async {
    if (_loadingEarlier) return;
    _loadingEarlier = true;
    final added = await ref.read(playerProvider.notifier).prependQueue();
    if (!mounted || added == 0 || !_scroll.hasClients) {
      _loadingEarlier = false;
      return;
    }
    _holdPlace(pixels, added);
  }

  void _holdPlace(double pixels, int added, [int tries = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) {
        _loadingEarlier = false;
        return;
      }
      final position = _scroll.position;
      final shift = added * (_queueWide(context) ? 84.0 : 60.0);
      final target = pixels + shift;
      if (tries < 4 && position.maxScrollExtent + 1 < target) {
        _holdPlace(pixels, added, tries + 1);
        return;
      }
      position.jumpTo(target.clamp(0.0, position.maxScrollExtent));
      _loadingEarlier = false;
    });
  }

  List<EpisodeEntry> _ordered(
    List<EpisodeEntry> entries,
    PlaybackSource source,
  ) {
    final ids = _orderSource == source ? _orderIds : null;
    if (ids == null) return entries;
    final byId = {for (final entry in entries) entry.episode.id: entry};
    final ordered = <EpisodeEntry>[];
    for (final id in ids) {
      final entry = byId[id];
      if (entry != null) ordered.add(entry);
    }
    if (ordered.length != entries.length) return entries;
    return ordered;
  }

  void _commit(List<EpisodeEntry> next) {
    final source = ref.read(playerProvider).playbackSource;
    final ids = next.map((entry) => entry.episode.id).toList();
    setState(() {
      _orderIds = ids;
      _orderSource = source;
    });
    final playlistId = source.query.playlistId;
    if (playlistId != null) {
      ref.read(databaseProvider).setPlaylistOrder(playlistId, ids);
    } else {
      ref.read(databaseProvider).setQueueOrder(ids);
    }
  }

  void _move(List<EpisodeEntry> entries, int from, int delta) {
    final to = from + delta;
    if (from < 0 || to < 0 || to >= entries.length) return;
    final next = [...entries];
    final moved = next.removeAt(from);
    next.insert(to, moved);
    _commit(next);
  }

  void _showActions({
    required EpisodeEntry entry,
    required int position,
    required int count,
    required List<EpisodeEntry> entries,
  }) {
    showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (position > 0)
                ListTile(
                  leading: const MoveUpIcon(),
                  title: const Text('Monter'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _move(entries, position, -1);
                  },
                ),
              if (position < count - 1)
                ListTile(
                  leading: const MoveDownIcon(),
                  title: const Text('Descendre'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _move(entries, position, 1);
                  },
                ),
              ListTile(
                leading: const DeleteIcon(),
                title: const Text('Supprimer'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final source = ref.read(playerProvider).playbackSource;
                  setState(() {
                    _orderIds = _orderIds
                        ?.where((id) => id != entry.episode.id)
                        .toList();
                    _orderSource = source;
                  });
                  final playlistId = source.query.playlistId;
                  if (playlistId != null) {
                    ref
                        .read(databaseProvider)
                        .removeFromPlaylist(playlistId, entry.episode.id);
                  } else {
                    ref
                        .read(databaseProvider)
                        .removeFromQueue(entry.episode.id);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Charge les pages voisines. La fermeture au glissé est dans
  /// [QueueSheetScrollController] : un geste qui défile ne ferme pas la file.
  bool _onQueueScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    if (!_revealed) return false;
    final metrics = notification.metrics;
    if (metrics.extentBefore < 480) {
      _loadEarlier(metrics.pixels);
    }
    if (metrics.extentAfter < 480) {
      ref.read(playerProvider.notifier).extendQueue();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(
      playerProvider.select((state) => state.playbackSource),
    );
    final window = ref.watch(episodesProvider(source.query));
    final currentId = ref.watch(
      playerProvider.select((state) => state.episodeId),
    );
    final current = currentId == null
        ? null
        : ref.watch(episodeProvider(currentId)).value;
    final loaded = window.asData?.value.entries ?? const <EpisodeEntry>[];
    final entries = _ordered(loaded, source);
    final editable = source.canEditOrder;
    final currentInQueue =
        currentId != null &&
        entries.any((entry) => entry.episode.id == currentId);
    final currentIndex = currentId == null
        ? -1
        : entries.indexWhere((entry) => entry.episode.id == currentId);
    final previous = currentIndex <= 0
        ? const <EpisodeEntry>[]
        : entries.sublist(0, currentIndex);
    final upcoming = currentIndex < 0
        ? entries
        : entries.sublist(currentIndex + 1);
    final emptyQueue = !window.isLoading && entries.isEmpty;
    final canAddToQueue =
        source.isQueue && !currentInQueue && !window.isLoading;
    _previousCount = previous.length;
    _queueReady = !window.isLoading || entries.isNotEmpty;
    _scheduleReveal();

    final collapseBar = AppBar(
      leading: IconButton(
        tooltip: 'Réduire',
        onPressed: () => ref.read(playerPanelProvider.notifier).close(),
        icon: const SkipIcon.collapse(),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerCollapseHeader(
          onVerticalDragStart: widget.onDragStart,
          onVerticalDragUpdate: widget.onDragUpdate,
          onVerticalDragEnd: widget.onDragEnd,
          onVerticalDragCancel: widget.onDragCancel,
          child: collapseBar,
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onQueueScroll,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
                if (previous.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _QueueSectionTitle('Précédents')),
                  SliverList.builder(
                    itemCount: previous.length,
                    itemBuilder: (context, index) {
                      final entry = previous[index];
                      return _QueueRow(
                        key: ValueKey('prev-${entry.episode.id}'),
                        entry: entry,
                        index: index,
                        reorderable: false,
                        onMore: editable
                            ? () => _showActions(
                                entry: entry,
                                position: index,
                                count: entries.length,
                                entries: entries,
                              )
                            : null,
                      );
                    },
                  ),
                ],
                if (current != null)
                  SliverToBoxAdapter(
                    child: _QueueNowPlaying(
                      key: _nowPlayingKey,
                      entry: current,
                      canAdd: canAddToQueue,
                    ),
                  ),
                if (window.isLoading && entries.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  SliverToBoxAdapter(child: _QueueSectionTitle('À suivre')),
                  if (emptyQueue || upcoming.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        title: emptyQueue
                            ? (source.isQueue
                                  ? 'La file d’attente est vide'
                                  : 'Cette liste est vide')
                            : 'Rien à suivre',
                        message: emptyQueue
                            ? (source.isQueue
                                  ? 'Ajoutez des épisodes pour les écouter les uns à la suite des autres.'
                                  : 'Les épisodes de cette liste apparaîtront ici.')
                            : 'Les épisodes suivants apparaîtront ici.',
                      ),
                    )
                  else if (editable)
                    SliverReorderableList(
                      itemCount: upcoming.length,
                      proxyDecorator: _queueDragProxy,
                      onReorderItem: (oldIndex, newIndex) {
                        final next = [...upcoming];
                        final moved = next.removeAt(oldIndex);
                        next.insert(newIndex, moved);
                        final head = entries.sublist(0, currentIndex + 1);
                        _commit([...head, ...next]);
                      },
                      itemBuilder: (context, index) {
                        final entry = upcoming[index];
                        final position = currentIndex + 1 + index;
                        return _QueueRow(
                          key: ValueKey(entry.episode.id),
                          entry: entry,
                          index: index,
                          onMore: () => _showActions(
                            entry: entry,
                            position: position,
                            count: entries.length,
                            entries: entries,
                          ),
                        );
                      },
                    )
                  else
                    SliverList.builder(
                      itemCount: upcoming.length,
                      itemBuilder: (context, index) {
                        final entry = upcoming[index];
                        return _QueueRow(
                          key: ValueKey(entry.episode.id),
                          entry: entry,
                          index: index,
                          reorderable: false,
                        );
                      },
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QueueSectionTitle extends StatelessWidget {
  const _QueueSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

bool _queueWide(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= 840;
}

/// Où en est le placement de l’épisode en cours dans la file.
enum QueueReveal {
  /// L’étendue du scroll grandit encore.
  wait,

  /// Assez de contenu en dessous pour le mettre en haut.
  pin,

  /// « À suivre » est trop court : laisser scroller vers « Précédents ».
  settle,
}

/// Hauteur estimée du titre de section et de l’épisode en cours.
const queueSectionTitleHeight = 36.0;
const queueNowPlayingRevealHeight = 80.0;

/// Décalage pour coller l’épisode en cours en haut de la file.
double queueRevealTarget({
  required int previousCount,
  required double rowHeight,
}) {
  return queueSectionTitleHeight + previousCount * rowHeight;
}

/// État du placement, d’une image à l’autre.
class QueueRevealState {
  const QueueRevealState({
    this.revealed = false,
    this.extent = -1,
    this.offset = 0,
  });

  final bool revealed;

  /// Dernière étendue mesurée. `-1` avant la première.
  final double extent;
  final double offset;
}

/// Résultat d’une image. [jumpTo] absent : ne pas toucher au scroll.
class QueueRevealUpdate {
  const QueueRevealUpdate({
    required this.state,
    required this.jumpTo,
    required this.reschedule,
  });

  final QueueRevealState state;
  final double? jumpTo;
  final bool reschedule;
}

/// Une image du placement. C’est cette fonction que la file appelle :
/// un « À suivre » trop court doit finir en [QueueReveal.settle], sans
/// ramener le décalage en bas aux images suivantes.
QueueRevealUpdate advanceQueueReveal({
  required QueueRevealState state,
  required double maxExtent,
  required double target,
  required double viewport,
  required int previousCount,
}) {
  if (state.revealed || previousCount <= 0) {
    return QueueRevealUpdate(
      state: QueueRevealState(
        revealed: true,
        extent: state.extent,
        offset: state.offset,
      ),
      jumpTo: null,
      reschedule: false,
    );
  }
  if (target + queueNowPlayingRevealHeight <= viewport) {
    return QueueRevealUpdate(
      state: QueueRevealState(
        revealed: true,
        extent: state.extent,
        offset: state.offset,
      ),
      jumpTo: null,
      reschedule: false,
    );
  }
  final step = queueRevealStep(
    maxExtent: maxExtent,
    target: target,
    previousExtent: state.extent,
  );
  switch (step) {
    case QueueReveal.wait:
      return QueueRevealUpdate(
        state: QueueRevealState(
          revealed: false,
          extent: maxExtent,
          offset: maxExtent,
        ),
        jumpTo: maxExtent,
        reschedule: true,
      );
    case QueueReveal.settle:
      return QueueRevealUpdate(
        state: QueueRevealState(
          revealed: true,
          extent: state.extent,
          offset: state.offset,
        ),
        jumpTo: null,
        reschedule: false,
      );
    case QueueReveal.pin:
      final pinned = target.clamp(0.0, maxExtent);
      return QueueRevealUpdate(
        state: QueueRevealState(
          revealed: true,
          extent: state.extent,
          offset: pinned,
        ),
        jumpTo: pinned,
        reschedule: false,
      );
  }
}

/// [previousExtent] vaut `-1` avant la première mesure.
QueueReveal queueRevealStep({
  required double maxExtent,
  required double target,
  required double previousExtent,
}) {
  if (maxExtent + 1 < target) {
    if (maxExtent > previousExtent + 0.5) return QueueReveal.wait;
    return QueueReveal.settle;
  }
  return QueueReveal.pin;
}

class _QueueHold {
  const _QueueHold(this.index, this.context, this.event);

  final int index;
  final BuildContext context;
  final PointerDownEvent event;
}

final _queueHolds = <int, _QueueHold>{};

/// Mémorise la ligne touchée pour réordonner si le glisser n’est pas vers le bas.
class _QueueReorderHold extends StatelessWidget {
  const _QueueReorderHold({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _queueHolds[event.pointer] = _QueueHold(index, context, event);
      },
      onPointerUp: (event) => _queueHolds.remove(event.pointer),
      onPointerCancel: (event) => _queueHolds.remove(event.pointer),
      child: child,
    );
  }
}

void startQueueReorder() {
  if (_queueHolds.length != 1) return;
  final hold = _queueHolds.values.single;
  if (!hold.context.mounted) return;
  final list = SliverReorderableList.maybeOf(hold.context);
  if (list == null) return;
  list.startItemDragReorder(
    index: hold.index,
    event: hold.event,
    recognizer: ImmediateMultiDragGestureRecognizer()
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(hold.context),
  );
}

Widget _queueDragProxy(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      return Material(
        elevation: 8 * t,
        shadowColor: Colors.black45,
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(8),
        child: child,
      );
    },
    child: child,
  );
}

class _QueueNowPlaying extends ConsumerWidget {
  const _QueueNowPlaying({
    super.key,
    required this.entry,
    required this.canAdd,
  });

  final EpisodeEntry entry;
  final bool canAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preferPodcastCover = ref.watch(
      settingsProvider.select((settings) => settings.preferPodcastCover),
    );
    final density = ref.watch(
      settingsProvider.select((settings) => settings.episodeListDensity),
    );
    final timing = _episodeLineTiming(ref, entry.episode);
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      child: InkWell(
        onTap: () => ref.read(playerProvider.notifier).playOrPauseEntry(entry),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _queueWide(context) ? 28 : 20,
            _queueWide(context) ? 10 : 6,
            8,
            _queueWide(context) ? 10 : 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: EpisodeLine(
                  entry: entry,
                  density: density,
                  preferPodcastCover: preferPodcastCover,
                  position: timing.$1,
                  duration: timing.$2,
                  coverSize: _queueWide(context) ? 72 : 55,
                  titleStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  metaStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (canAdd)
                IconButton(
                  tooltip: 'Ajouter l’épisode',
                  onPressed: () =>
                      ref.read(databaseProvider).addToQueue(entry.episode.id),
                  icon: const PlaylistAddIcon(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueRow extends ConsumerWidget {
  const _QueueRow({
    super.key,
    required this.entry,
    required this.index,
    this.onMore,
    this.reorderable = true,
  });

  final EpisodeEntry entry;
  final int index;
  final VoidCallback? onMore;
  final bool reorderable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final current = ref.watch(
      playerProvider.select((state) => state.episodeId == entry.episode.id),
    );
    final tap = _queueEntryTap(context, ref);
    return Material(
      color: current
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          children: [
            Expanded(
              child: reorderable
                  ? _QueueReorderHold(index: index, child: tap)
                  : tap,
            ),
            if (onMore != null)
              IconButton(
                tooltip: 'Actions',
                onPressed: onMore,
                icon: const MoreVertIcon(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _queueEntryTap(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preferPodcastCover = ref.watch(
      settingsProvider.select((settings) => settings.preferPodcastCover),
    );
    final density = ref.watch(
      settingsProvider.select((settings) => settings.episodeListDensity),
    );
    final timing = _episodeLineTiming(ref, entry.episode);
    final wide = _queueWide(context);
    return InkWell(
      onTap: () => ref.read(playerProvider.notifier).playOrPauseEntry(entry),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          wide ? 28 : 20,
          wide ? 10 : 6,
          8,
          wide ? 10 : 6,
        ),
        child: EpisodeLine(
          entry: entry,
          density: density,
          preferPodcastCover: preferPodcastCover,
          position: timing.$1,
          duration: timing.$2,
          coverSize: wide ? 64 : 48,
          titleStyle:
              (wide ? theme.textTheme.titleMedium : theme.textTheme.titleSmall)
                  ?.copyWith(fontWeight: FontWeight.w600),
          metaStyle: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

(Duration, Duration?) _episodeLineTiming(WidgetRef ref, Episode episode) {
  final playback = ref.watch(
    playerProvider.select((state) {
      if (state.episodeId != episode.id) return null;
      return (position: state.position, duration: state.duration);
    }),
  );
  final duration = playback != null && playback.duration > Duration.zero
      ? playback.duration
      : (episode.durationSeconds == null
            ? null
            : Duration(seconds: episode.durationSeconds!));
  final position =
      playback?.position ?? Duration(milliseconds: episode.positionMs);
  return (position, duration);
}
