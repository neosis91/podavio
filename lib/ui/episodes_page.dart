import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../data/feed_refresh_controller.dart';
import '../settings/settings_controller.dart';
import 'router.dart';
import 'widgets/empty_state.dart';
import 'widgets/episode_list.dart';
import 'widgets/messages.dart';

part 'episodes/episodes_filters.dart';

class EpisodesPage extends ConsumerStatefulWidget {
  const EpisodesPage({super.key});

  @override
  ConsumerState<EpisodesPage> createState() => _EpisodesPageState();
}

class _EpisodesPageState extends ConsumerState<EpisodesPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  var _searching = false;
  var _search = '';
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
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
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searching = false;
      _search = '';
    });
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    setState(() {});
    _searchTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final refreshing = ref.watch(
      feedRefreshProvider.select((s) => s.isRunning),
    );
    final filters = ref.watch(
      settingsProvider.select((s) => s.episodeFilters),
    );
    final hasFilters = !filters.isEmpty;
    final isInboxDefault =
        filters.unreadOnly &&
        !filters.downloadsOnly &&
        !filters.inProgressOnly;
    final hasSearch = _search.isNotEmpty;
    final showFilterEmpty = hasFilters && !isInboxDefault;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un épisode',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
              )
            : const Text('Épisodes'),
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
              onPressed: _searchController.text.isEmpty
                  ? _closeSearch
                  : () {
                      _searchTimer?.cancel();
                      _searchController.clear();
                      setState(() => _search = '');
                    },
              icon: const Icon(Icons.close),
            )
          else ...[
            IconButton(
              tooltip: 'Rechercher',
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: refreshing
                  ? 'Actualisation en cours'
                  : 'Actualiser les abonnements',
              onPressed: refreshing
                  ? null
                  : () => refreshSubscriptions(context, ref),
              icon: const Icon(Icons.refresh),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'filter':
                    await _showEpisodeFilterDialog(context, ref);
                  case 'played':
                    await ref.read(databaseProvider).markAllPlayed();
                    if (context.mounted) {
                      showMessage(context, 'Épisodes marqués comme lus');
                    }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'filter',
                  child: Text('Filtrer'),
                ),
                PopupMenuItem(
                  value: 'played',
                  child: Text('Tout marquer comme lu'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasFilters)
            _ActiveEpisodeFiltersBar(
              filters: filters,
              onEdit: () => _showEpisodeFilterDialog(context, ref),
              onChanged: (next) =>
                  ref.read(settingsProvider.notifier).setEpisodeFilters(next),
            ),
          Expanded(
            child: EpisodeListBody(
              query: EpisodeQuery(
                unreadOnly: filters.unreadOnly,
                downloadsOnly: filters.downloadsOnly,
                inProgressOnly: filters.inProgressOnly,
                search: _search,
              ),
              highlightQuery: _search,
              onRefresh: refreshing
                  ? null
                  : () => refreshSubscriptions(context, ref),
              empty: EmptyState(
                title: hasSearch
                    ? 'Aucun résultat'
                    : showFilterEmpty
                    ? 'Aucun épisode'
                    : 'Aucun épisode à écouter',
                message: hasSearch && showFilterEmpty
                    ? 'Essayez un autre mot, ou modifiez les filtres.'
                    : hasSearch
                    ? 'Essayez un autre mot, ou effacez la recherche.'
                    : showFilterEmpty
                    ? 'Aucun épisode ne correspond aux filtres choisis.'
                    : 'Abonnez-vous à un podcast depuis Explorer, ou collez l’adresse d’un flux RSS.',
                action: hasSearch && showFilterEmpty
                    ? TextButton(
                        onPressed: () => ref
                            .read(settingsProvider.notifier)
                            .setEpisodeFilters(EpisodeFilters.empty),
                        child: const Text('Effacer les filtres'),
                      )
                    : hasSearch
                    ? TextButton(
                        onPressed: _closeSearch,
                        child: const Text('Effacer la recherche'),
                      )
                    : showFilterEmpty
                    ? TextButton(
                        onPressed: () => ref
                            .read(settingsProvider.notifier)
                            .setEpisodeFilters(EpisodeFilters.empty),
                        child: const Text('Effacer les filtres'),
                      )
                    : FilledButton(
                        onPressed: () => context.go(AppRoutes.discover),
                        child: const Text('Explorer'),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> refreshSubscriptions(BuildContext context, WidgetRef ref) async {
  final outcome = await ref.read(feedRefreshProvider.notifier).start();
  if (!context.mounted) return;
  switch (outcome.result) {
    case FeedRefreshStartResult.started:
      break;
    case FeedRefreshStartResult.alreadyRunning:
      showMessage(context, 'Actualisation déjà en cours');
      break;
    case FeedRefreshStartResult.empty:
      showMessage(context, 'Aucun abonnement à actualiser');
      break;
    case FeedRefreshStartResult.throttled:
      final wait = formatRefreshRetryAfter(
        outcome.retryAfter ?? Duration.zero,
      );
      showMessage(
        context,
        'Actualisation récente — réessayez dans $wait',
      );
      break;
  }
}
