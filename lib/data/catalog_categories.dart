import 'discover_hit.dart';

/// Genre commun aux catalogues (Apple Podcasts, Podcast Index, fyyd).
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.title,
    required this.genre,
    required this.fyydId,
  });

  final String id;

  /// Clé anglaise du libellé, aussi le nom du genre Apple.
  final String title;

  /// Nom transmis à Apple (`genre`) et à Podcast Index (`cat`).
  final String genre;

  final int fyydId;
}

/// Taxonomie de premier niveau, la même chez Apple, Podcast Index et fyyd.
const catalogCategories = <CatalogCategory>[
  CatalogCategory(id: 'comedy', title: 'Comedy', genre: 'Comedy', fyydId: 115),
  CatalogCategory(id: 'news', title: 'News', genre: 'News', fyydId: 155),
  CatalogCategory(
    id: 'society',
    title: 'Society & Culture',
    genre: 'Society & Culture',
    fyydId: 181,
  ),
  CatalogCategory(
    id: 'trueCrime',
    title: 'True Crime',
    genre: 'True Crime',
    fyydId: 204,
  ),
  CatalogCategory(
    id: 'education',
    title: 'Education',
    genre: 'Education',
    fyydId: 119,
  ),
  CatalogCategory(
    id: 'technology',
    title: 'Technology',
    genre: 'Technology',
    fyydId: 203,
  ),
  CatalogCategory(
    id: 'business',
    title: 'Business',
    genre: 'Business',
    fyydId: 108,
  ),
  CatalogCategory(
    id: 'health',
    title: 'Health & Fitness',
    genre: 'Health & Fitness',
    fyydId: 130,
  ),
  CatalogCategory(
    id: 'history',
    title: 'History',
    genre: 'History',
    fyydId: 129,
  ),
  CatalogCategory(
    id: 'science',
    title: 'Science',
    genre: 'Science',
    fyydId: 171,
  ),
  CatalogCategory(id: 'sports', title: 'Sports', genre: 'Sports', fyydId: 187),
  CatalogCategory(id: 'music', title: 'Music', genre: 'Music', fyydId: 151),
  CatalogCategory(
    id: 'tvFilm',
    title: 'TV & Film',
    genre: 'TV & Film',
    fyydId: 205,
  ),
  CatalogCategory(id: 'arts', title: 'Arts', genre: 'Arts', fyydId: 100),
  CatalogCategory(
    id: 'kids',
    title: 'Kids & Family',
    genre: 'Kids & Family',
    fyydId: 137,
  ),
  CatalogCategory(
    id: 'leisure',
    title: 'Leisure',
    genre: 'Leisure',
    fyydId: 142,
  ),
  CatalogCategory(
    id: 'religion',
    title: 'Religion & Spirituality',
    genre: 'Religion & Spirituality',
    fyydId: 163,
  ),
  CatalogCategory(
    id: 'fiction',
    title: 'Fiction',
    genre: 'Fiction',
    fyydId: 124,
  ),
  CatalogCategory(
    id: 'government',
    title: 'Government',
    genre: 'Government',
    fyydId: 128,
  ),
];

CatalogCategory? catalogCategoryById(String id) {
  for (final category in catalogCategories) {
    if (category.id == id) return category;
  }
  return null;
}

/// Clé anglaise du titre d’une catégorie d’accueil.
String homeCategoryTitle(String id) => catalogCategoryById(id)?.title ?? id;

/// Une rangée de la page catégorie, issue d’un seul catalogue.
class HomeCategoryShelf {
  const HomeCategoryShelf({required this.source, required this.hits});

  final DiscoverSource source;
  final List<DiscoverHit> hits;
}

/// Identifiant Apple (y compris les sous-genres) → catégorie d’accueil.
const appleGenreCatalogIds = <int, String>{
  1301: 'arts',
  1302: 'society',
  1303: 'comedy',
  1304: 'education',
  1305: 'kids',
  1306: 'arts',
  1309: 'tvFilm',
  1310: 'music',
  1314: 'religion',
  1318: 'technology',
  1320: 'society',
  1321: 'business',
  1324: 'society',
  1402: 'arts',
  1405: 'arts',
  1406: 'arts',
  1410: 'business',
  1412: 'business',
  1438: 'religion',
  1439: 'religion',
  1440: 'religion',
  1441: 'religion',
  1443: 'society',
  1444: 'religion',
  1459: 'arts',
  1463: 'religion',
  1482: 'arts',
  1483: 'fiction',
  1484: 'fiction',
  1485: 'fiction',
  1486: 'fiction',
  1487: 'history',
  1488: 'trueCrime',
  1489: 'news',
  1490: 'news',
  1491: 'business',
  1492: 'business',
  1493: 'business',
  1494: 'business',
  1495: 'comedy',
  1496: 'comedy',
  1497: 'comedy',
  1498: 'education',
  1499: 'education',
  1500: 'education',
  1501: 'education',
  1502: 'leisure',
  1503: 'leisure',
  1504: 'leisure',
  1505: 'leisure',
  1506: 'leisure',
  1507: 'leisure',
  1508: 'leisure',
  1509: 'leisure',
  1510: 'leisure',
  1511: 'government',
  1512: 'health',
  1513: 'health',
  1514: 'health',
  1515: 'health',
  1516: 'health',
  1517: 'health',
  1518: 'health',
  1519: 'kids',
  1520: 'kids',
  1521: 'kids',
  1522: 'kids',
  1523: 'music',
  1524: 'music',
  1525: 'music',
  1526: 'news',
  1527: 'news',
  1528: 'news',
  1529: 'news',
  1530: 'news',
  1531: 'news',
  1532: 'religion',
  1533: 'science',
  1534: 'science',
  1535: 'science',
  1536: 'science',
  1537: 'science',
  1538: 'science',
  1539: 'science',
  1540: 'science',
  1541: 'science',
  1542: 'science',
  1543: 'society',
  1544: 'society',
  1545: 'sports',
  1546: 'sports',
  1547: 'sports',
  1548: 'sports',
  1549: 'sports',
  1550: 'sports',
  1551: 'sports',
  1552: 'sports',
  1553: 'sports',
  1554: 'sports',
  1555: 'sports',
  1556: 'sports',
  1557: 'sports',
  1558: 'sports',
  1559: 'sports',
  1560: 'sports',
  1561: 'tvFilm',
  1562: 'tvFilm',
  1563: 'tvFilm',
  1564: 'tvFilm',
  1565: 'tvFilm',
};

/// Nom de genre Apple ou Podcast Index → catégorie d’accueil.
const genreNameCatalogIds = <String, String>{
  'After Shows': 'tvFilm',
  'Alternative Health': 'health',
  'Animation & Manga': 'leisure',
  'Arts': 'arts',
  'Astronomy': 'science',
  'Automotive': 'leisure',
  'Aviation': 'leisure',
  'Baseball': 'sports',
  'Basketball': 'sports',
  'Books': 'arts',
  'Buddhism': 'religion',
  'Business': 'business',
  'Business News': 'news',
  'Careers': 'business',
  'Chemistry': 'science',
  'Christianity': 'religion',
  'Comedy': 'comedy',
  'Comedy Fiction': 'fiction',
  'Comedy Interviews': 'comedy',
  'Courses': 'education',
  'Crafts': 'leisure',
  'Cricket': 'sports',
  'Daily News': 'news',
  'Design': 'arts',
  'Documentary': 'society',
  'Drama': 'fiction',
  'Earth Sciences': 'science',
  'Education': 'education',
  'Education for Kids': 'kids',
  'Entertainment News': 'news',
  'Entrepreneurship': 'business',
  'Fantasy Sports': 'sports',
  'Fashion & Beauty': 'arts',
  'Fiction': 'fiction',
  'Film History': 'tvFilm',
  'Film Interviews': 'tvFilm',
  'Film Reviews': 'tvFilm',
  'Fitness': 'health',
  'Food': 'arts',
  'Football': 'sports',
  'Games': 'leisure',
  'Golf': 'sports',
  'Government': 'government',
  'Health & Fitness': 'health',
  'Hinduism': 'religion',
  'History': 'history',
  'Hobbies': 'leisure',
  'Hockey': 'sports',
  'Home & Garden': 'leisure',
  'How To': 'education',
  'Improv': 'comedy',
  'Investing': 'business',
  'Islam': 'religion',
  'Judaism': 'religion',
  'Kids & Family': 'kids',
  'Language Learning': 'education',
  'Leisure': 'leisure',
  'Life Sciences': 'science',
  'Management': 'business',
  'Marketing': 'business',
  'Mathematics': 'science',
  'Medicine': 'health',
  'Mental Health': 'health',
  'Music': 'music',
  'Music Commentary': 'music',
  'Music History': 'music',
  'Music Interviews': 'music',
  'Natural Sciences': 'science',
  'Nature': 'science',
  'News': 'news',
  'News Commentary': 'news',
  'Non-Profit': 'business',
  'Nutrition': 'health',
  'Parenting': 'kids',
  'Performing Arts': 'arts',
  'Personal Journals': 'society',
  'Pets & Animals': 'kids',
  'Philosophy': 'society',
  'Physics': 'science',
  'Places & Travel': 'society',
  'Politics': 'news',
  'Relationships': 'society',
  'Religion': 'religion',
  'Religion & Spirituality': 'religion',
  'Rugby': 'sports',
  'Running': 'sports',
  'Science': 'science',
  'Science Fiction': 'fiction',
  'Self-Improvement': 'education',
  'Sexuality': 'health',
  'Soccer': 'sports',
  'Social Sciences': 'science',
  'Society & Culture': 'society',
  'Spirituality': 'religion',
  'Sports': 'sports',
  'Sports News': 'news',
  'Stand-Up': 'comedy',
  'Stories for Kids': 'kids',
  'Swimming': 'sports',
  'TV & Film': 'tvFilm',
  'TV Reviews': 'tvFilm',
  'Tech News': 'news',
  'Technology': 'technology',
  'Tennis': 'sports',
  'True Crime': 'trueCrime',
  'Video Games': 'leisure',
  'Visual Arts': 'arts',
  'Volleyball': 'sports',
  'Wilderness': 'sports',
  'Wrestling': 'sports',
};

/// Nombre de pastilles prises dans le classement du mois, avant Histoire.
const monthlyHomeCategoryCount = 8;

/// Histoire reste affichée : choix de départ, même si le mois la classe plus loin.
const pinnedHomeCategoryId = 'history';

String? catalogIdFromAppleCategory(Object? category) {
  final nodes = category is List ? category : <Object?>[category];
  for (final node in nodes) {
    if (node is! Map) continue;
    final attributes = node['attributes'];
    if (attributes is! Map) continue;
    final parsed = int.tryParse('${attributes['im:id']}');
    if (parsed == null) continue;
    final id = appleGenreCatalogIds[parsed];
    if (id != null) return id;
  }
  return null;
}

/// Identifiants de catégories présents dans un flux « top podcasts » Apple.
List<String> catalogIdsFromAppleChart(Object? json) {
  if (json is! Map) return const [];
  final feed = json['feed'];
  if (feed is! Map) return const [];
  final entry = feed['entry'];
  final entries = entry is List
      ? entry
      : entry is Map
      ? [entry]
      : const <Object?>[];
  final ids = <String>[];
  for (final raw in entries) {
    if (raw is! Map) continue;
    final id = catalogIdFromAppleCategory(raw['category']);
    if (id != null) ids.add(id);
  }
  return ids;
}

String? catalogIdFromGenreName(String name) => genreNameCatalogIds[name.trim()];

/// Du plus cité au moins cité. Les égalités suivent [catalogCategories].
List<String> rankPlayedCategories(Iterable<String> catalogIds) {
  final counts = <String, int>{};
  for (final id in catalogIds) {
    if (catalogCategoryById(id) == null) continue;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  final order = {
    for (final (index, category) in catalogCategories.indexed)
      category.id: index,
  };
  final ranked = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      return order[a]!.compareTo(order[b]!);
    });
  return ranked;
}

String monthlyCategoryRankStamp(List<String> languages, DateTime now) {
  final codes = [...languages]..sort();
  final month = now.month.toString().padLeft(2, '0');
  return '${now.year}-$month|${codes.join(',')}';
}

/// `null` si le cache est d’un autre mois, d’une autre langue, ou a plus de sept jours.
List<String>? readMonthlyCategoryRanks({
  required String? stored,
  required int? storedAtMillis,
  required List<String> languages,
  required DateTime now,
}) {
  if (stored == null || storedAtMillis == null) return null;
  final parts = stored.split('|');
  if (parts.length != 3) return null;
  final stamp = monthlyCategoryRankStamp(languages, now);
  if ('${parts[0]}|${parts[1]}' != stamp) return null;
  final storedAt = DateTime.fromMillisecondsSinceEpoch(storedAtMillis);
  final age = now.difference(storedAt);
  if (age.isNegative || age > const Duration(days: 7)) return null;
  return [
    for (final id in parts[2].split(','))
      if (catalogCategoryById(id) != null) id,
  ];
}

String writeMonthlyCategoryRanks({
  required List<String> languages,
  required List<String> ranks,
  required DateTime now,
}) {
  final ids = [
    for (final id in ranks)
      if (catalogCategoryById(id) != null) id,
  ];
  return '${monthlyCategoryRankStamp(languages, now)}|${ids.join(',')}';
}
