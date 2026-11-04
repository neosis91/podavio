import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/app_database.dart';
import '../../data/feed_service.dart';
import '../../data/providers.dart';
import '../../player/playback_source.dart';
import '../../player/player_controller.dart';
import '../../settings/settings_controller.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/brand.dart';
import '../widgets/empty_state.dart';
import '../widgets/episode_tile.dart';
import '../widgets/marquee_text.dart';
import '../widgets/playing_cover.dart';
import '../widgets/show_notes.dart';
import 'player_chapter.dart';
import 'player_panel.dart';

Future<void> showChaptersSheet({
  required BuildContext context,
  required WidgetRef ref,
  required int episodeId,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ChaptersSheet(episodeId: episodeId),
  );
}

class PlayerQueue extends ConsumerStatefulWidget {
  const PlayerQueue({
    super.key,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  @override
  ConsumerState<PlayerQueue> createState() => _PlayerQueueState();
}

class _PlayerQueueState extends ConsumerState<PlayerQueue> {
  final _scroll = ScrollController();
  final _nowPlayingKey = GlobalKey();
  List<int>? _orderIds;
  PlaybackSource? _orderSource;
  var _previousCount = 0;
  var _queueReady = false;
  var _revealed = false;
  var _revealScheduled = false;
  var _revealExtent = -1.0;
  var _loadingEarlier = false;
  var _pulling = false;
  var _pull = 0.0;
  var _jumping = false;

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

  /// En haut de la liste, glisser vers le bas ramène au grand lecteur.
  /// Le panneau suit le doigt, comme le lecteur lui-même.
  bool _onQueueScroll(ScrollNotification notification) {
    if (_jumping || notification.depth != 0) return false;
    if (notification is OverscrollNotification) {
      final details = notification.dragDetails;
      final atTop =
          notification.metrics.pixels <= notification.metrics.minScrollExtent;
      if (details != null && atTop && notification.overscroll < 0) {
        _followSheet(details, -notification.overscroll);
      }
    } else if (notification is ScrollUpdateNotification &&
        _pulling &&
        notification.dragDetails != null) {
      final details = notification.dragDetails!;
      final dy = details.primaryDelta ?? 0;
      if (dy < 0 && _pull > 0) {
        final back = math.min(_pull, -dy);
        _followSheet(details, -back);
        final pixels = notification.metrics.pixels;
        if (back > 0 && _scroll.hasClients) {
          final target = (pixels - back).clamp(
            0.0,
            _scroll.position.maxScrollExtent,
          );
          if (target != pixels) {
            _jumping = true;
            _scroll.jumpTo(target);
            _jumping = false;
          }
        }
      }
    } else if (notification is ScrollEndNotification && _pulling) {
      final end = notification.dragDetails;
      _pulling = false;
      _pull = 0;
      widget.onDragEnd(
        end ?? DragEndDetails(primaryVelocity: 0, velocity: Velocity.zero),
      );
    }
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

  void _followSheet(DragUpdateDetails details, double dy) {
    if (!_pulling) {
      _pulling = true;
      _pull = 0;
      widget.onDragStart(
        DragStartDetails(
          sourceTimeStamp: details.sourceTimeStamp,
          globalPosition: details.globalPosition,
          localPosition: details.localPosition,
        ),
      );
    }
    _pull = math.max(0, _pull + dy);
    widget.onDragUpdate(
      DragUpdateDetails(
        sourceTimeStamp: details.sourceTimeStamp,
        delta: Offset(0, dy),
        primaryDelta: dy,
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      ),
    );
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

String formatPlaybackSpeed(double speed) {
  final text = speed == speed.roundToDouble()
      ? speed.toInt().toString()
      : speed.toString();
  return '$text×';
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
              PlayingEpisodeCover(
                episodeId: entry.episode.id,
                label: entry.episode.title,
                colorKey: entry.podcast.title,
                url: entry.imageUrl(preferPodcastCover: preferPodcastCover),
                localPath: entry.imagePath(
                  preferPodcastCover: preferPodcastCover,
                ),
                httpHeaders: podcastAuthHeaders(
                  username: entry.podcast.authUsername,
                  password: entry.podcast.authPassword,
                ),
                size: _queueWide(context) ? 72 : 55,
                radius: 4,
              ),
              SizedBox(width: _queueWide(context) ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarqueeText(
                      text: entry.episode.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.podcast.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
    return InkWell(
      onTap: () => ref.read(playerProvider.notifier).playOrPauseEntry(entry),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _queueWide(context) ? 28 : 20,
          _queueWide(context) ? 10 : 6,
          8,
          _queueWide(context) ? 10 : 6,
        ),
        child: Row(
          children: [
            PlayingEpisodeCover(
              episodeId: entry.episode.id,
              label: entry.episode.title,
              colorKey: entry.podcast.title,
              url: entry.imageUrl(preferPodcastCover: preferPodcastCover),
              localPath: entry.imagePath(
                preferPodcastCover: preferPodcastCover,
              ),
              httpHeaders: podcastAuthHeaders(
                username: entry.podcast.authUsername,
                password: entry.podcast.authPassword,
              ),
              size: _queueWide(context) ? 64 : 48,
              radius: 4,
            ),
            SizedBox(width: _queueWide(context) ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarqueeText(
                    text: entry.episode.title,
                    style:
                        (_queueWide(context)
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.titleSmall)
                            ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  EpisodeListSubtitle(
                    entry: entry,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showNotesSheet({
  required BuildContext context,
  required int episodeId,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 1,
        minChildSize: 0.35,
        maxChildSize: 1,
        builder: (context, scrollController) {
          return Material(
            color:
                theme.bottomSheetTheme.backgroundColor ??
                scheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.paddingOf(context).top + 12),
                const SheetDragHandle(),
                Expanded(
                  child: _NotesSheet(
                    episodeId: episodeId,
                    scrollController: scrollController,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _NotesSheet extends ConsumerWidget {
  const _NotesSheet({required this.episodeId, required this.scrollController});

  final int episodeId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notesAsync = ref.watch(episodeProvider(episodeId));
    final notes = notesAsync.asData?.value?.episode.description ?? '';
    final hasNotes = plainText(notes).isNotEmpty;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text('Notes', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (notesAsync.isLoading && !notesAsync.hasValue)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!hasNotes)
          Text(
            'Aucune note pour cet épisode.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          ShowNotes(html: notes, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

Future<void> choosePlaybackSpeed(BuildContext context, WidgetRef ref) {
  return showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _SpeedSheet(),
  );
}

class _SpeedSheet extends ConsumerWidget {
  const _SpeedSheet();

  static const _presets = [0.8, 1.0, 1.2, 1.5, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(playerProvider.select((state) => state.speed));
    final episodeId = ref.watch(
      playerProvider.select((state) => state.episodeId),
    );
    final hasOverride = episodeId == null
        ? false
        : ref
                  .watch(episodeProvider(episodeId))
                  .asData
                  ?.value
                  ?.podcast
                  .playbackSpeed !=
              null;
    final theme = Theme.of(context);
    final sliderValue = speed.clamp(0.5, 3.0);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Vitesse', style: theme.textTheme.titleMedium),
            if (hasOverride) ...[
              const SizedBox(height: 4),
              Text(
                'Pour ce podcast',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: sliderValue,
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    label: formatPlaybackSpeed(sliderValue),
                    onChanged: (value) {
                      unawaited(
                        ref.read(playerProvider.notifier).setSpeed(value),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    formatPlaybackSpeed(sliderValue),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ChoiceChip(
                    label: Text(formatPlaybackSpeed(preset)),
                    selected: (speed - preset).abs() < 0.05,
                    onSelected: (_) {
                      unawaited(
                        ref.read(playerProvider.notifier).setSpeed(preset),
                      );
                    },
                  ),
              ],
            ),
            if (hasOverride) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    unawaited(
                      ref.read(playerProvider.notifier).resetPodcastSpeed(),
                    );
                  },
                  child: const Text('Réinitialiser'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> chooseSleepTimer(BuildContext context, WidgetRef ref) async {
  final choice = await showAppModalBottomSheet<_SleepChoice>(
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

class _ChaptersSheet extends ConsumerStatefulWidget {
  const _ChaptersSheet({required this.episodeId});

  final int episodeId;

  @override
  ConsumerState<_ChaptersSheet> createState() => _ChaptersSheetState();
}

class _ChaptersSheetState extends ConsumerState<_ChaptersSheet> {
  final _itemKeys = <int, GlobalKey>{};
  int? _lastScrolledChapterId;
  int? _pendingScrollId;

  GlobalKey _keyFor(int chapterId) =>
      _itemKeys.putIfAbsent(chapterId, GlobalKey.new);

  void _scrollToActive(EpisodeChapter? active, {required bool animate}) {
    if (active == null) return;
    if (_lastScrolledChapterId == active.id) return;
    if (_pendingScrollId == active.id) return;
    _pendingScrollId = active.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScrollId = null;
      if (!mounted) return;
      final ctx = _itemKeys[active.id]?.currentContext;
      if (ctx == null) return;
      _lastScrolledChapterId = active.id;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final episodeId = widget.episodeId;
    final chapters =
        ref.watch(chaptersProvider(episodeId)).value ??
        const <EpisodeChapter>[];
    final loadAsync = ref.watch(chaptersLoadStateProvider(episodeId));
    final episode = ref.watch(episodeProvider(episodeId)).value?.episode;
    final chaptersUrl = episode?.chaptersUrl?.trim() ?? '';
    final fetched = episode?.chaptersFetched ?? false;
    final position = ref.watch(playerProvider.select((s) => s.position));
    final active = currentChapterFor(chapters, position);
    final height = MediaQuery.sizeOf(context).height * 0.55;

    final phase = loadAsync.asData?.value;
    final pendingFetch = chaptersUrl.isNotEmpty && !fetched;
    final showLoading =
        chapters.isEmpty &&
        (loadAsync.isLoading ||
            (pendingFetch && phase != ChaptersLoadPhase.failed));
    final showError = chapters.isEmpty && phase == ChaptersLoadPhase.failed;

    if (chapters.isNotEmpty) {
      _scrollToActive(active, animate: _lastScrolledChapterId != null);
    }

    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final Widget body;
    if (showLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (showError) {
      body = Center(
        child: Text(
          'Impossible de charger les chapitres.',
          style: muted,
          textAlign: TextAlign.center,
        ),
      );
    } else if (chapters.isEmpty) {
      body = Center(
        child: Text(
          'Aucun chapitre pour cet épisode.',
          style: muted,
          textAlign: TextAlign.center,
        ),
      );
    } else {
      body = ListView(
        children: [
          for (var index = 0; index < chapters.length; index++)
            _chapterTile(
              theme: theme,
              chapter: chapters[index],
              index: index,
              selected: chapters[index].id == active?.id,
            ),
        ],
      );
    }

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
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _chapterTile({
    required ThemeData theme,
    required EpisodeChapter chapter,
    required int index,
    required bool selected,
  }) {
    final start = Duration(milliseconds: chapter.startMs);
    return ListTile(
      key: _keyFor(chapter.id),
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
        chapter.title.isEmpty ? 'Chapitre ${index + 1}' : chapter.title,
      ),
      onTap: () {
        Navigator.pop(context);
        ref.read(playerProvider.notifier).seek(start);
      },
    );
  }
}
