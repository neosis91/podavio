import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/discover_hit.dart';
import '../data/feed_service.dart';
import '../data/providers.dart';
import 'more_page.dart';
import 'podcasts_page.dart';
import 'router.dart';
import 'widgets/cover.dart';
import 'widgets/empty_state.dart';
import 'widgets/highlighted_text.dart';
import 'widgets/messages.dart';

/// Tendances iTunes (grille « suggestions » façon AntennaPod).
final discoverChartsProvider =
    AsyncNotifierProvider<DiscoverChartsNotifier, List<DiscoverHit>>(
      DiscoverChartsNotifier.new,
    );

class DiscoverChartsNotifier extends AsyncNotifier<List<DiscoverHit>> {
  @override
  Future<List<DiscoverHit>> build() => _load();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<List<DiscoverHit>> _load() async {
    return ref.read(feedServiceProvider).discoverCharts(limit: 48);
  }
}

/// Résultats de recherche (écran secondaire après soumission).
final discoverSearchProvider =
    AsyncNotifierProvider<DiscoverSearchNotifier, List<DiscoverHit>?>(
      DiscoverSearchNotifier.new,
    );

class DiscoverSearchNotifier extends AsyncNotifier<List<DiscoverHit>?> {
  DiscoverSearchScope _scope = DiscoverSearchScope.combined;
  String _query = '';

  DiscoverSearchScope get scope => _scope;
  String get query => _query;

  @override
  Future<List<DiscoverHit>?> build() async => null;

  Future<void> search(
    String query, {
    DiscoverSearchScope scope = DiscoverSearchScope.combined,
  }) async {
    final trimmed = query.trim();
    _scope = scope;
    _query = trimmed;
    if (trimmed.isEmpty) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(feedServiceProvider)
          .discoverSearch(trimmed, scope: scope),
    );
  }

  void clear() {
    _query = '';
    _scope = DiscoverSearchScope.combined;
    state = const AsyncData(null);
  }
}

const _quickSuggestions = 12;
const _tabletBreakpoint = 600.0;
const _searchDebounce = Duration(milliseconds: 450);

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _busy = <String>{};
  var _searching = false;
  var _query = '';
  var _scope = DiscoverSearchScope.combined;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch({DiscoverSearchScope scope = DiscoverSearchScope.combined}) {
    setState(() {
      _searching = true;
      _scope = scope;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(discoverSearchProvider.notifier).clear();
    setState(() {
      _searching = false;
      _query = '';
      _scope = DiscoverSearchScope.combined;
    });
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      ref.read(discoverSearchProvider.notifier).clear();
      return;
    }
    // URL collée : laisser l’utilisateur valider (évite un fetch RSS anticipé).
    if (_looksLikeFeedUrl(trimmed)) return;

    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      if (_searchController.text.trim() != trimmed) return;
      _runSearch(trimmed, _scope);
    });
  }

  String get _searchHint {
    return switch (_scope) {
      DiscoverSearchScope.combined => 'Rechercher un podcast',
      DiscoverSearchScope.apple => 'Rechercher sur Apple Podcasts',
      DiscoverSearchScope.podcastIndex => 'Rechercher sur Podcast Index',
      DiscoverSearchScope.fyyd => 'Rechercher sur fyyd',
    };
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(discoverSearchProvider);
    final showingResults =
        search.isLoading || (search.hasValue && search.value != null);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _searchHint,
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  _onSearchSubmitted(value, _scope);
                },
              )
            : const Text('Explorer'),
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
                      _debounce?.cancel();
                      _searchController.clear();
                      ref.read(discoverSearchProvider.notifier).clear();
                      setState(() => _query = '');
                    },
              icon: const Icon(Icons.close),
            )
          else
            IconButton(
              tooltip: 'Rechercher',
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
            ),
        ],
      ),
      body: showingResults
          ? _SearchResultsBody(
              search: search,
              query: _query.trim(),
              opening: _busy,
              onRetry: () => _runSearch(_query, _scope),
              onOpen: _open,
              onSubscribe: _subscribe,
            )
          : _DiscoverHomeBody(
              opening: _busy,
              onOpen: _open,
              onScopedSearch: (scope) {
                final q = _query.trim().isNotEmpty
                    ? _query.trim()
                    : _searchController.text.trim();
                _openSearch(scope: scope);
                if (q.isNotEmpty) {
                  _searchController.text = q;
                  setState(() => _query = q);
                  _debounce?.cancel();
                  _runSearch(q, scope);
                }
              },
              onAddByUrl: () => _showAddByUrlDialog(context),
              onImportOpml: () => importOpmlFile(context, ref),
            ),
    );
  }

  Future<void> _onSearchSubmitted(
    String value,
    DiscoverSearchScope scope,
  ) async {
    final query = value.trim();
    if (query.isEmpty) return;
    if (_looksLikeFeedUrl(query)) {
      await openPodcastFromFeedUrl(context, ref, query);
      return;
    }
    await _runSearch(query, scope);
  }

  Future<void> _runSearch(String query, DiscoverSearchScope scope) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _searching = true;
      _scope = scope;
      _query = trimmed;
    });
    await ref
        .read(discoverSearchProvider.notifier)
        .search(trimmed, scope: scope);
  }

  Future<String?> _resolveFeedUrl(DiscoverHit hit) async {
    final direct = hit.feedUrl.trim();
    if (direct.isNotEmpty) return direct;
    final appleId = hit.appleId;
    if (appleId == null) return null;
    return ref.read(feedServiceProvider).feedUrlForAppleShow(appleId);
  }

  Future<void> _open(DiscoverHit hit, String key) async {
    setState(() => _busy.add(key));
    try {
      final url = await _resolveFeedUrl(hit);
      if (!mounted) return;
      if (url == null) {
        showMessage(context, 'Pas de flux RSS public');
        return;
      }
      await openPodcastFromFeedUrl(context, ref, url);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _subscribe(DiscoverHit hit, String key) async {
    setState(() => _busy.add(key));
    try {
      final url = await _resolveFeedUrl(hit);
      if (!mounted) return;
      if (url == null) {
        showMessage(context, 'Pas de flux RSS public');
        return;
      }
      await subscribeToFeed(context, ref, url);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
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
                  if (!_looksLikeFeedUrl(value)) {
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
                    if (!_looksLikeFeedUrl(value)) {
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

class _DiscoverMorePageState extends ConsumerState<DiscoverMorePage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _busy = <String>{};
  var _searching = false;
  var _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
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
    _debounce?.cancel();
    _searchController.clear();
    ref.read(discoverSearchProvider.notifier).clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      ref.read(discoverSearchProvider.notifier).clear();
      return;
    }
    if (_looksLikeFeedUrl(trimmed)) return;

    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      if (_searchController.text.trim() != trimmed) return;
      _runSearch(trimmed);
    });
  }

  Future<void> _onSearchSubmitted(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    if (_looksLikeFeedUrl(query)) {
      await openPodcastFromFeedUrl(context, ref, query);
      return;
    }
    await _runSearch(query);
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _searching = true;
      _query = trimmed;
    });
    await ref.read(discoverSearchProvider.notifier).search(trimmed);
  }

  Future<String?> _resolveFeedUrl(DiscoverHit hit) async {
    final direct = hit.feedUrl.trim();
    if (direct.isNotEmpty) return direct;
    final appleId = hit.appleId;
    if (appleId == null) return null;
    return ref.read(feedServiceProvider).feedUrlForAppleShow(appleId);
  }

  Future<void> _open(DiscoverHit hit, String key) async {
    setState(() => _busy.add(key));
    try {
      final url = await _resolveFeedUrl(hit);
      if (!mounted) return;
      if (url == null) {
        showMessage(context, 'Pas de flux RSS public');
        return;
      }
      await openPodcastFromFeedUrl(context, ref, url);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _subscribe(DiscoverHit hit, String key) async {
    setState(() => _busy.add(key));
    try {
      final url = await _resolveFeedUrl(hit);
      if (!mounted) return;
      if (url == null) {
        showMessage(context, 'Pas de flux RSS public');
        return;
      }
      await subscribeToFeed(context, ref, url);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
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
        title: _searching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un podcast',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  _onSearchSubmitted(value);
                },
              )
            : const Text('Suggestions'),
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
                      _debounce?.cancel();
                      _searchController.clear();
                      ref.read(discoverSearchProvider.notifier).clear();
                      setState(() => _query = '');
                    },
              icon: const Icon(Icons.close),
            )
          else
            IconButton(
              tooltip: 'Rechercher',
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
            ),
        ],
      ),
      body: showingResults
          ? _SearchResultsBody(
              search: search,
              query: _query.trim(),
              opening: _busy,
              onRetry: () => _runSearch(_query),
              onOpen: _open,
              onSubscribe: _subscribe,
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
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Apple Podcasts · Podcast Index · fyyd',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final hit = items[index];
                            final key = hit.dedupeKey;
                            final busy = _busy.contains(key);
                            return Tooltip(
                              message: hit.title,
                              child: Material(
                                elevation: 2,
                                shadowColor: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: busy
                                      ? null
                                      : () => _open(hit, key),
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
                                              child:
                                                  CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: items.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

bool _looksLikeFeedUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  return uri != null &&
      (uri.isScheme('http') || uri.isScheme('https')) &&
      uri.host.isNotEmpty;
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
