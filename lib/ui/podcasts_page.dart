import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_database.dart';
import '../data/feed_refresh_controller.dart';
import '../data/providers.dart';
import '../settings/settings_controller.dart';
import '../core/platform.dart';
import 'episodes_page.dart';
import 'router.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/highlighted_text.dart';
import 'widgets/messages.dart';

/// Compteurs jaquettes / tri Compteur / filtre « supérieur à zéro ».
/// Si Compteur = aucun : map vide sauf besoin tri/filtre → non lus.
final podcastCounterCountsProvider = StreamProvider<Map<int, int>>((ref) {
  final mode = ref.watch(settingsProvider.select((s) => s.podcastCounter));
  final sort = ref.watch(settingsProvider.select((s) => s.podcastSort));
  final counterAboveZero = ref.watch(
    settingsProvider.select((s) => s.podcastFilters.counterAboveZero),
  );
  final forBadge = mode != PodcastCounter.none;
  final forMetric = sort == PodcastSort.counter || counterAboveZero;
  if (!forBadge && !forMetric) {
    return Stream.value(const <int, int>{});
  }

  final database = ref.watch(databaseProvider);
  final queryMode = mode == PodcastCounter.none ? PodcastCounter.unread : mode;
  return switch (queryMode) {
    PodcastCounter.none => Stream.value(const <int, int>{}),
    PodcastCounter.unread => database.watchEpisodeCountsByPodcast(
      unreadOnly: true,
    ),
    PodcastCounter.downloaded => database.watchEpisodeCountsByPodcast(
      downloadsOnly: true,
    ),
    PodcastCounter.downloadedUnread => database.watchEpisodeCountsByPodcast(
      unreadOnly: true,
      downloadsOnly: true,
    ),
    PodcastCounter.queue => database.watchEpisodeCountsByPodcast(
      queuedOnly: true,
    ),
  };
});

/// Épisodes lus par podcast (uniquement si tri « Nombre lus »).
final podcastPlayedCountsProvider = StreamProvider<Map<int, int>>((ref) {
  final sort = ref.watch(settingsProvider.select((s) => s.podcastSort));
  if (sort != PodcastSort.played) {
    return Stream.value(const <int, int>{});
  }
  return ref.watch(databaseProvider).watchEpisodeCountsByPodcast(
    playedOnly: true,
  );
});

class PodcastsPage extends ConsumerStatefulWidget {
  const PodcastsPage({super.key});

  @override
  ConsumerState<PodcastsPage> createState() => _PodcastsPageState();
}

class _PodcastsPageState extends ConsumerState<PodcastsPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  var _searching = false;
  var _query = '';
  Map<int, int> _lastCounterCounts = const {};
  Map<int, int> _lastPlayedCounts = const {};

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final podcasts = ref.watch(podcastsProvider);
    final podcastList = ref.watch(
      settingsProvider.select((s) => s.podcastList),
    );
    final podcastColumns = ref.watch(
      settingsProvider.select((s) => s.podcastColumns),
    );
    final showNames = ref.watch(
      settingsProvider.select((s) => s.podcastShowNames),
    );
    final counter = ref.watch(
      settingsProvider.select((s) => s.podcastCounter),
    );
    final sort = ref.watch(settingsProvider.select((s) => s.podcastSort));
    final filters = ref.watch(
      settingsProvider.select((s) => s.podcastFilters),
    );
    final refreshing = ref.watch(
      feedRefreshProvider.select((s) => s.isRunning),
    );
    final maxColumns = maxPodcastColumnsFor(MediaQuery.sizeOf(context).width);
    final columns = podcastList ? 1 : podcastColumns.clamp(1, maxColumns);

    final counterAsync = ref.watch(podcastCounterCountsProvider);
    final playedAsync = ref.watch(podcastPlayedCountsProvider);
    ref.listen(podcastCounterCountsProvider, (_, next) {
      next.whenData((value) => _lastCounterCounts = value);
    });
    ref.listen(podcastPlayedCountsProvider, (_, next) {
      next.whenData((value) => _lastPlayedCounts = value);
    });
    final counterCounts = counterAsync.value ?? _lastCounterCounts;
    final playedCounts = playedAsync.value ?? _lastPlayedCounts;
    final showBadges = counter != PodcastCounter.none;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un abonnement',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
              )
            : const Text('Abonnements'),
        leading: _searching
            ? IconButton(
                tooltip: 'Fermer la recherche',
                onPressed: _closeSearch,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          if (_searching)
            IconButton(
              tooltip: 'Effacer',
              onPressed: _query.isEmpty
                  ? _closeSearch
                  : () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
              icon: const Icon(Icons.close),
            )
          else ...[
            IconButton(
              tooltip: 'Rechercher',
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
            ),
            PopupMenuButton<int>(
              tooltip: 'Affichage',
              icon: Icon(podcastList ? Icons.view_list : Icons.grid_view),
              onSelected: (value) => ref
                  .read(settingsProvider.notifier)
                  .setPodcastLayout(
                    list: value == 0,
                    columns: value == 0 ? null : value,
                  ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 0,
                  child: Row(
                    children: [
                      const Expanded(child: Text('Liste')),
                      if (podcastList) const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
                for (var count = 1; count <= maxColumns; count++)
                  PopupMenuItem(
                    value: count,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$count ${count == 1 ? 'colonne' : 'colonnes'}',
                          ),
                        ),
                        if (!podcastList && count == columns)
                          const Icon(Icons.check, size: 18),
                      ],
                    ),
                  ),
              ],
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'refresh':
                    refreshSubscriptions(context, ref);
                  case 'counter':
                    _showCounterDialog(context, ref);
                  case 'filter':
                    _showFilterDialog(context, ref);
                  case 'sort':
                    _showSortDialog(context, ref);
                  case 'showNames':
                    ref
                        .read(settingsProvider.notifier)
                        .setPodcastShowNames(!showNames);
                }
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'showNames',
                  checked: showNames,
                  child: const Text('Afficher les noms'),
                ),
                const PopupMenuItem(
                  value: 'counter',
                  child: Text('Compteur'),
                ),
                const PopupMenuItem(
                  value: 'filter',
                  child: Text('Filtrer'),
                ),
                const PopupMenuItem(
                  value: 'sort',
                  child: Text('Trier'),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  enabled: !refreshing,
                  child: Text(
                    refreshing
                        ? 'Actualisation en cours…'
                        : 'Actualiser les abonnements',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!filters.isEmpty)
            _ActiveFiltersBar(
              filters: filters,
              onEdit: () => _showFilterDialog(context, ref),
              onChanged: (next) =>
                  ref.read(settingsProvider.notifier).setPodcastFilters(next),
            ),
          Expanded(
            child: podcasts.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                title: 'Abonnements indisponibles',
                message: error.toString(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    title: 'Aucun abonnement',
                    message: 'Cherchez un podcast dans Explorer.',
                    action: FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.discover),
                      icon: const Icon(Icons.explore),
                      label: const Text('Explorer'),
                    ),
                  );
                }

                final needle = _query.trim().toLowerCase();
                final searched = needle.isEmpty
                    ? items
                    : items
                          .where(
                            (p) => p.title.toLowerCase().contains(needle),
                          )
                          .toList();

                final filtered = _filterPodcasts(
                  searched,
                  filters: filters,
                  counterCounts: filters.counterAboveZero
                      ? counterCounts
                      : const {},
                );

                if (filtered.isEmpty) {
                  final hasSearch = needle.isNotEmpty;
                  final hasFilters = !filters.isEmpty;
                  return EmptyState(
                    title: 'Aucun résultat',
                    message: hasSearch && !hasFilters
                        ? 'Aucun abonnement ne correspond à « ${_query.trim()} ».'
                        : hasSearch && hasFilters
                        ? 'Aucun abonnement ne correspond à la recherche et aux filtres.'
                        : 'Aucun abonnement ne correspond aux filtres.',
                    action: TextButton(
                      onPressed: () {
                        if (hasSearch) _closeSearch();
                        if (hasFilters) {
                          ref
                              .read(settingsProvider.notifier)
                              .setPodcastFilters(PodcastFilters.empty);
                        }
                      },
                      child: Text(
                        hasSearch && hasFilters
                            ? 'Effacer recherche et filtres'
                            : hasSearch
                            ? 'Effacer la recherche'
                            : 'Effacer les filtres',
                      ),
                    ),
                  );
                }

                final visible = _sortPodcasts(
                  filtered,
                  sort: sort,
                  counterCounts: counterCounts,
                  playedCounts: playedCounts,
                );

                final child = podcastList
                    ? ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final podcast = visible[index];
                          return _PodcastListTile(
                            key: ValueKey(podcast.id),
                            podcast: podcast,
                            showName: showNames || needle.isNotEmpty,
                            highlightQuery: needle,
                            count: showBadges
                                ? (counterCounts[podcast.id] ?? 0)
                                : 0,
                          );
                        },
                      )
                    : _PodcastGrid(
                        items: visible,
                        columns: columns,
                        showNames: showNames || needle.isNotEmpty,
                        highlightQuery: needle,
                        counts: showBadges ? counterCounts : const {},
                      );
                if (refreshing || !supportsPullToRefresh) return child;
                return RefreshIndicator(
                  onRefresh: () => refreshSubscriptions(context, ref),
                  child: child,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveFiltersBar extends StatelessWidget {
  const _ActiveFiltersBar({
    required this.filters,
    required this.onEdit,
    required this.onChanged,
  });

  final PodcastFilters filters;
  final VoidCallback onEdit;
  final ValueChanged<PodcastFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = <Widget>[
      if (filters.counterAboveZero)
        InputChip(
          label: const Text('Compteur > 0'),
          onPressed: onEdit,
          onDeleted: () =>
              onChanged(filters.copyWith(counterAboveZero: false)),
        ),
      if (filters.autoDownload == true)
        InputChip(
          label: const Text('Téléchargements auto'),
          onPressed: onEdit,
          onDeleted: () =>
              onChanged(filters.copyWith(clearAutoDownload: true)),
        ),
      if (filters.autoDownload == false)
        InputChip(
          label: const Text('Sans téléchargements auto'),
          onPressed: onEdit,
          onDeleted: () =>
              onChanged(filters.copyWith(clearAutoDownload: true)),
        ),
      if (filters.keepUpdated == true)
        InputChip(
          label: const Text('Maintenu à jour'),
          onPressed: onEdit,
          onDeleted: () =>
              onChanged(filters.copyWith(clearKeepUpdated: true)),
        ),
      if (filters.keepUpdated == false)
        InputChip(
          label: const Text('Non maintenu à jour'),
          onPressed: onEdit,
          onDeleted: () =>
              onChanged(filters.copyWith(clearKeepUpdated: true)),
        ),
      ActionChip(
        avatar: Icon(Icons.clear_all, size: 18, color: scheme.primary),
        label: const Text('Tout effacer'),
        onPressed: () => onChanged(PodcastFilters.empty),
      ),
    ];

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => chips[index],
        ),
      ),
    );
  }
}

List<Podcast> _filterPodcasts(
  List<Podcast> items, {
  required PodcastFilters filters,
  required Map<int, int> counterCounts,
}) {
  if (filters.isEmpty) return items;
  return items.where((podcast) {
    if (filters.counterAboveZero && (counterCounts[podcast.id] ?? 0) <= 0) {
      return false;
    }
    if (filters.autoDownload != null &&
        podcast.autoDownload != filters.autoDownload) {
      return false;
    }
    if (filters.keepUpdated != null &&
        podcast.keepUpdated != filters.keepUpdated) {
      return false;
    }
    return true;
  }).toList();
}

List<Podcast> _sortPodcasts(
  List<Podcast> items, {
  required PodcastSort sort,
  required Map<int, int> counterCounts,
  required Map<int, int> playedCounts,
}) {
  final sorted = List<Podcast>.of(items);
  int byTitle(Podcast a, Podcast b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  switch (sort) {
    case PodcastSort.published:
      // Déjà trié par date du dernier épisode via watchPodcasts().
      return sorted;
    case PodcastSort.alphabetical:
      sorted.sort(byTitle);
    case PodcastSort.counter:
      sorted.sort((a, b) {
        final cmp = (counterCounts[b.id] ?? 0).compareTo(
          counterCounts[a.id] ?? 0,
        );
        return cmp != 0 ? cmp : byTitle(a, b);
      });
    case PodcastSort.played:
      sorted.sort((a, b) {
        final cmp = (playedCounts[b.id] ?? 0).compareTo(
          playedCounts[a.id] ?? 0,
        );
        return cmp != 0 ? cmp : byTitle(a, b);
      });
  }
  return sorted;
}

Future<void> _showCounterDialog(BuildContext context, WidgetRef ref) async {
  final selected = ref.read(settingsProvider).podcastCounter;
  final choice = await showDialog<PodcastCounter>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Compteur'),
      children: [
        for (final mode in PodcastCounter.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, mode),
            child: Row(
              children: [
                Expanded(child: Text(mode.label)),
                if (mode == selected) const Icon(Icons.check, size: 20),
              ],
            ),
          ),
      ],
    ),
  );
  if (choice == null) return;
  await ref.read(settingsProvider.notifier).setPodcastCounter(choice);
}

Future<void> _showFilterDialog(BuildContext context, WidgetRef ref) async {
  var draft = ref.read(settingsProvider).podcastFilters;
  final applied = await showDialog<PodcastFilters>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          void toggleCounter(bool? value) {
            setState(() {
              draft = draft.copyWith(counterAboveZero: value ?? false);
            });
          }

          void toggleAutoDownload(bool wantWith) {
            setState(() {
              if (draft.autoDownload == wantWith) {
                draft = draft.copyWith(clearAutoDownload: true);
              } else {
                draft = draft.copyWith(autoDownload: wantWith);
              }
            });
          }

          void toggleKeepUpdated(bool wantKept) {
            setState(() {
              if (draft.keepUpdated == wantKept) {
                draft = draft.copyWith(clearKeepUpdated: true);
              } else {
                draft = draft.copyWith(keepUpdated: wantKept);
              }
            });
          }

          return AlertDialog(
            title: const Text('Filtrer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compteur supérieur à zéro'),
                    value: draft.counterAboveZero,
                    onChanged: toggleCounter,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Avec téléchargements automatiques'),
                    value: draft.autoDownload == true,
                    onChanged: (_) => toggleAutoDownload(true),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sans téléchargements automatiques'),
                    value: draft.autoDownload == false,
                    onChanged: (_) => toggleAutoDownload(false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Maintenu à jour'),
                    value: draft.keepUpdated == true,
                    onChanged: (_) => toggleKeepUpdated(true),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Non maintenu à jour'),
                    value: draft.keepUpdated == false,
                    onChanged: (_) => toggleKeepUpdated(false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, PodcastFilters.empty),
                child: const Text('Effacer'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, draft),
                child: const Text('Appliquer'),
              ),
            ],
          );
        },
      );
    },
  );
  if (applied == null) return;
  await ref.read(settingsProvider.notifier).setPodcastFilters(applied);
}

Future<void> _showSortDialog(BuildContext context, WidgetRef ref) async {
  final selected = ref.read(settingsProvider).podcastSort;
  final choice = await showDialog<PodcastSort>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Trier'),
      children: [
        for (final mode in PodcastSort.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, mode),
            child: Row(
              children: [
                Expanded(child: Text(mode.label)),
                if (mode == selected) const Icon(Icons.check, size: 20),
              ],
            ),
          ),
      ],
    ),
  );
  if (choice == null) return;
  await ref.read(settingsProvider.notifier).setPodcastSort(choice);
}

Future<void> subscribeToFeed(
  BuildContext context,
  WidgetRef ref,
  String url, {
  bool openPodcast = true,
  String busyMessage = 'Ajout de l’abonnement…',
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogOpen = true;
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(busyMessage)),
          ],
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  void closeDialog() {
    if (!dialogOpen) return;
    dialogOpen = false;
    navigator.pop();
  }

  try {
    final result = await ref.read(feedServiceProvider).subscribe(url);
    closeDialog();
    if (!context.mounted) return;
    if (result.created) {
      showMessage(context, 'Abonnement ajouté');
    }
    if (openPodcast) {
      context.push(AppRoutes.podcast(result.podcastId));
    }
  } catch (error) {
    closeDialog();
    if (!context.mounted) return;
    showMessage(context, errorText(error));
  }
}

/// Ouvre la page podcast (épisodes). Charge un aperçu si pas encore en base.
Future<void> openPodcastFromFeedUrl(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;

  final known = ref.read(podcastsProvider).value ?? const [];
  for (final podcast in known) {
    if (podcast.feedUrl == trimmed) {
      context.push(AppRoutes.podcast(podcast.id));
      return;
    }
  }

  // Déjà en aperçu (hors liste d’abonnements) ?
  final existing = await ref.read(databaseProvider).findByFeedUrl(trimmed);
  if (!context.mounted) return;
  if (existing != null) {
    context.push(AppRoutes.podcast(existing.id));
    return;
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogOpen = true;
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Ouverture du podcast…')),
          ],
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  void closeDialog() {
    if (!dialogOpen) return;
    dialogOpen = false;
    navigator.pop();
  }

  try {
    final id = await ref.read(feedServiceProvider).preview(trimmed);
    closeDialog();
    if (!context.mounted) return;
    context.push(AppRoutes.podcast(id));
  } catch (error) {
    closeDialog();
    if (!context.mounted) return;
    showMessage(context, errorText(error));
  }
}

const _gridPadding = 16.0;
const _gridSpacing = 16.0;
const _phoneMaxColumns = 5;
const _tabletMaxColumns = 8;
const _tabletBreakpoint = 600.0;

int maxPodcastColumnsFor(double width) {
  return width >= _tabletBreakpoint ? _tabletMaxColumns : _phoneMaxColumns;
}

/// Taille lisible du titre en grille, selon la largeur de jaquette.
double _gridTitleFontSize(double tileWidth) {
  // ~12 % de la jaquette : assez grand sur peu de colonnes, compact si dense.
  return (tileWidth * 0.12).clamp(10.0, 14.5);
}

double _gridTitleGap(double fontSize) => fontSize >= 12.5 ? 8.0 : 6.0;

/// Taille lisible du titre en liste, selon la largeur d’écran.
double _listTitleFontSize(double screenWidth, double baseSize) {
  if (screenWidth < 360) return (baseSize * 0.88).clamp(13.0, 16.0);
  if (screenWidth < _tabletBreakpoint) {
    return (baseSize * 0.94).clamp(14.0, 17.0);
  }
  if (screenWidth < 900) return baseSize.clamp(15.0, 18.0);
  return (baseSize * 1.05).clamp(16.0, 19.0);
}

class _HighlightedTitle extends StatelessWidget {
  const _HighlightedTitle({
    required this.text,
    required this.query,
    required this.style,
  });

  final String text;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return HighlightedText(text: text, query: query, style: style);
  }
}

class _PodcastGrid extends StatelessWidget {
  const _PodcastGrid({
    required this.items,
    required this.columns,
    required this.showNames,
    required this.highlightQuery,
    required this.counts,
  });

  final List<Podcast> items;
  final int columns;
  final bool showNames;
  final String highlightQuery;
  final Map<int, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    const lineHeight = 1.2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth -
                _gridPadding * 2 -
                _gridSpacing * (columns - 1)) /
            columns;
        final fontSize = _gridTitleFontSize(tileWidth);
        final gap = _gridTitleGap(fontSize);
        final titleStyle = theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          height: lineHeight,
          fontSize: fontSize,
          letterSpacing: fontSize < 11.5 ? -0.1 : 0,
        );
        final titleHeight = showNames
            ? textScaler.scale(fontSize) * lineHeight * 2
            : 0.0;
        final textHeight = showNames ? gap + titleHeight : 0.0;
        return GridView.builder(
          padding: const EdgeInsets.all(_gridPadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _gridSpacing,
            crossAxisSpacing: _gridSpacing,
            mainAxisExtent: tileWidth + textHeight,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final podcast = items[index];
            final count = counts[podcast.id] ?? 0;
            return KeyedSubtree(
              key: ValueKey(podcast.id),
              child: _PodcastGridTile(
                podcast: podcast,
                showName: showNames,
                highlightQuery: highlightQuery,
                count: count,
                titleHeight: titleHeight,
                gap: gap,
                titleStyle: titleStyle,
                tileWidth: tileWidth,
              ),
            );
          },
        );
      },
    );
  }
}

class _PodcastGridTile extends StatelessWidget {
  const _PodcastGridTile({
    required this.podcast,
    required this.showName,
    required this.highlightQuery,
    required this.count,
    required this.titleHeight,
    required this.gap,
    required this.titleStyle,
    required this.tileWidth,
  });

  final Podcast podcast;
  final bool showName;
  final String highlightQuery;
  final int count;
  final double titleHeight;
  final double gap;
  final TextStyle? titleStyle;
  final double tileWidth;

  @override
  Widget build(BuildContext context) {
    final cover = _CoverWithCount(
      url: podcast.imageUrl,
      localPath: podcast.imagePath,
      radius: 16,
      count: count,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(AppRoutes.podcast(podcast.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: showName
                ? cover
                : Semantics(
                    label: podcast.title,
                    button: true,
                    child: cover,
                  ),
          ),
          if (showName) ...[
            SizedBox(height: gap),
            SizedBox(
              height: titleHeight,
              width: tileWidth,
              child: _HighlightedTitle(
                text: podcast.title,
                query: highlightQuery,
                style: titleStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PodcastListTile extends StatelessWidget {
  const _PodcastListTile({
    super.key,
    required this.podcast,
    required this.showName,
    required this.highlightQuery,
    required this.count,
  });

  final Podcast podcast;
  final bool showName;
  final String highlightQuery;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final baseSize = theme.textTheme.titleMedium?.fontSize ?? 16;
    final listStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.25,
      fontSize: _listTitleFontSize(screenWidth, baseSize),
    );
    final cover = _CoverWithCount(
      url: podcast.imageUrl,
      localPath: podcast.imagePath,
      size: 72,
      radius: 12,
      count: count,
    );
    return InkWell(
      onTap: () => context.push(AppRoutes.podcast(podcast.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: showName
                    ? cover
                    : Semantics(
                        label: podcast.title,
                        button: true,
                        child: cover,
                      ),
              ),
              if (showName) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _HighlightedTitle(
                    text: podcast.title,
                    query: highlightQuery,
                    style: listStyle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverWithCount extends StatelessWidget {
  const _CoverWithCount({
    required this.url,
    this.localPath,
    required this.radius,
    required this.count,
    this.size,
  });

  final String? url;
  final String? localPath;
  final double radius;
  final int count;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        PodcastCover(
          url: url,
          localPath: localPath,
          size: size,
          radius: radius,
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
