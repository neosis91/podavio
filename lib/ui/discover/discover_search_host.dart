import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/discover_providers.dart';
import '../../data/feed_service.dart';
import '../podcasts_page.dart';

const discoverSearchDebounce = Duration(milliseconds: 450);

bool looksLikeFeedUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  return uri != null &&
      (uri.isScheme('http') || uri.isScheme('https')) &&
      uri.host.isNotEmpty;
}

/// AppBar search partagée (Explorer + Suggestions).
mixin DiscoverSearchHost<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final searchController = TextEditingController();
  final searchFocus = FocusNode();
  var searching = false;
  var query = '';
  var searchScope = DiscoverSearchScope.combined;
  Timer? _debounce;

  /// Lancer la recherche distante (scope déjà appliqué côté hôte si besoin).
  Future<void> runDiscoverSearch(String query);

  void disposeSearchHost() {
    _debounce?.cancel();
    searchController.dispose();
    searchFocus.dispose();
  }

  void openSearch({
    DiscoverSearchScope scope = DiscoverSearchScope.combined,
  }) {
    setState(() {
      searching = true;
      searchScope = scope;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) searchFocus.requestFocus();
    });
  }

  void closeSearch() {
    _debounce?.cancel();
    searchController.clear();
    ref.read(discoverSearchProvider.notifier).clear();
    setState(() {
      searching = false;
      query = '';
      searchScope = DiscoverSearchScope.combined;
    });
  }

  void onQueryChanged(String value) {
    setState(() => query = value);
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      ref.read(discoverSearchProvider.notifier).clear();
      return;
    }
    if (looksLikeFeedUrl(trimmed)) return;

    _debounce = Timer(discoverSearchDebounce, () {
      if (!mounted) return;
      if (searchController.text.trim() != trimmed) return;
      runDiscoverSearch(trimmed);
    });
  }

  void clearQueryOrClose() {
    if (query.isEmpty) {
      closeSearch();
      return;
    }
    _debounce?.cancel();
    searchController.clear();
    ref.read(discoverSearchProvider.notifier).clear();
    setState(() => query = '');
  }

  Future<void> onSearchSubmitted(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (looksLikeFeedUrl(trimmed)) {
      await openPodcastFromFeedUrl(context, ref, trimmed);
      return;
    }
    await runDiscoverSearch(trimmed);
  }

  void cancelDebounce() => _debounce?.cancel();

  String get searchHint {
    return switch (searchScope) {
      DiscoverSearchScope.combined => 'Rechercher un podcast',
      DiscoverSearchScope.apple => 'Rechercher sur Apple Podcasts',
      DiscoverSearchScope.podcastIndex => 'Rechercher sur Podcast Index',
      DiscoverSearchScope.fyyd => 'Rechercher sur fyyd',
    };
  }
}
