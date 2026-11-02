import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import 'app_database.dart';
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
    ref.watch(podcastsProvider.select(_subscribedFeedsKey));
    ref.listen(onlineStatusProvider, (previous, next) {
      if (previous == false && next == true) unawaited(reload());
    });
    ref.listen(podcastsProvider, (previous, next) {
      next.whenData(_dropSubscribedFromState);
    });
    _generation++;
    if (ref.read(onlineStatusProvider) == false) {
      return Future.value(const DiscoverCharts(hasMore: false));
    }
    return _loadFirst();
  }

  void _dropSubscribedFromState(List<Podcast> podcasts) {
    final current = state.asData?.value;
    if (current == null || current.hits.isEmpty) return;
    final urls = subscribedFeedUrls(podcasts);
    final kept = [
      for (final hit in current.hits)
        if (!isSubscribedDiscoverHit(hit, urls)) hit,
    ];
    if (kept.length == current.hits.length) return;
    state = AsyncData(current.copyWith(hits: kept));
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
    final urls = subscribedFeedUrls(
      ref.read(podcastsProvider).asData?.value ?? const [],
    );
    final fresh = <DiscoverHit>[];
    for (final hit in merged) {
      if (isSubscribedDiscoverHit(hit, urls)) continue;
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
  Future<List<DiscoverHit>?> build() async {
    ref.listen(podcastsProvider, (previous, next) {
      next.whenData((podcasts) {
        final current = state.asData?.value;
        if (current == null || current.isEmpty) return;
        final urls = subscribedFeedUrls(podcasts);
        final kept = [
          for (final hit in current)
            if (!isSubscribedDiscoverHit(hit, urls)) hit,
        ];
        if (kept.length == current.length) return;
        state = AsyncData(kept);
      });
    });
    return null;
  }

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
    final next = await AsyncValue.guard(() async {
      final hits = await ref
          .read(feedServiceProvider)
          .discoverSearch(trimmed, scope: scope, languages: languages);
      final urls = subscribedFeedUrls(
        ref.read(podcastsProvider).asData?.value ?? const [],
      );
      return [
        for (final hit in hits)
          if (!isSubscribedDiscoverHit(hit, urls)) hit,
      ];
    });
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

const categorySubjectsKey = 'categorySubjects';

/// Sujets choisis par catégorie d’accueil. Absent : le regroupement par défaut.
final categorySubjectsProvider =
    NotifierProvider<CategorySubjectsNotifier, Map<String, List<String>>>(
      CategorySubjectsNotifier.new,
    );

class CategorySubjectsNotifier extends Notifier<Map<String, List<String>>> {
  @override
  Map<String, List<String>> build() {
    return _decode(
      ref.watch(sharedPreferencesProvider).getStringList(categorySubjectsKey),
    );
  }

  /// Remplace les sujets d’une catégorie. Une liste vide est ignorée.
  Future<void> setEnabled(String categoryId, Set<String> genres) async {
    if (catalogCategoryById(categoryId) == null) return;
    final enabled = [
      for (final member in allCatalogMembers)
        if (genres.contains(member.genre)) member.genre,
    ];
    if (enabled.isEmpty) return;
    final next = {...state, categoryId: enabled};
    state = next;
    await ref.read(sharedPreferencesProvider).setStringList(
      categorySubjectsKey,
      [
        for (final entry in next.entries)
          for (final genre in entry.value) '${entry.key}\u0001$genre',
      ],
    );
  }

  static Map<String, List<String>> _decode(List<String>? raw) {
    final out = <String, List<String>>{};
    if (raw == null) return out;
    for (final line in raw) {
      final split = line.split('\u0001');
      if (split.length != 2) continue;
      final id = split[0];
      final genre = split[1];
      if (catalogCategoryById(id) == null) continue;
      if (catalogMemberByGenre(genre) == null) continue;
      (out[id] ??= []).add(genre);
    }
    return out;
  }
}

/// Podcasts d’une catégorie d’accueil (liste plate paginée, hors abonnements).
final homeCategoryHitsProvider = AsyncNotifierProvider.autoDispose
    .family<HomeCategoryHitsNotifier, DiscoverCharts, String>(
      HomeCategoryHitsNotifier.new,
    );

class HomeCategoryHitsNotifier extends AsyncNotifier<DiscoverCharts> {
  HomeCategoryHitsNotifier(this.categoryId);

  final String categoryId;

  static const pageSize = 20;
  static const firstBatch = 24;
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
    ref.watch(podcastsProvider.select(_subscribedFeedsKey));
    ref.watch(
      categorySubjectsProvider.select(
        (stored) => enabledSubjects(
          categoryId,
          stored[categoryId],
        ).map((member) => member.genre).join('\u0001'),
      ),
    );
    ref.listen(onlineStatusProvider, (previous, next) {
      if (previous == false && next == true) unawaited(reload());
    });
    ref.listen(podcastsProvider, (previous, next) {
      next.whenData(_dropSubscribedFromState);
    });
    _generation++;
    if (!HomeCategories.known.contains(categoryId)) {
      return Future.value(const DiscoverCharts(hasMore: false));
    }
    if (ref.read(onlineStatusProvider) == false) {
      return Future.value(const DiscoverCharts(hasMore: false));
    }
    return _loadFirst();
  }

  void _dropSubscribedFromState(List<Podcast> podcasts) {
    final current = state.asData?.value;
    if (current == null || current.hits.isEmpty) return;
    final urls = subscribedFeedUrls(podcasts);
    final kept = [
      for (final hit in current.hits)
        if (!isSubscribedDiscoverHit(hit, urls)) hit,
    ];
    if (kept.length == current.hits.length) return;
    state = AsyncData(current.copyWith(hits: kept));
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
      // Une page peut ne renvoyer que des doublons déjà vus : on enchaîne
      // sur d’autres membres du regroupement avant d’abandonner.
      final members = enabledSubjects(
        categoryId,
        ref.read(categorySubjectsProvider)[categoryId],
      );
      final maxAttempts = (members.length * 2).clamp(2, 16);
      var fresh = <DiscoverHit>[];
      for (var i = 0; i < maxAttempts && _page < _maxPages; i++) {
        fresh = await _fetchFresh();
        if (gen != _generation) return;
        if (fresh.isNotEmpty) break;
      }
      if (gen != _generation) return;
      final latest = state.asData?.value ?? current;
      final hasMore = fresh.isNotEmpty && _page < _maxPages;
      state = AsyncData(
        latest.copyWith(
          hits: fresh.isEmpty ? latest.hits : [...latest.hits, ...fresh],
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
    final subjects = enabledSubjects(
      categoryId,
      ref.read(categorySubjectsProvider)[categoryId],
    );
    final merged = await ref
        .read(feedServiceProvider)
        .categoryHitsPage(
          id: categoryId,
          page: page,
          pageSize: pageSize,
          languages: languages,
          subjects: subjects,
        );
    if (gen != _generation) return const [];
    _page = page + 1;
    final urls = subscribedFeedUrls(
      ref.read(podcastsProvider).asData?.value ?? const [],
    );
    final fresh = <DiscoverHit>[];
    for (final hit in merged) {
      if (isSubscribedDiscoverHit(hit, urls)) continue;
      if (_seen.add(hit.dedupeKey)) fresh.add(hit);
    }
    return fresh;
  }
}

/// Adresse de flux comparable, sans slash final.
String normalizeFeedUrl(String url) {
  var value = url.trim().toLowerCase();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

Set<String> subscribedFeedUrls(Iterable<Podcast> podcasts) {
  return {
    for (final podcast in podcasts)
      if (podcast.feedUrl.trim().isNotEmpty) normalizeFeedUrl(podcast.feedUrl),
  };
}

bool isSubscribedDiscoverHit(DiscoverHit hit, Set<String> subscribedUrls) {
  final feed = normalizeFeedUrl(hit.feedUrl);
  return feed.isNotEmpty && subscribedUrls.contains(feed);
}

String _subscribedFeedsKey(AsyncValue<List<Podcast>> async) {
  final podcasts = async.asData?.value;
  if (podcasts == null || podcasts.isEmpty) return '';
  final urls = subscribedFeedUrls(podcasts).toList()..sort();
  return urls.join('\u0001');
}
