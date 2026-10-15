import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/platform.dart';
import '../l10n/l10n.dart';
import '../core/search.dart';
import '../data/app_database.dart';
import '../data/feed_refresh_controller.dart';
import '../data/feed_service.dart';
import '../data/providers.dart';
import '../settings/settings_controller.dart';
import 'episodes_page.dart';
import 'router.dart';
import 'widgets/cover.dart';
import 'widgets/list_metrics.dart';
import 'widgets/empty_state.dart';
import 'widgets/highlighted_text.dart';

export 'podcasts/podcast_feed_actions.dart';

part 'podcasts/podcasts_providers.dart';
part 'podcasts/podcasts_filters.dart';
part 'podcasts/podcasts_tiles.dart';

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
    final counter = ref.watch(settingsProvider.select((s) => s.podcastCounter));
    final sort = ref.watch(settingsProvider.select((s) => s.podcastSort));
    final filters = ref.watch(settingsProvider.select((s) => s.podcastFilters));
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
            : Text(context.tr('Subscriptions')),
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
                const PopupMenuItem(value: 'counter', child: Text('Compteur')),
                const PopupMenuItem(value: 'filter', child: Text('Filtrer')),
                const PopupMenuItem(value: 'sort', child: Text('Trier')),
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
              loading: () => const Center(child: CircularProgressIndicator()),
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
                      label: Text(context.tr('Explore')),
                    ),
                  );
                }

                final needle = _query.trim();
                final searched = needle.isEmpty
                    ? items
                    : items.where((p) => searchMatch(p.title, needle)).toList();

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
                        padding: underChrome(
                          context,
                          const EdgeInsets.symmetric(vertical: 8),
                        ),
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
