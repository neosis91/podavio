import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/status_notifications.dart';
import '../../player/playback_source.dart';
import '../../player/player_controller.dart';
import '../../settings/settings_controller.dart';
import '../router.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/brand.dart';
import '../widgets/empty_state.dart';
import '../widgets/episode_list.dart';
import '../widgets/frosted_header.dart';
import '../widgets/episode_tile.dart';
import '../widgets/list_metrics.dart';
import '../widgets/marquee_text.dart';
import '../widgets/messages.dart';
import 'cover_palette.dart';
import 'podcast_album_header.dart';

class PodcastPage extends ConsumerStatefulWidget {
  const PodcastPage({super.key, required this.podcastId});

  final int podcastId;

  @override
  ConsumerState<PodcastPage> createState() => _PodcastPageState();
}

class _PodcastPageState extends ConsumerState<PodcastPage> {
  EpisodeWindow? _previousEpisodes;
  var _selecting = false;
  final _selected = <int>{};
  final _scrollController = ScrollController();

  EpisodeQuery get _query => EpisodeQuery(podcastId: widget.podcastId);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMore() {
    ref.read(episodesProvider(_query).notifier).loadMore();
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
    _withScrollPinned(() {
      setState(() {
        _selecting = true;
        _selected
          ..clear()
          ..add(id);
      });
    });
  }

  void _exitSelection() {
    _withScrollPinned(() {
      setState(() {
        _selecting = false;
        _selected.clear();
      });
    });
  }

  void _toggle(int id) {
    _withScrollPinned(() {
      setState(() {
        if (!_selected.remove(id)) _selected.add(id);
        if (_selected.isEmpty) _selecting = false;
      });
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
    });
  }

  void _deselectAll() {
    setState(() => _selected.clear());
  }

  EpisodeSelectionSession? _selectionSession(EpisodeWindow? window) {
    if (!_selecting) return null;
    final entries = window?.entries ?? const <EpisodeEntry>[];
    final chosen = [
      for (final entry in entries)
        if (_selected.contains(entry.episode.id)) entry,
    ];
    return EpisodeSelectionSession(
      selectedCount: _selected.length,
      totalCount: entries.length,
      selected: chosen,
      onClose: _exitSelection,
      onSelectAll: () => _selectAll(entries),
      onDeselectAll: _deselectAll,
      bulkActions: const EpisodeBulkActions(favorite: true, download: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final podcast = ref.watch(podcastProvider(widget.podcastId));
    final episodes = ref.watch(episodesProvider(_query));
    final loaded = episodes.asData?.value;
    if (loaded != null) _previousEpisodes = loaded;
    final window = loaded ?? _previousEpisodes;
    return podcast.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => FrostedScaffold(
        appBar: FrostedAppBar(),
        body: EmptyState(
          title: 'Podcast introuvable',
          message: error.toString(),
        ),
      ),
      data: (item) {
        if (item == null) {
          return FrostedScaffold(
            appBar: FrostedAppBar(),
            body: const EmptyState(
              title: 'Podcast introuvable',
              message: 'Cet abonnement n’est plus dans la bibliothèque.',
            ),
          );
        }
        final background =
            ref
                .watch(
                  podcastCoverColorProvider(
                    coverColorToken(path: item.imagePath, url: item.imageUrl),
                  ),
                )
                .asData
                ?.value ??
            Colors.black;
        final playingHere = ref.watch(
          playerProvider.select(
            (state) =>
                state.podcastId == item.id && state.hasEpisode && state.playing,
          ),
        );
        final loadedHere = ref.watch(
          playerProvider.select(
            (state) => state.podcastId == item.id && state.hasEpisode,
          ),
        );
        final first = window?.entries.firstOrNull;
        final selection = _selectionSession(window);
        final selectingOverlay = Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;
        // Toujours la même structure Theme → Scaffold → body pour ne pas
        // démonter le CustomScrollView (sinon retour en haut de liste).
        final baseTheme = Theme.of(context);
        final pageColor = background;
        final immersiveScheme = ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Colors.white70,
          surface: pageColor,
          onSurface: Colors.white,
          onSurfaceVariant: Colors.white.withValues(alpha: 0.74),
          secondaryContainer: Colors.white.withValues(alpha: 0.18),
          onSecondaryContainer: Colors.white,
          primaryContainer: Colors.white.withValues(alpha: 0.16),
          onPrimaryContainer: Colors.white,
        );
        final appBarTheme = selection != null
            ? baseTheme.appBarTheme
            : const AppBarTheme(
                foregroundColor: Colors.white,
                iconTheme: IconThemeData(color: Colors.white),
                actionsIconTheme: IconThemeData(color: Colors.white),
              );
        final pageTheme = baseTheme.copyWith(
          brightness: Brightness.dark,
          colorScheme: selection != null
              ? baseTheme.colorScheme
              : immersiveScheme,
          scaffoldBackgroundColor: pageColor,
          appBarTheme: appBarTheme,
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: Colors.white,
          ),
          dividerColor: Colors.white24,
          listTileTheme: const ListTileThemeData(
            iconColor: Colors.white,
            textColor: Colors.white,
          ),
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: selection != null
              ? selectingOverlay
              : SystemUiOverlayStyle.light,
          child: Theme(
            data: pageTheme,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: background),
              duration: const Duration(milliseconds: 500),
              builder: (context, color, child) {
                return FrostedScaffold(
                  appBar: selection != null
                      ? EpisodeSelectionAppBar(session: selection)
                      : FrostedAppBar(
                          alwaysFrosted: true,
                          title: MarqueeText(
                            text: item.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          actions: _appBarActions(item),
                        ),
                  body: ColoredBox(color: color ?? Colors.black, child: child),
                );
              },
              child: PopScope(
                canPop: !_selecting,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop && _selecting) _exitSelection();
                },
                child: supportsPullToRefresh
                    ? RefreshIndicator(
                        color: Colors.white,
                        backgroundColor: background,
                        onRefresh: () => _refresh(context, ref, item.feedUrl),
                        child: _podcastScrollView(
                          item: item,
                          window: window,
                          episodes: episodes,
                          pullToRefresh: true,
                          background: background,
                          showPause: playingHere,
                          onPlay: first == null
                              ? null
                              : () => _play(ref, item, first, loadedHere),
                        ),
                      )
                    : _podcastScrollView(
                        item: item,
                        window: window,
                        episodes: episodes,
                        pullToRefresh: false,
                        background: background,
                        showPause: playingHere,
                        onPlay: first == null
                            ? null
                            : () => _play(ref, item, first, loadedHere),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _appBarActions(Podcast item) {
    return [
      if (item.subscribed)
        IconButton(
          tooltip: item.preferred
              ? 'Retirer des préférés'
              : 'Marquer comme préféré',
          onPressed: () => ref
              .read(databaseProvider)
              .setPodcastPreferred(item.id, preferred: !item.preferred),
          icon: PreferredStarIcon(
            selected: item.preferred,
            color: item.preferred ? preferredStarColor : Colors.white,
          ),
        ),
      IconButton(
        tooltip: 'Plus',
        onPressed: () => _showPodcastActions(item),
        icon: const Icon(Icons.more_vert, color: Colors.white),
      ),
    ];
  }

  void _showPodcastActions(Podcast item) {
    showAppModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Actualiser ce flux'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _refresh(context, ref, item.feedUrl);
                },
              ),
              if (item.subscribed)
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Paramètres'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(AppRoutes.podcastSettings(item.id));
                  },
                ),
              if (item.subscribed)
                ListTile(
                  leading: Icon(
                    item.autoDownload
                        ? Icons.download_done
                        : Icons.download_outlined,
                  ),
                  title: Text(
                    item.autoDownload
                        ? 'Désactiver les téléchargements automatiques'
                        : 'Activer les téléchargements automatiques',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref
                        .read(databaseProvider)
                        .setPodcastAutoDownload(
                          item.id,
                          autoDownload: !item.autoDownload,
                        );
                  },
                ),
              if (item.subscribed)
                ListTile(
                  leading: Icon(
                    item.keepUpdated ? Icons.sync_disabled : Icons.sync,
                  ),
                  title: Text(
                    item.keepUpdated
                        ? 'Ne plus maintenir à jour'
                        : 'Maintenir à jour',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref
                        .read(databaseProvider)
                        .setPodcastKeepUpdated(
                          item.id,
                          keepUpdated: !item.keepUpdated,
                        );
                  },
                ),
              ListTile(
                leading: Icon(
                  item.subscribed
                      ? Icons.person_remove_outlined
                      : Icons.delete_outline,
                ),
                title: Text(
                  item.subscribed ? 'Se désabonner' : 'Retirer l’aperçu',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _unsubscribe(context, ref, item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _play(WidgetRef ref, Podcast item, EpisodeEntry first, bool loadedHere) {
    if (loadedHere) {
      ref.read(playerProvider.notifier).toggle();
      return;
    }
    ref
        .read(playerProvider.notifier)
        .playOrPauseEntry(
          first,
          source: PlaybackSource.fromQuery(
            EpisodeQuery(podcastId: item.id, paginated: false),
          ),
        );
  }

  Widget _podcastScrollView({
    required Podcast item,
    required EpisodeWindow? window,
    required AsyncValue<EpisodeWindow> episodes,
    required bool pullToRefresh,
    required Color background,
    required bool showPause,
    required VoidCallback? onPlay,
  }) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        if (notification is! ScrollUpdateNotification &&
            notification is! ScrollEndNotification) {
          return false;
        }
        if (notification.metrics.extentAfter < 800) _loadMore();
        return false;
      },
      child: CustomScrollView(
        key: PageStorageKey<String>('podcast-scroll-${widget.podcastId}'),
        controller: _scrollController,
        physics: pullToRefresh ? const AlwaysScrollableScrollPhysics() : null,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: MediaQuery.viewPaddingOf(context).top + kToolbarHeight,
            ),
            sliver: SliverToBoxAdapter(
              child: PodcastAlbumHeader(
                podcast: item,
                showPause: showPause,
                onPlay: onPlay,
                onAbout: () => context.push(AppRoutes.podcastAbout(item.id)),
              ),
            ),
          ),
          ..._episodeSlivers(
            window: window,
            episodes: episodes,
            background: background,
          ),
        ],
      ),
    );
  }

  List<Widget> _episodeSlivers({
    required EpisodeWindow? window,
    required AsyncValue<EpisodeWindow> episodes,
    required Color background,
  }) {
    if (window == null) {
      return episodes.when(
        loading: () => [
          DecoratedSliver(
            decoration: BoxDecoration(color: background),
            sliver: const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
        ],
        error: (error, _) => [
          DecoratedSliver(
            decoration: BoxDecoration(color: background),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                title: 'Épisodes indisponibles',
                message: error.toString(),
              ),
            ),
          ),
        ],
        data: (_) => const [],
      );
    }
    if (window.entries.isEmpty) {
      return [
        DecoratedSliver(
          decoration: BoxDecoration(color: background),
          sliver: const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              title: 'Aucun épisode',
              message: 'Ce flux ne contient pas encore d’épisode audio.',
            ),
          ),
        ),
      ];
    }
    return _episodeListSlivers(window, background);
  }

  List<Widget> _episodeListSlivers(EpisodeWindow window, Color background) {
    final source = PlaybackSource(
      EpisodeQuery(podcastId: widget.podcastId, paginated: false),
    );
    return [
      DecoratedSliver(
        decoration: BoxDecoration(color: background),
        sliver: SliverPadding(
          padding: underChrome(
            context,
            const EdgeInsets.only(top: 4, bottom: 24),
          ),
          sliver: SliverList.builder(
            addAutomaticKeepAlives: false,
            itemCount: window.entries.length + (window.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= window.entries.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _loadMore();
                });
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }
              final entry = window.entries[index];
              final id = entry.episode.id;
              return EpisodeTile(
                key: ValueKey(id),
                entry: entry,
                queueStyle: true,
                showPodcast: false,
                playbackSource: source,
                selecting: _selecting,
                selected: _selected.contains(id),
                onLongPress: () => _enterSelection(id),
                onToggleSelect: () => _toggle(id),
              );
            },
          ),
        ),
      ),
    ];
  }

  Future<void> _refresh(
    BuildContext context,
    WidgetRef ref,
    String feedUrl,
  ) async {
    try {
      final saved = await ref.read(feedServiceProvider).refresh(feedUrl);
      final podcast = await ref
          .read(databaseProvider)
          .getPodcast(saved.podcastId);
      if (podcast != null &&
          shouldNotifyNewEpisodes(
            notifyNewEpisodes: ref.read(settingsProvider).notifyNewEpisodes,
            keepUpdated: podcast.keepUpdated,
            episodeNotification: podcast.episodeNotification,
            newCount: saved.newEpisodeIds.length,
          )) {
        await announceNewEpisodes(
          ref.read(statusNotificationsProvider),
          ref.read(settingsProvider),
          [
            NewEpisodeArrival(
              podcastId: podcast.id,
              title: podcast.title,
              count: saved.newEpisodeIds.length,
            ),
          ],
        );
      }
      if (context.mounted) showMessage(context, 'Flux actualisé');
    } catch (error) {
      if (context.mounted) showMessage(context, errorText(error));
    }
  }

  Future<void> _unsubscribe(
    BuildContext context,
    WidgetRef ref,
    Podcast item,
  ) async {
    final isPreview = !item.subscribed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPreview ? 'Retirer cet aperçu ?' : 'Se désabonner ?'),
        content: Text(
          isPreview
              ? '« ${item.title} » et ses épisodes seront retirés. Les fichiers téléchargés seront aussi supprimés.'
              : '« ${item.title} » et ses épisodes seront retirés de Podavio. Les fichiers téléchargés seront aussi supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isPreview ? 'Retirer' : 'Se désabonner'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final paths = await ref.read(databaseProvider).deletePodcast(item.id);
    await ref.read(downloadServiceProvider).deleteFiles(paths);
    if (context.mounted) Navigator.pop(context);
  }
}
