import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'discover_hit.dart';
import 'feed_service.dart';
import 'providers.dart';

/// Tendances combinées (grille « suggestions »).
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
    state = const AsyncLoading();
    final next = await AsyncValue.guard(
      () => ref
          .read(feedServiceProvider)
          .discoverSearch(trimmed, scope: scope),
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
