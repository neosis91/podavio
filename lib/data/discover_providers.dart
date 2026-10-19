import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import 'catalog_categories.dart';
import 'discover_hit.dart';
import 'online_status.dart';
import 'feed_service.dart';
import 'providers.dart';

/// Tendances combinées (grille « suggestions »), chargées par pages.
final discoverChartsProvider =
    AsyncNotifierProvider<DiscoverChartsNotifier, DiscoverCharts>(
      DiscoverChartsNotifier.new,
    );

class DiscoverCharts {
  const DiscoverCharts({
    this.hits = const [],
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<DiscoverHit> hits;
  final bool hasMore;
  final bool loadingMore;

  DiscoverCharts copyWith({
    List<DiscoverHit>? hits,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return DiscoverCharts(
      hits: hits ?? this.hits,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

class DiscoverChartsNotifier extends AsyncNotifier<DiscoverCharts> {
  static const pageSize = 16;

  /// Assez pour quatre rangées même avec le maximum de colonnes.
  static const firstBatch = 48;
  static const _maxPages = 40;

  var _page = 0;
  var _generation = 0;
  var _loadingMore = false;
  final _seen = <String>{};

  @override
  Future<DiscoverCharts> build() {
    ref.watch(
      settingsProvider.select(
        (settings) => settings.discoverLanguages.join('\u0001'),
      ),
    );
    ref.listen(onlineStatusProvider, (previous, next) {
      if (previous == false && next == true) unawaited(reload());
    });
    _generation++;
    if (ref.read(onlineStatusProvider) == false) {
      return Future.value(const DiscoverCharts(hasMore: false));
    }
    return _loadFirst();
  }

  Future<void> reload() async {
    _generation++;
    _reset();
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFirst);
  }

  Future<void> loadMore() async {
    if (ref.read(onlineStatusProvider) == false) return;
    final current = state.asData?.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    final gen = _generation;
    _loadingMore = true;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final fresh = await _fetchFresh();
      if (gen != _generation) return;
      final latest = state.asData?.value ?? current;
      final hasMore = fresh.isNotEmpty && _page < _maxPages;
      state = AsyncData(
        latest.copyWith(
          hits: [...latest.hits, ...fresh],
          hasMore: hasMore,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (gen != _generation) return;
      final latest = state.asData?.value ?? current;
      state = AsyncData(latest.copyWith(loadingMore: false));
    } finally {
      if (gen == _generation) _loadingMore = false;
    }
  }

  void _reset() {
    _page = 0;
    _loadingMore = false;
    _seen.clear();
  }

  Future<DiscoverCharts> _loadFirst() async {
    _reset();
    final hits = <DiscoverHit>[];
    var hasMore = true;
    while (hits.length < firstBatch && hasMore && _page < _maxPages) {
      final fresh = await _fetchFresh();
      if (fresh.isEmpty) {
        hasMore = false;
        break;
      }
      hits.addAll(fresh);
    }
    return DiscoverCharts(hits: hits, hasMore: hasMore && _page < _maxPages);
  }

  Future<List<DiscoverHit>> _fetchFresh() async {
    final gen = _generation;
    final page = _page;
    final languages = ref.read(settingsProvider).discoverLanguages;
    final merged = await ref
        .read(feedServiceProvider)
        .discoverChartsPage(
          page: page,
          pageSize: pageSize,
          languages: languages,
        );
    if (gen != _generation) return const [];
    _page = page + 1;
    final fresh = <DiscoverHit>[];
    for (final hit in merged) {
      if (_seen.add(hit.dedupeKey)) fresh.add(hit);
    }
    return fresh;
  }
}

/// Résultats de recherche Discover.
final discoverSearchProvider =
    AsyncNotifierProvider<DiscoverSearchNotifier, List<DiscoverHit>?>(
      DiscoverSearchNotifier.new,
    );

class DiscoverSearchNotifier extends AsyncNotifier<List<DiscoverHit>?> {
  DiscoverSearchScope _scope = DiscoverSearchScope.combined;
  String _query = '';
  var _generation = 0;

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
    final gen = ++_generation;
    if (trimmed.isEmpty) {
      state = const AsyncData(null);
      return;
    }
    if (ref.read(onlineStatusProvider) == false) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    final languages = ref.read(settingsProvider).discoverLanguages;
    final next = await AsyncValue.guard(
      () => ref
          .read(feedServiceProvider)
          .discoverSearch(trimmed, scope: scope, languages: languages),
    );
    if (gen != _generation) return;
    state = next;
  }

  void clear() {
    ++_generation;
    _query = '';
    _scope = DiscoverSearchScope.combined;
    state = const AsyncData(null);
  }
}

const _monthlyCategoryRanksKey = 'homeCategoryRanks';
const _monthlyCategoryRanksAtKey = 'homeCategoryRanksAt';

/// Classement des catégories les plus présentes dans les tops du mois.
final monthlyCategoryRanksProvider = FutureProvider<List<String>>((ref) async {
  final preferences = ref.watch(sharedPreferencesProvider);
  final languages = ref.watch(
    settingsProvider.select((settings) => settings.discoverLanguages),
  );
  final now = DateTime.now();
  final cached = readMonthlyCategoryRanks(
    stored: preferences.getString(_monthlyCategoryRanksKey),
    storedAtMillis: preferences.getInt(_monthlyCategoryRanksAtKey),
    languages: languages,
    now: now,
  );
  if (cached != null) return cached;
  if (ref.watch(onlineStatusProvider) == false) return const [];
  try {
    final ranks = await ref
        .read(feedServiceProvider)
        .mostPlayedCategoryIds(languages);
    await preferences.setString(
      _monthlyCategoryRanksKey,
      writeMonthlyCategoryRanks(languages: languages, ranks: ranks, now: now),
    );
    await preferences.setInt(
      _monthlyCategoryRanksAtKey,
      now.millisecondsSinceEpoch,
    );
    return ranks;
  } catch (_) {
    return const [];
  }
});

/// Pastilles de l’accueil. Un choix dans Interface gagne. Sinon, le mois.
final displayedHomeCategoriesProvider = Provider<HomeCategories>((ref) {
  final chosen = ref.watch(
    settingsProvider.select((settings) => settings.homeCategoriesChosen),
  );
  final stored = ref.watch(
    settingsProvider.select((settings) => settings.homeCategories),
  );
  if (chosen) return stored;
  final ranks = ref.watch(monthlyCategoryRanksProvider).asData?.value;
  if (ranks == null || ranks.isEmpty) return stored;
  return HomeCategories.fromPlayRanks(ranks);
});

/// Podcasts d’une catégorie d’accueil, par catalogue, hors abonnements.
final homeCategoryHitsProvider = FutureProvider.autoDispose
    .family<List<HomeCategoryShelf>, String>((ref, id) async {
      if (!HomeCategories.known.contains(id)) return const [];
      if (ref.watch(onlineStatusProvider) == false) return const [];
      final languages = ref.watch(
        settingsProvider.select((settings) => settings.discoverLanguages),
      );
      final subscribed = await ref.watch(podcastsProvider.future);
      final urls = {
        for (final podcast in subscribed) normalizeFeedUrl(podcast.feedUrl),
      };
      final shelves = await ref
          .read(feedServiceProvider)
          .categoryShelves(id, languages: languages);
      final seen = <String>{};
      final out = <HomeCategoryShelf>[];
      for (final shelf in shelves) {
        final hits = <DiscoverHit>[];
        for (final hit in shelf.hits) {
          final feed = normalizeFeedUrl(hit.feedUrl);
          if (feed.isNotEmpty && urls.contains(feed)) continue;
          if (!seen.add(hit.dedupeKey)) continue;
          hits.add(hit);
          if (hits.length >= 12) break;
        }
        if (hits.isNotEmpty) {
          out.add(HomeCategoryShelf(source: shelf.source, hits: hits));
        }
      }
      return out;
    });

/// Adresse de flux comparable, sans slash final.
String normalizeFeedUrl(String url) {
  var value = url.trim().toLowerCase();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}
