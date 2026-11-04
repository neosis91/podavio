import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';
import '../../data/app_database.dart';
import '../../data/download_controller.dart';
import '../../data/download_service.dart';
import '../../data/providers.dart';
import '../../player/playback_source.dart';
import 'app_bottom_sheet.dart';
import 'brand.dart';
import 'empty_state.dart';
import 'episode_tile.dart';
import 'frosted_header.dart';
import 'messages.dart';

/// Actions groupées disponibles en sélection multiple.
///
/// Si [hasAny] est faux, la sélection multiple est désactivée sur la liste.
class EpisodeBulkActions {
  const EpisodeBulkActions({
    this.onRemove,
    this.removeLabel = 'Supprimer',
    this.favorite = false,
    this.download = false,
  });

  static const none = EpisodeBulkActions();

  final Future<void> Function(List<EpisodeEntry> entries)? onRemove;
  final String removeLabel;

  /// Ajouter / retirer des favoris selon l’état de la sélection.
  final bool favorite;

  /// Télécharger / supprimer les téléchargements selon l’état de la sélection.
  final bool download;

  bool get hasAny => onRemove != null || favorite || download;
}

class EpisodeSelectionSession {
  const EpisodeSelectionSession({
    required this.selectedCount,
    required this.totalCount,
    required this.selected,
    required this.onClose,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.bulkActions,
  });

  final int selectedCount;
  final int totalCount;
  final List<EpisodeEntry> selected;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final EpisodeBulkActions bulkActions;

  bool get allSelected => totalCount > 0 && selectedCount >= totalCount;
}

/// App bar givré qui remplace le header pendant la sélection.
class EpisodeSelectionAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  const EpisodeSelectionAppBar({super.key, required this.session});

  final EpisodeSelectionSession session;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = session.selected;
    final actions = session.bulkActions;
    final canAct = selected.isNotEmpty && actions.hasAny;
    return FrostedAppBar(
      alwaysFrosted: true,
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Annuler',
        onPressed: session.onClose,
        icon: const Icon(Icons.close),
      ),
      title: Text(
        session.selectedCount == 0
            ? 'Sélection'
            : session.selectedCount == 1
            ? '1 sélectionné'
            : '${session.selectedCount} sélectionnés',
      ),
      actions: [
        if (session.allSelected)
          IconButton(
            tooltip: 'Tout désélectionner',
            onPressed: session.onDeselectAll,
            icon: const DeselectAllIcon(),
          )
        else
          IconButton(
            tooltip: 'Tout sélectionner',
            onPressed: session.onSelectAll,
            icon: const SelectAllIcon(),
          ),
        if (canAct)
          IconButton(
            tooltip: 'Actions',
            onPressed: () => _showBulkActionsSheet(context, ref),
            icon: const MoreVertIcon(),
          ),
      ],
    );
  }

  void _showBulkActionsSheet(BuildContext context, WidgetRef ref) {
    final selected = session.selected;
    final actions = session.bulkActions;
    final allFavorite =
        actions.favorite && selected.every((e) => e.episode.favorite);
    final allDownloaded =
        actions.download &&
        selected.every((e) => e.episode.downloadPath != null);
    final anyUnplayed = selected.any((e) => !e.episode.played);
    final anyPlayed = selected.any((e) => e.episode.played);
    showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (anyUnplayed)
                ListTile(
                  leading: const Icon(Icons.done_all),
                  title: const Text('Marquer comme lu'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _runBulkAction(context, ref, _BulkMenuAction.markPlayed);
                  },
                ),
              if (anyPlayed)
                ListTile(
                  leading: const Icon(Icons.unpublished_outlined),
                  title: const Text('Marquer comme non lu'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _runBulkAction(context, ref, _BulkMenuAction.markUnplayed);
                  },
                ),
              if (actions.favorite)
                ListTile(
                  leading: Icon(
                    allFavorite ? Icons.favorite : Icons.favorite_border,
                    color: allFavorite ? favoriteHeartColor : null,
                  ),
                  title: Text(
                    allFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _runBulkAction(
                      context,
                      ref,
                      allFavorite
                          ? _BulkMenuAction.unfavorite
                          : _BulkMenuAction.favorite,
                    );
                  },
                ),
              if (actions.download)
                ListTile(
                  leading: Icon(
                    allDownloaded
                        ? Icons.delete_outline
                        : Icons.download_outlined,
                  ),
                  title: Text(
                    allDownloaded
                        ? 'Supprimer les téléchargements'
                        : 'Télécharger',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _runBulkAction(
                      context,
                      ref,
                      allDownloaded
                          ? _BulkMenuAction.removeDownload
                          : _BulkMenuAction.download,
                    );
                  },
                ),
              if (actions.onRemove != null)
                ListTile(
                  leading: const RemoveSelectionIcon(),
                  title: Text(actions.removeLabel),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _runBulkAction(context, ref, _BulkMenuAction.remove);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runBulkAction(
    BuildContext context,
    WidgetRef ref,
    _BulkMenuAction action,
  ) async {
    final selected = session.selected;
    if (selected.isEmpty) return;
    try {
      switch (action) {
        case _BulkMenuAction.markPlayed:
          final database = ref.read(databaseProvider);
          for (final entry in selected) {
            if (!entry.episode.played) {
              await database.setPlayed(entry.episode.id, played: true);
            }
          }
        case _BulkMenuAction.markUnplayed:
          final database = ref.read(databaseProvider);
          for (final entry in selected) {
            if (entry.episode.played) {
              await database.setPlayed(entry.episode.id, played: false);
            }
          }
        case _BulkMenuAction.favorite:
          final database = ref.read(databaseProvider);
          for (final entry in selected) {
            if (!entry.episode.favorite) {
              await database.setFavorite(entry.episode.id, favorite: true);
            }
          }
        case _BulkMenuAction.unfavorite:
          final database = ref.read(databaseProvider);
          for (final entry in selected) {
            if (entry.episode.favorite) {
              await database.setFavorite(entry.episode.id, favorite: false);
            }
          }
        case _BulkMenuAction.download:
          final downloads = ref.read(downloadProgressProvider.notifier);
          final inFlight = ref.read(downloadProgressProvider);
          var started = 0;
          for (final entry in selected) {
            final episode = entry.episode;
            if (episode.downloadPath != null) continue;
            if (inFlight.containsKey(episode.id)) continue;
            started++;
            // Lancement parallèle : l’anneau autour de chaque pochette
            // (style mini-lecteur) affiche la progression.
            unawaited(() async {
              try {
                await downloads.download(episode);
              } on DownloadCancelled {
                return;
              } catch (_) {
                // Erreur déjà notifiée par le contrôleur de téléchargement.
              }
            }());
          }
          if (context.mounted) {
            showMessage(
              context,
              started == 0
                  ? 'Aucun téléchargement à lancer'
                  : started == 1
                  ? 'Téléchargement lancé'
                  : '$started téléchargements lancés',
            );
          }
        case _BulkMenuAction.removeDownload:
          final downloads = ref.read(downloadProgressProvider.notifier);
          for (final entry in selected) {
            if (entry.episode.downloadPath != null) {
              await downloads.deleteDownload(entry.episode);
            }
          }
          if (context.mounted) {
            showMessage(context, 'Téléchargements supprimés');
          }
        case _BulkMenuAction.remove:
          final remove = session.bulkActions.onRemove;
          if (remove != null) await remove(selected);
      }
    } on DownloadCancelled {
      return;
    } catch (error) {
      if (context.mounted) showMessage(context, errorText(error));
      return;
    }
    if (context.mounted) session.onClose();
  }
}

enum _BulkMenuAction {
  markPlayed,
  markUnplayed,
  favorite,
  unfavorite,
  download,
  removeDownload,
  remove,
}

/// Scaffold liste + app bar, avec remplacement givré en mode sélection.
class EpisodeListScaffold extends ConsumerStatefulWidget {
  const EpisodeListScaffold({
    super.key,
    required this.title,
    required this.query,
    required this.empty,
    this.actions,
    this.leading,
    this.bulkActions = EpisodeBulkActions.none,
    this.onRemove,
    this.reorder,
    this.queueStyle = true,
    this.highlightQuery = '',
    this.onRefresh,
    this.showPodcast = true,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final EpisodeQuery query;
  final Widget empty;
  final EpisodeBulkActions bulkActions;
  final void Function(EpisodeEntry entry)? onRemove;
  final void Function(List<EpisodeEntry> entries, int oldIndex, int newIndex)?
  reorder;
  final bool queueStyle;
  final String highlightQuery;
  final Future<void> Function()? onRefresh;
  final bool showPodcast;

  @override
  ConsumerState<EpisodeListScaffold> createState() =>
      _EpisodeListScaffoldState();
}

class _EpisodeListScaffoldState extends ConsumerState<EpisodeListScaffold> {
  EpisodeSelectionSession? _selection;

  @override
  Widget build(BuildContext context) {
    return FrostedScaffold(
      appBar: _selection != null
          ? EpisodeSelectionAppBar(session: _selection!)
          : FrostedAppBar(
              title: widget.title,
              leading: widget.leading,
              actions: widget.actions,
            ),
      body: EpisodeListBody(
        query: widget.query,
        empty: widget.empty,
        showPodcast: widget.showPodcast,
        onRefresh: widget.onRefresh,
        reorder: widget.reorder,
        highlightQuery: widget.highlightQuery,
        queueStyle: widget.queueStyle,
        onRemove: widget.onRemove,
        bulkActions: widget.bulkActions,
        onSelectionChanged: (session) {
          if (!mounted) return;
          setState(() => _selection = session);
        },
      ),
    );
  }
}

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
    this.bulkActions = EpisodeBulkActions.none,
    this.onSelectionChanged,
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
  final EpisodeBulkActions bulkActions;
  final ValueChanged<EpisodeSelectionSession?>? onSelectionChanged;

  @override
  ConsumerState<EpisodeListBody> createState() => _EpisodeListBodyState();
}

class _EpisodeListBodyState extends ConsumerState<EpisodeListBody> {
  EpisodeWindow? _previous;
  var _selecting = false;
  final _selected = <int>{};
  final _scrollController = ScrollController();

  bool get _canSelect => widget.bulkActions.hasAny;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EpisodeListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canSelect && _selecting) {
      _exitSelection();
    }
  }

  void _publish() {
    final cb = widget.onSelectionChanged;
    if (cb == null) return;
    if (!_selecting) {
      cb(null);
      return;
    }
    final entries = _previous?.entries ?? const <EpisodeEntry>[];
    final chosen = [
      for (final entry in entries)
        if (_selected.contains(entry.episode.id)) entry,
    ];
    cb(
      EpisodeSelectionSession(
        selectedCount: _selected.length,
        totalCount: entries.length,
        selected: chosen,
        onClose: _exitSelection,
        onSelectAll: () => _selectAll(entries),
        onDeselectAll: _deselectAll,
        bulkActions: widget.bulkActions,
      ),
    );
  }

  void _withScrollPinned(VoidCallback update) {
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : null;
    update();
    if (offset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(offset.clamp(0.0, max));
    });
  }

  void _enterSelection(int id) {
    if (!_canSelect) return;
    _withScrollPinned(() {
      setState(() {
        _selecting = true;
        _selected
          ..clear()
          ..add(id);
      });
      _publish();
    });
  }

  void _exitSelection() {
    _withScrollPinned(() {
      setState(() {
        _selecting = false;
        _selected.clear();
      });
      _publish();
    });
  }

  void _toggle(int id) {
    _withScrollPinned(() {
      setState(() {
        if (!_selected.remove(id)) _selected.add(id);
        if (_selected.isEmpty) _selecting = false;
      });
      _publish();
    });
  }

  void _selectAll(List<EpisodeEntry> entries) {
    _withScrollPinned(() {
      setState(() {
        _selecting = true;
        _selected
          ..clear()
          ..addAll(entries.map((entry) => entry.episode.id));
      });
      _publish();
    });
  }

  void _deselectAll() {
    setState(() => _selected.clear());
    _publish();
  }

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

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _exitSelection();
      },
      child: _EpisodeWindowList(
        window: window,
        empty: widget.empty,
        showPodcast: widget.showPodcast,
        onRefresh: supportsPullToRefresh ? widget.onRefresh : null,
        // Garder le même type de liste (Reorderable ou non) pour ne pas
        // réinitialiser la position de scroll à l’entrée en sélection.
        reorder: widget.reorder,
        highlightQuery: widget.highlightQuery,
        queueStyle: widget.queueStyle,
        playbackSource: PlaybackSource.fromQuery(widget.query),
        onRemove: widget.onRemove,
        selecting: _selecting,
        selectedIds: _selected,
        onLongPress: _canSelect ? _enterSelection : null,
        onToggleSelect: _toggle,
        scrollController: _scrollController,
        onLoadMore: () =>
            ref.read(episodesProvider(widget.query).notifier).loadMore(),
      ),
    );
  }
}

class _EpisodeWindowList extends StatelessWidget {
  const _EpisodeWindowList({
    required this.window,
    required this.empty,
    required this.showPodcast,
    required this.onLoadMore,
    required this.selecting,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.scrollController,
    this.onLongPress,
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
  final bool selecting;
  final Set<int> selectedIds;
  final ValueChanged<int>? onLongPress;
  final ValueChanged<int> onToggleSelect;
  final ScrollController scrollController;
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
      return FrostedRefreshIndicator(
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
      final id = entry.episode.id;
      return EpisodeTile(
        key: ValueKey(id),
        entry: entry,
        showPodcast: showPodcast,
        highlightQuery: highlightQuery,
        queueStyle: queueStyle,
        playbackSource: playbackSource,
        onRemove: onRemove == null ? null : () => onRemove!(entry),
        selecting: selecting,
        selected: selectedIds.contains(id),
        onLongPress: onLongPress == null ? null : () => onLongPress!(id),
        onToggleSelect: () => onToggleSelect(id),
      );
    }

    final listPadding = queueStyle
        ? belowFrostedBar(context, const EdgeInsets.only(top: 4, bottom: 24))
        : null;
    final list = reorder == null
        ? (queueStyle
              ? ListView.builder(
                  key: const PageStorageKey<String>('episode-list'),
                  controller: scrollController,
                  padding: listPadding,
                  physics: physics,
                  addAutomaticKeepAlives: false,
                  itemCount: itemCount,
                  itemBuilder: (context, index) => tile(index),
                )
              : ListView.separated(
                  key: const PageStorageKey<String>('episode-list-sep'),
                  controller: scrollController,
                  physics: physics,
                  addAutomaticKeepAlives: false,
                  itemCount: itemCount,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => tile(index),
                ))
        : ReorderableListView.builder(
            key: const PageStorageKey<String>('episode-list-reorder'),
            scrollController: scrollController,
            padding: listPadding,
            physics: physics,
            buildDefaultDragHandles: false,
            proxyDecorator: queueStyle ? queueStyleDragProxy : null,
            itemCount: entries.length,
            onReorderItem: selecting
                ? (oldIndex, newIndex) {}
                : (oldIndex, newIndex) => reorder!(entries, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final id = entry.episode.id;
              return EpisodeTile(
                key: ValueKey(id),
                entry: entry,
                showPodcast: showPodcast,
                reorderIndex: selecting ? null : index,
                highlightQuery: highlightQuery,
                queueStyle: queueStyle,
                playbackSource: playbackSource,
                onMoveUp: selecting || index == 0
                    ? null
                    : () => reorder!(entries, index, index - 1),
                onMoveDown: selecting || index >= entries.length - 1
                    ? null
                    : () => reorder!(entries, index, index + 1),
                onRemove: onRemove == null ? null : () => onRemove!(entry),
                selecting: selecting,
                selected: selectedIds.contains(id),
                onLongPress: onLongPress == null
                    ? null
                    : () => onLongPress!(id),
                onToggleSelect: () => onToggleSelect(id),
              );
            },
          );
    final scrollable = onRefresh == null
        ? list
        : FrostedRefreshIndicator(onRefresh: onRefresh!, child: list);
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
