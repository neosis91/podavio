import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';
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
  });

  final EpisodeQuery query;
  final Widget empty;
  final bool showPodcast;
  final Future<void> Function()? onRefresh;
  final void Function(List<EpisodeEntry> entries, int oldIndex, int newIndex)?
  reorder;

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
  });

  final EpisodeWindow window;
  final Widget empty;
  final bool showPodcast;
  final VoidCallback onLoadMore;
  final Future<void> Function()? onRefresh;
  final void Function(List<EpisodeEntry> entries, int oldIndex, int newIndex)?
  reorder;

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
      );
    }

    final list = reorder == null
        ? ListView.separated(
            physics: physics,
            addAutomaticKeepAlives: false,
            itemCount: itemCount,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => tile(index),
          )
        : ReorderableListView.builder(
            physics: physics,
            buildDefaultDragHandles: false,
            itemCount: entries.length,
            onReorderItem: (oldIndex, newIndex) =>
                reorder!(entries, oldIndex, newIndex),
            itemBuilder: (context, index) => EpisodeTile(
              key: ValueKey(entries[index].episode.id),
              entry: entries[index],
              showPodcast: showPodcast,
              reorderIndex: index,
            ),
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
