import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';
import '../../player/playback_source.dart';
import 'empty_state.dart';
import 'episode_tile.dart';

class EpisodeListBody extends ConsumerStatefulWidget {
  const EpisodeListBody({
    super.key,
    required this.query,
    required this.empty,
    this.showPodcast = true,
    this.onRefresh,
    this.reorder,
    this.highlightQuery = '',
    this.queueStyle = false,
    this.onRemove,
  });

  final EpisodeQuery query;
  final Widget empty;
  final bool showPodcast;
  final Future<void> Function()? onRefresh;
  final void Function(List<EpisodeEntry> entries, int oldIndex, int newIndex)?
  reorder;
  final String highlightQuery;
  final bool queueStyle;
  final void Function(EpisodeEntry entry)? onRemove;

  @override
  ConsumerState<EpisodeListBody> createState() => _EpisodeListBodyState();
}

class _EpisodeListBodyState extends ConsumerState<EpisodeListBody> {
  EpisodeWindow? _previous;

  @override
  Widget build(BuildContext context) {
    final next = ref.watch(episodesProvider(widget.query));
    final loaded = next.asData?.value;
    if (loaded != null) _previous = loaded;
    final window = loaded ?? _previous;

    if (window == null) {
      return next.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          title: 'Impossible de charger les épisodes',
          message: error.toString(),
        ),
        data: (_) => const SizedBox.shrink(),
      );
    }

    return _EpisodeWindowList(
      window: window,
      empty: widget.empty,
      showPodcast: widget.showPodcast,
      onRefresh: supportsPullToRefresh ? widget.onRefresh : null,
      reorder: widget.reorder,
      highlightQuery: widget.highlightQuery,
      queueStyle: widget.queueStyle,
      playbackSource: PlaybackSource.fromQuery(widget.query),
      onRemove: widget.onRemove,
      onLoadMore: () =>
          ref.read(episodesProvider(widget.query).notifier).loadMore(),
    );
  }
}

class _EpisodeWindowList extends StatelessWidget {
  const _EpisodeWindowList({
    required this.window,
    required this.empty,
    required this.showPodcast,
    required this.onLoadMore,
    this.onRefresh,
    this.reorder,
    this.highlightQuery = '',
    this.queueStyle = false,
    this.playbackSource,
    this.onRemove,
  });

  final EpisodeWindow window;
  final Widget empty;
  final bool showPodcast;
  final VoidCallback onLoadMore;
  final Future<void> Function()? onRefresh;
  final void Function(List<EpisodeEntry> entries, int oldIndex, int newIndex)?
  reorder;
  final String highlightQuery;
  final bool queueStyle;
  final PlaybackSource? playbackSource;
  final void Function(EpisodeEntry entry)? onRemove;

  @override
  Widget build(BuildContext context) {
    final entries = window.entries;
    if (entries.isEmpty) {
      if (onRefresh == null) return empty;
      return RefreshIndicator(
        onRefresh: onRefresh!,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: 420, child: empty)],
        ),
      );
    }

    final physics = onRefresh == null
        ? null
        : const AlwaysScrollableScrollPhysics();
    final itemCount = entries.length + (window.hasMore ? 1 : 0);
    Widget tile(int index) {
      if (index >= entries.length) return const _LoadMoreTile();
      final entry = entries[index];
      return EpisodeTile(
        key: ValueKey(entry.episode.id),
        entry: entry,
        showPodcast: showPodcast,
        highlightQuery: highlightQuery,
        queueStyle: queueStyle,
        playbackSource: playbackSource,
        onRemove: onRemove == null ? null : () => onRemove!(entry),
      );
    }

    final listPadding = queueStyle
        ? const EdgeInsets.only(top: 4, bottom: 24)
        : null;
    final list = reorder == null
        ? (queueStyle
              ? ListView.builder(
                  padding: listPadding,
                  physics: physics,
                  addAutomaticKeepAlives: false,
                  itemCount: itemCount,
                  itemBuilder: (context, index) => tile(index),
                )
              : ListView.separated(
                  physics: physics,
                  addAutomaticKeepAlives: false,
                  itemCount: itemCount,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => tile(index),
                ))
        : ReorderableListView.builder(
            padding: listPadding,
            physics: physics,
            buildDefaultDragHandles: false,
            proxyDecorator: queueStyle ? queueStyleDragProxy : null,
            itemCount: entries.length,
            onReorderItem: (oldIndex, newIndex) =>
                reorder!(entries, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return EpisodeTile(
                key: ValueKey(entry.episode.id),
                entry: entry,
                showPodcast: showPodcast,
                reorderIndex: index,
                highlightQuery: highlightQuery,
                queueStyle: queueStyle,
                playbackSource: playbackSource,
                onMoveUp: index == 0
                    ? null
                    : () => reorder!(entries, index, index - 1),
                onMoveDown: index >= entries.length - 1
                    ? null
                    : () => reorder!(entries, index, index + 1),
                onRemove: onRemove == null ? null : () => onRemove!(entry),
              );
            },
          );
    final scrollable = onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is! ScrollUpdateNotification &&
            notification is! ScrollEndNotification) {
          return false;
        }
        if (notification.metrics.extentAfter < 800) onLoadMore();
        return false;
      },
      child: scrollable,
    );
  }
}

Widget queueStyleDragProxy(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      final scheme = Theme.of(context).colorScheme;
      return Material(
        elevation: 8 * t,
        shadowColor: Colors.black45,
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: child,
      );
    },
    child: child,
  );
}

class _LoadMoreTile extends StatelessWidget {
  const _LoadMoreTile();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
