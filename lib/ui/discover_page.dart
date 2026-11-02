import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/catalog_categories.dart';
import '../data/discover_hit.dart';
import '../data/online_status.dart';
import '../l10n/l10n.dart';
import '../data/discover_providers.dart';
import '../data/feed_service.dart';
import '../settings/settings_controller.dart';
import 'category_subjects_sheet.dart';
import 'discover/discover_hit_actions.dart';
import 'discover/discover_search_host.dart';
import 'more_page.dart';
import 'podcasts_page.dart';
import 'router.dart';
import 'widgets/app_bottom_sheet.dart';
import 'widgets/brand.dart';
import 'widgets/cover.dart';
import 'widgets/discover_category_tile.dart';
import 'widgets/frosted_header.dart';
import 'widgets/empty_state.dart';
import 'widgets/highlighted_text.dart';
import 'widgets/messages.dart';
import 'widgets/selection_chip.dart';

export '../data/discover_providers.dart';

const _tabletBreakpoint = 600.0;

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage>
    with DiscoverSearchHost, DiscoverHitActions {
  String? _category;
  @override
  void dispose() {
    disposeSearchHost();
    super.dispose();
  }

  @override
  Future<void> runDiscoverSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || ref.read(onlineStatusProvider) == false) return;
    setState(() {
      searching = true;
      this.query = trimmed;
    });
    await ref
        .read(discoverSearchProvider.notifier)
        .search(trimmed, scope: searchScope);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(discoverSearchProvider);
    final offline = ref.watch(onlineStatusProvider) == false;
    final categories = ref.watch(displayedHomeCategoriesProvider);
    final category = categories.isOn(_category ?? '') ? _category : null;
    final showingResults =
        !offline &&
        (search.isLoading || (search.hasValue && search.value != null));

    return FrostedScaffold(
      appBar: FrostedAppBar(
        title: searching
            ? TextField(
                controller: searchController,
                focusNode: searchFocus,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: searchHint,
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onChanged: onQueryChanged,
                onSubmitted: (value) {
                  cancelDebounce();
                  onSearchSubmitted(value);
                },
              )
            : Text(context.tr('Explore')),
        leading: searching
            ? IconButton(
                tooltip: 'Fermer la recherche',
                onPressed: closeSearch,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          if (!searching)
            IconButton(
              tooltip: 'Ajouter un podcast',
              onPressed: () => _showAddSheet(context),
              icon: const Icon(Icons.add),
            ),
          if (!searching)
            IconButton(
              tooltip: context.tr('Listening language'),
              onPressed: () => context.push(AppRoutes.discoverLanguages),
              icon: const TranslateIcon(),
            ),
          if (searching)
            IconButton(
              tooltip: 'Effacer',
              onPressed: clearQueryOrClose,
              icon: const Icon(Icons.close),
            )
          else
            IconButton(
              tooltip: 'Rechercher',
              onPressed: offline ? null : openSearch,
              icon: const Icon(Icons.search),
            ),
        ],
      ),
      body: offline
          ? const _OfflineExplore()
          : showingResults
          ? _SearchResultsBody(
              search: search,
              query: query.trim(),
              opening: busyHits,
              onRetry: () => runDiscoverSearch(query),
              onOpen: openHit,
              onSubscribe: subscribeHit,
            )
          : _DiscoverHomeBody(
              categories: categories,
              category: category,
              onCategory: (id) => setState(() => _category = id),
            ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        void choose(VoidCallback action) {
          Navigator.pop(sheetContext);
          action();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionRow(
                icon: Icons.rss_feed_outlined,
                label: 'Ajouter via une adresse RSS',
                onTap: () => choose(() => _showAddByUrlDialog(context)),
              ),
              _ActionRow(
                icon: Icons.search,
                label: 'Rechercher sur Apple Podcasts',
                onTap: () =>
                    choose(() => _openScopedSearch(DiscoverSearchScope.apple)),
              ),
              _ActionRow(
                icon: Icons.search,
                label: 'Rechercher sur Podcast Index',
                onTap: () => choose(
                  () => _openScopedSearch(DiscoverSearchScope.podcastIndex),
                ),
              ),
              _ActionRow(
                icon: Icons.search,
                label: 'Rechercher sur fyyd',
                onTap: () =>
                    choose(() => _openScopedSearch(DiscoverSearchScope.fyyd)),
              ),
              _ActionRow(
                icon: Icons.file_upload_outlined,
                label: 'Importer une liste de podcasts (OPML)',
                onTap: () => choose(() => importOpmlFile(context, ref)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openScopedSearch(DiscoverSearchScope scope) {
    final q = query.trim().isNotEmpty
        ? query.trim()
        : searchController.text.trim();
    openSearch(scope: scope);
    if (q.isNotEmpty) {
      searchController.text = q;
      setState(() => query = q);
      cancelDebounce();
      runDiscoverSearch(q);
    }
  }

  Future<void> _showAddByUrlDialog(BuildContext context) async {
    final controller = TextEditingController();
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final clip = clipboard?.text?.trim() ?? '';
    if (clip.startsWith('http')) {
      controller.text = clip;
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    }

    if (!context.mounted) return;
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ajouter via une adresse RSS'),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'https://…',
                  errorText: error,
                ),
                onSubmitted: (value) {
                  if (!looksLikeFeedUrl(value)) {
                    setDialogState(() => error = 'Adresse invalide');
                    return;
                  }
                  Navigator.of(context).pop(value.trim());
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (!looksLikeFeedUrl(value)) {
                      setDialogState(() => error = 'Adresse invalide');
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (url == null || !context.mounted) return;
    await openPodcastFromFeedUrl(context, ref, url);
  }
}

class _OfflineExplore extends StatelessWidget {
  const _OfflineExplore();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: context.tr('No internet connection'),
      message: context.tr('Explore needs an internet connection.'),
    );
  }
}

/// Toutes les suggestions (ouverte via « Découvrir plus »).
class DiscoverMorePage extends ConsumerStatefulWidget {
  const DiscoverMorePage({super.key});

  @override
  ConsumerState<DiscoverMorePage> createState() => _DiscoverMorePageState();
}

class _DiscoverMorePageState extends ConsumerState<DiscoverMorePage>
    with DiscoverSearchHost, DiscoverHitActions {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    disposeSearchHost();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 800) {
      ref.read(discoverChartsProvider.notifier).loadMore();
    }
  }

  void _fillIfShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent < 800) {
        ref.read(discoverChartsProvider.notifier).loadMore();
      }
    });
  }

  @override
  Future<void> runDiscoverSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || ref.read(onlineStatusProvider) == false) return;
    setState(() {
      searching = true;
      this.query = trimmed;
    });
    await ref.read(discoverSearchProvider.notifier).search(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(discoverSearchProvider);
    final charts = ref.watch(discoverChartsProvider);
    final offline = ref.watch(onlineStatusProvider) == false;
    final showingResults =
        !offline &&
        (search.isLoading || (search.hasValue && search.value != null));
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= _tabletBreakpoint ? 6 : 4;

    return FrostedScaffold(
      appBar: FrostedAppBar(
        title: searching
            ? TextField(
                controller: searchController,
                focusNode: searchFocus,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un podcast',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onChanged: onQueryChanged,
                onSubmitted: (value) {
                  cancelDebounce();
                  onSearchSubmitted(value);
                },
              )
            : const Text('Suggestions'),
        leading: searching
            ? IconButton(
                tooltip: 'Fermer la recherche',
                onPressed: closeSearch,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          if (!searching)
            IconButton(
              tooltip: context.tr('Listening language'),
              onPressed: () => context.push(AppRoutes.discoverLanguages),
              icon: const TranslateIcon(),
            ),
          if (searching)
            IconButton(
              tooltip: 'Effacer',
              onPressed: clearQueryOrClose,
              icon: const Icon(Icons.close),
            )
          else
            IconButton(
              tooltip: 'Rechercher',
              onPressed: offline ? null : openSearch,
              icon: const Icon(Icons.search),
            ),
        ],
      ),
      body: offline
          ? const _OfflineExplore()
          : showingResults
          ? _SearchResultsBody(
              search: search,
              query: query.trim(),
              opening: busyHits,
              onRetry: () => runDiscoverSearch(query),
              onOpen: openHit,
              onSubscribe: subscribeHit,
            )
          : charts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                title: 'Suggestions indisponibles',
                message: errorText(error),
                action: FilledButton(
                  onPressed: () =>
                      ref.read(discoverChartsProvider.notifier).reload(),
                  child: const Text('Réessayer'),
                ),
              ),
              data: (charts) {
                final items = charts.hits;
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'Aucune suggestion',
                    message: 'Réessayez plus tard.',
                  );
                }
                if (charts.hasMore && !charts.loadingMore) _fillIfShort();
                return MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  removeBottom: true,
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverPadding(
                        padding: belowFrostedBar(
                          context,
                          const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        ),
                        sliver: SliverMainAxisGroup(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Text(
                                'Apple Podcasts · Podcast Index · fyyd',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 8),
                            ),
                            SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                return _DiscoverCover(
                                  hit: items[index],
                                  busy: busyHits.contains(
                                    items[index].dedupeKey,
                                  ),
                                  onOpen: openHit,
                                );
                              }, childCount: items.length),
                            ),
                            if (charts.loadingMore)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _DiscoverHomeBody extends ConsumerStatefulWidget {
  const _DiscoverHomeBody({
    required this.categories,
    required this.category,
    required this.onCategory,
  });

  final HomeCategories categories;
  final String? category;
  final ValueChanged<String?> onCategory;

  @override
  ConsumerState<_DiscoverHomeBody> createState() => _DiscoverHomeBodyState();
}

class _DiscoverHomeBodyState extends ConsumerState<_DiscoverHomeBody> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DiscoverHomeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category == widget.category) return;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillIfShort());
  }

  void _onScroll() {
    if (!_scroll.hasClients || _scroll.position.extentAfter >= 800) return;
    _requestMore();
  }

  void _requestMore() {
    final category = widget.category;
    if (category == null) {
      ref.read(discoverChartsProvider.notifier).loadMore();
    } else {
      ref.read(homeCategoryHitsProvider(category).notifier).loadMore();
    }
  }

  void _fillIfShort() {
    if (!mounted || !_scroll.hasClients) return;
    if (_scroll.position.maxScrollExtent < 800) _requestMore();
  }

  void _keepFilling(
    AsyncValue<DiscoverCharts>? previous,
    AsyncValue<DiscoverCharts> next,
  ) {
    final hits = next.asData?.value;
    if (hits == null || !hits.hasMore || hits.loadingMore) return;
    final previousCount = previous?.asData?.value.hits.length ?? 0;
    if (hits.hits.length > previousCount || previous?.isLoading == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fillIfShort());
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    if (category == null) {
      ref.listen(discoverChartsProvider, _keepFilling);
    } else {
      ref.listen(homeCategoryHitsProvider(category), _keepFilling);
    }

    return ListView(
      controller: _scroll,
      padding: belowFrostedBar(context, const EdgeInsets.only(bottom: 24)),
      children: [
        SizedBox(
          height: 48,
          child: _ExploreCategoryChips(
            categories: widget.categories,
            selected: category,
            onSelected: widget.onCategory,
          ),
        ),
        if (category != null)
          _ExploreCategoryList(categoryId: category)
        else
          const _ExploreSuggestions(),
      ],
    );
  }
}

class _ExploreSuggestions extends ConsumerWidget {
  const _ExploreSuggestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(discoverChartsProvider);
    final charts = async.value;
    final list = charts?.hits ?? const <DiscoverHit>[];
    final loadingMore = charts?.loadingMore ?? false;
    final hasMore = charts?.hasMore ?? false;
    final showStatus =
        (async.isLoading && list.isEmpty) ||
        (async.hasError && list.isEmpty) ||
        (!async.isLoading && list.isEmpty && !async.hasError);

    if (showStatus) {
      if (async.isLoading && list.isEmpty) {
        return const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (async.hasError && list.isEmpty) {
        return EmptyState(
          title: 'Suggestions',
          message: context.tr('The search failed.'),
          action: FilledButton(
            onPressed: () => ref.read(discoverChartsProvider.notifier).reload(),
            child: Text(context.tr('Retry')),
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Aucune suggestion pour le moment.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in list.indexed) ...[
          if (entry.$1 > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: Theme.of(context).colorScheme.outlineVariant
                  .withValues(alpha: 0.5),
            ),
          DiscoverCategoryTile(rank: entry.$1 + 1, hit: entry.$2),
        ],
        if (hasMore || loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExploreCategoryChips extends StatelessWidget {
  const _ExploreCategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final HomeCategories categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final ids = categories.visible;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      itemCount: ids.length + 1,
      separatorBuilder: (_, _) => const SizedBox(width: 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return SelectionChip(
            label: context.tr('All'),
            selected: selected == null,
            onSelected: () => onSelected(null),
          );
        }
        final id = ids[index - 1];
        return SelectionChip(
          label: context.tr(homeCategoryTitle(id)),
          selected: selected == id,
          onSelected: () => onSelected(id),
        );
      },
    );
  }
}

class _ExploreCategoryList extends ConsumerWidget {
  const _ExploreCategoryList({required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeCategoryHitsProvider(categoryId));
    final charts = async.value;
    final list = charts?.hits ?? const <DiscoverHit>[];
    final title = context.tr(homeCategoryTitle(categoryId));
    final loadingMore = charts?.loadingMore ?? false;
    final hasMore = charts?.hasMore ?? false;
    final showStatus =
        (async.isLoading && list.isEmpty) ||
        (async.hasError && list.isEmpty) ||
        (!async.isLoading && list.isEmpty && !async.hasError);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton(
                onPressed: () =>
                    showCategorySubjectsSheet(context, ref, categoryId),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  visualDensity: VisualDensity.compact,
                  textStyle: Theme.of(context).textTheme.bodySmall,
                ),
                child: Text(context.tr('Subjects')),
              ),
            ],
          ),
        ),
        CategorySubjectChips(categoryId: categoryId),
        if (showStatus)
          _ExploreCategoryStatus(
            title: title,
            loading: async.isLoading && list.isEmpty,
            failed: async.hasError && list.isEmpty,
            onRetry: () => ref
                .read(homeCategoryHitsProvider(categoryId).notifier)
                .reload(),
          )
        else ...[
          for (final entry in list.indexed) ...[
            if (entry.$1 > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context).colorScheme.outlineVariant
                    .withValues(alpha: 0.5),
              ),
            DiscoverCategoryTile(rank: entry.$1 + 1, hit: entry.$2),
          ],
          if (hasMore || loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ExploreCategoryStatus extends StatelessWidget {
  const _ExploreCategoryStatus({
    required this.title,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  final String title;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (failed) {
      return EmptyState(
        title: title,
        message: context.tr('The search failed.'),
        action: FilledButton(
          onPressed: onRetry,
          child: Text(context.tr('Retry')),
        ),
      );
    }
    return EmptyState(
      title: context.tr('Nothing new in this category'),
      message: context.tr('You already follow the podcasts found here.'),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      minVerticalPadding: 12,
      onTap: onTap,
    );
  }
}

class _DiscoverCover extends StatelessWidget {
  const _DiscoverCover({
    required this.hit,
    required this.busy,
    required this.onOpen,
  });

  final DiscoverHit hit;
  final bool busy;
  final Future<void> Function(DiscoverHit hit, String key) onOpen;

  @override
  Widget build(BuildContext context) {
    final key = hit.dedupeKey;
    return Tooltip(
      message: hit.title,
      child: Material(
        elevation: 2,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : () => onOpen(hit, key),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PodcastCover(
                url: hit.imageUrl,
                label: hit.title,
                size: null,
                radius: 0,
              ),
              if (busy)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultsBody extends StatelessWidget {
  const _SearchResultsBody({
    required this.search,
    required this.query,
    required this.opening,
    required this.onRetry,
    required this.onOpen,
    required this.onSubscribe,
  });

  final AsyncValue<List<DiscoverHit>?> search;
  final String query;
  final Set<String> opening;
  final VoidCallback onRetry;
  final Future<void> Function(DiscoverHit hit, String key) onOpen;
  final Future<void> Function(DiscoverHit hit, String key) onSubscribe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return search.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        title: 'Recherche indisponible',
        message: errorText(error),
        action: FilledButton(
          onPressed: onRetry,
          child: const Text('Réessayer'),
        ),
      ),
      data: (items) {
        final list = items ?? const <DiscoverHit>[];
        if (list.isEmpty) {
          return EmptyState(
            title: 'Aucun podcast trouvé',
            message: query.isEmpty
                ? 'Essayez un autre mot-clé.'
                : 'Aucun résultat pour « $query ».',
          );
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final hit = list[index];
            final key = hit.dedupeKey;
            final busy = opening.contains(key);
            final canOpen =
                hit.feedUrl.trim().isNotEmpty || hit.appleId != null;
            final needle = query.trim().toLowerCase();
            return ListTile(
              key: ValueKey(key),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: PodcastCover(
                url: hit.imageUrl,
                label: hit.title,
                size: 64,
                radius: 8,
              ),
              title: HighlightedText(
                text: hit.title,
                query: needle,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hit.author.isNotEmpty)
                    HighlightedText(
                      text: hit.author,
                      query: needle,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    hit.source.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              isThreeLine: hit.author.isNotEmpty,
              onTap: !canOpen || busy ? null : () => onOpen(hit, key),
              trailing: busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: !canOpen
                          ? 'Pas de flux RSS public'
                          : 'S’abonner',
                      onPressed: !canOpen ? null : () => onSubscribe(hit, key),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
            );
          },
        );
      },
    );
  }
}
