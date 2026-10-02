import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/discover_hit.dart';
import '../data/discover_providers.dart';
import '../data/feed_service.dart';
import 'discover/discover_hit_actions.dart';
import 'discover/discover_search_host.dart';
import 'more_page.dart';
import 'podcasts_page.dart';
import 'router.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/highlighted_text.dart';
import 'widgets/messages.dart';

export '../data/discover_providers.dart';

const _quickSuggestions = 12;
const _tabletBreakpoint = 600.0;

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage>
    with DiscoverSearchHost, DiscoverHitActions {
  @override
  void dispose() {
    disposeSearchHost();
    super.dispose();
  }

  @override
  Future<void> runDiscoverSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
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
    final showingResults =
        search.isLoading || (search.hasValue && search.value != null);

    return Scaffold(
      appBar: AppBar(
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
            : const Text('Explorer'),
        leading: searching
            ? IconButton(
                tooltip: 'Fermer la recherche',
                onPressed: closeSearch,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          if (searching)
            IconButton(
              tooltip: 'Effacer',
              onPressed: clearQueryOrClose,
              icon: const Icon(Icons.close),
            )
          else
            IconButton(
              tooltip: 'Rechercher',
              onPressed: openSearch,
              icon: const Icon(Icons.search),
            ),
        ],
      ),
      body: showingResults
          ? _SearchResultsBody(
              search: search,
              query: query.trim(),
              opening: busyHits,
              onRetry: () => runDiscoverSearch(query),
              onOpen: openHit,
              onSubscribe: subscribeHit,
            )
          : _DiscoverHomeBody(
              opening: busyHits,
              onOpen: openHit,
              onScopedSearch: (scope) {
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
              },
              onAddByUrl: () => _showAddByUrlDialog(context),
              onImportOpml: () => importOpmlFile(context, ref),
            ),
    );
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

/// Toutes les suggestions (ouverte via « Découvrir plus »).
class DiscoverMorePage extends ConsumerStatefulWidget {
  const DiscoverMorePage({super.key});

  @override
  ConsumerState<DiscoverMorePage> createState() => _DiscoverMorePageState();
}

class _DiscoverMorePageState extends ConsumerState<DiscoverMorePage>
    with DiscoverSearchHost, DiscoverHitActions {
  @override
  void dispose() {
    disposeSearchHost();
    super.dispose();
  }

  @override
  Future<void> runDiscoverSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
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
    final showingResults =
        search.isLoading || (search.hasValue && search.value != null);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= _tabletBreakpoint ? 6 : 4;

    return Scaffold(
      appBar: AppBar(
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
          if (searching)
            IconButton(
              tooltip: 'Effacer',
              onPressed: clearQueryOrClose,
              icon: const Icon(Icons.close),
            )
          else
            IconButton(
              tooltip: 'Rechercher',
              onPressed: openSearch,
              icon: const Icon(Icons.search),
            ),
        ],
      ),
      body: showingResults
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
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'Aucune suggestion',
                    message: 'Réessayez plus tard.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(
                      'Apple Podcasts · Podcast Index · fyyd',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CoverGrid(
                      items: items,
                      columns: columns,
                      opening: busyHits,
                      onOpen: openHit,
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _DiscoverHomeBody extends ConsumerWidget {
  const _DiscoverHomeBody({
    required this.opening,
    required this.onOpen,
    required this.onScopedSearch,
    required this.onAddByUrl,
    required this.onImportOpml,
  });

  final Set<String> opening;
  final Future<void> Function(DiscoverHit hit, String key) onOpen;
  final ValueChanged<DiscoverSearchScope> onScopedSearch;
  final VoidCallback onAddByUrl;
  final VoidCallback onImportOpml;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charts = ref.watch(discoverChartsProvider);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= _tabletBreakpoint ? 6 : 4;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: charts.when(
            loading: () => _ChartsPlaceholderGrid(columns: columns),
            error: (error, _) => _ChartsError(
              message: errorText(error),
              onRetry: () =>
                  ref.read(discoverChartsProvider.notifier).reload(),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucune suggestion pour le moment.'),
                );
              }
              final visible = items.take(_quickSuggestions).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CoverGrid(
                    items: visible,
                    columns: columns,
                    opening: opening,
                    onOpen: onOpen,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Suggestions · Apple, Podcast Index, fyyd',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (items.length > _quickSuggestions)
                        TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.discoverMore),
                          child: const Text('Découvrir plus »'),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _ActionRow(
          icon: Icons.rss_feed_outlined,
          label: 'Ajouter via une adresse RSS',
          onTap: onAddByUrl,
        ),
        _ActionRow(
          icon: Icons.search,
          label: 'Rechercher sur Apple Podcasts',
          onTap: () => onScopedSearch(DiscoverSearchScope.apple),
        ),
        _ActionRow(
          icon: Icons.search,
          label: 'Rechercher sur Podcast Index',
          onTap: () => onScopedSearch(DiscoverSearchScope.podcastIndex),
        ),
        _ActionRow(
          icon: Icons.search,
          label: 'Rechercher sur fyyd',
          onTap: () => onScopedSearch(DiscoverSearchScope.fyyd),
        ),
        _ActionRow(
          icon: Icons.file_upload_outlined,
          label: 'Importer une liste de podcasts (OPML)',
          onTap: onImportOpml,
        ),
      ],
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

class _CoverGrid extends StatelessWidget {
  const _CoverGrid({
    required this.items,
    required this.columns,
    required this.opening,
    required this.onOpen,
  });

  final List<DiscoverHit> items;
  final int columns;
  final Set<String> opening;
  final Future<void> Function(DiscoverHit hit, String key) onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final hit = items[index];
        final key = hit.dedupeKey;
        final busy = opening.contains(key);

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
      },
    );
  }
}

class _ChartsPlaceholderGrid extends StatelessWidget {
  const _ChartsPlaceholderGrid({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _quickSuggestions,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _ChartsError extends StatelessWidget {
  const _ChartsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
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
                      onPressed: !canOpen
                          ? null
                          : () => onSubscribe(hit, key),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
            );
          },
        );
      },
    );
  }
}
