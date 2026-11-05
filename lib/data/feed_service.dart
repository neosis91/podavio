import 'package:podcast_search/podcast_search.dart' as remote;

import 'app_database.dart';
import 'catalog_categories.dart';
import 'chapter_loader.dart';
import 'discover_catalog.dart';
import 'discover_hit.dart';
import 'discover_languages.dart';
import 'feed_refresh.dart';
import 'http_auth.dart';
import 'models.dart';

const podavioUserAgent = 'Podavio/0.1 (podcast player)';

/// Le serveur a répondu 401. [hadCredentials] : un identifiant a déjà été envoyé.
class FeedUnauthorizedException implements Exception {
  const FeedUnauthorizedException({this.hadCredentials = false});

  final bool hadCredentials;

  @override
  String toString() => hadCredentials
      ? 'Exception: Identifiant ou mot de passe refusé.'
      : 'Exception: Ce flux demande un identifiant et un mot de passe.';
}

bool isFeedUnauthorized(Object error) {
  if (error is FeedUnauthorizedException) return true;
  return error is remote.PodcastFailedException && error.statusCode == 401;
}

/// En-têtes à passer aux jaquettes, ou `null` si le podcast n’est pas protégé.
Map<String, String>? podcastAuthHeaders({String? username, String? password}) {
  final headers = podcastRequestHeaders(
    userAgent: podavioUserAgent,
    username: username,
    password: password,
  );
  if (!headers.containsKey('Authorization')) return null;
  return headers;
}

enum DiscoverSearchScope { combined, apple, podcastIndex, fyyd }

/// Abonnement, recherche et chapitres. Le travail est dans [FeedRefresh],
/// [DiscoverCatalog] et [ChapterLoader].
class FeedService {
  FeedService(AppDatabase database) {
    _catalog = DiscoverCatalog(database);
    _refresh = FeedRefresh(database, _catalog);
    _chapters = ChapterLoader(database);
  }

  late final DiscoverCatalog _catalog;
  late final FeedRefresh _refresh;
  late final ChapterLoader _chapters;

  Future<SubscribeResult> subscribe(
    String rawUrl, {
    String? username,
    String? password,
    bool notifyNewEpisodes = false,
  }) {
    return _refresh.subscribe(
      rawUrl,
      username: username,
      password: password,
      notifyNewEpisodes: notifyNewEpisodes,
    );
  }

  /// Charge le flux en aperçu (épisodes utilisables) sans l’ajouter à la bibliothèque.
  Future<int> preview(String rawUrl, {String? username, String? password}) {
    return _refresh.preview(rawUrl, username: username, password: password);
  }

  /// Abonne plusieurs flux en parallèle (réseau), avec une limite de concurrence.
  Future<RefreshReport> subscribeMany(
    List<String> urls, {
    int concurrency = 2,
    void Function(int done, int total, List<SubscribeFailure> failures)?
    onProgress,
  }) {
    return _refresh.subscribeMany(
      urls,
      concurrency: concurrency,
      onProgress: onProgress,
    );
  }

  Future<SavedFeed> refresh(String feedUrl) => _refresh.refresh(feedUrl);

  Future<RefreshReport> refreshAll({
    int concurrency = 2,
    bool notifyNewEpisodes = false,
    Future<void> Function()? beforeEach,
    void Function(int done, int total, List<SubscribeFailure> failures)?
    onProgress,
  }) {
    return _refresh.refreshAll(
      concurrency: concurrency,
      notifyNewEpisodes: notifyNewEpisodes,
      beforeEach: beforeEach,
      onProgress: onProgress,
    );
  }

  Future<remote.SearchResult> search(
    String query, {
    List<String> languages = const [discoverLanguagesAll],
  }) {
    return _catalog.search(query, languages: languages);
  }

  Future<remote.SearchResult> charts({
    List<String> languages = const [discoverLanguagesAll],
  }) {
    return _catalog.charts(languages: languages);
  }

  /// Suggestions combinées (Apple, Podcast Index, fyyd).
  Future<List<DiscoverHit>> discoverCharts({
    int limit = 24,
    List<String> languages = const [discoverLanguagesAll],
  }) {
    return _catalog.discoverCharts(limit: limit, languages: languages);
  }

  /// Une page de suggestions. La page 0 mêle les tops Apple ; les suivantes
  /// avancent dans Podcast Index (top élargi) et fyyd (page suivante).
  Future<List<DiscoverHit>> discoverChartsPage({
    required int page,
    int pageSize = 16,
    List<String> languages = const [discoverLanguagesAll],
  }) {
    return _catalog.discoverChartsPage(
      page: page,
      pageSize: pageSize,
      languages: languages,
    );
  }

  /// Genres les plus présents dans les classements du mois : tops Apple et
  /// tendances Podcast Index des 30 derniers jours.
  Future<List<String>> mostPlayedCategoryIds(List<String> languages) {
    return _catalog.mostPlayedCategoryIds(languages);
  }

  /// Trois rangées pour une catégorie : classements Apple, tendances
  /// Podcast Index, liste fyyd. Une source en échec est absente. Toutes en
  /// échec, la future échoue.
  Future<List<HomeCategoryShelf>> categoryShelves(
    String id, {
    List<String> languages = const [discoverLanguagesAll],
  }) {
    return _catalog.categoryShelves(id, languages: languages);
  }

  /// Une page des podcasts étiquetés dans les sujets choisis d’une catégorie.
  Future<List<DiscoverHit>> categoryHitsPage({
    required String id,
    required int page,
    int pageSize = 20,
    List<String> languages = const [discoverLanguagesAll],
    List<CatalogMember>? subjects,
  }) {
    return _catalog.categoryHitsPage(
      id: id,
      page: page,
      pageSize: pageSize,
      languages: languages,
      subjects: subjects,
    );
  }

  /// Recherche multi-annuaires (Apple, Podcast Index, fyyd).
  Future<List<DiscoverHit>> discoverSearch(
    String query, {
    DiscoverSearchScope scope = DiscoverSearchScope.combined,
    List<String> languages = const [discoverLanguagesAll],
  }) {
    return _catalog.discoverSearch(query, scope: scope, languages: languages);
  }

  /// Resolves the public RSS address when iTunes search omitted it.
  Future<String> feedUrlForAppleShow(int id) =>
      _catalog.feedUrlForAppleShow(id);

  /// Lit les genres des abonnements qui n’en ont pas encore.
  void backfillPodcastCategories(List<Podcast> pending) {
    _catalog.backfillPodcastCategories(pending);
  }

  /// Fetch chapitres encore en cours pour cet épisode.
  bool isChaptersInflight(int episodeId) =>
      _chapters.isChaptersInflight(episodeId);

  /// Dernier fetch a échoué et le backoff empêche un nouvel essai.
  bool chaptersRecentlyFailed(int episodeId) =>
      _chapters.chaptersRecentlyFailed(episodeId);

  /// Charge et mémorise les chapitres Podcast Index d’un épisode (lazy).
  Future<void> ensureChapters(int episodeId) =>
      _chapters.ensureChapters(episodeId);
}

String describeFeedError(Object error) {
  if (error is FeedUnauthorizedException) {
    return error.hadCredentials
        ? 'Identifiant ou mot de passe refusé.'
        : 'Ce flux demande un identifiant et un mot de passe.';
  }
  if (error is remote.PodcastTimeoutException) {
    return 'Délai dépassé';
  }
  if (error is remote.PodcastCertificateException) {
    return 'Certificat HTTPS invalide';
  }
  if (error is remote.PodcastGoneException) {
    return 'Flux supprimé (${error.statusCode})';
  }

  final status = switch (error) {
    remote.PodcastFailedException(:final statusCode) => statusCode,
    remote.PodcastUnknownException(:final statusCode) => statusCode,
    remote.PodcastCancelledException(:final statusCode) => statusCode,
    _ => null,
  };
  if (status != null) {
    return switch (status) {
      404 => 'Flux introuvable (404)',
      410 => 'Flux supprimé (410)',
      401 => 'Accès non autorisé (401)',
      403 => 'Accès refusé (403)',
      408 || 504 => 'Délai dépassé ($status)',
      500 || 502 || 503 => 'Serveur indisponible ($status)',
      _ when status > 0 => 'Erreur HTTP $status',
      _ => 'Impossible de charger le flux',
    };
  }

  final text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  if (text.startsWith('FormatException: ')) return text.substring(17);
  if (text.startsWith('TimeoutException')) {
    return 'Délai dépassé';
  }
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Pas de connexion réseau';
  }
  return text;
}
