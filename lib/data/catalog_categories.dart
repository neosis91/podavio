import 'discover_hit.dart';

/// Sous-genre d’un regroupement (Apple / Podcast Index + fyyd).
class CatalogSubcategory {
  const CatalogSubcategory({required this.genre, required this.fyydId});

  /// Nom transmis à Podcast Index (`cat`), aligné sur Apple.
  final String genre;

  final int fyydId;
}

/// Un sujet interrogeable : genre parent ou sous-genre.
class CatalogMember {
  const CatalogMember({required this.genre, required this.fyydId});

  /// Nom transmis à Apple (`genre`) et à Podcast Index (`cat`).
  final String genre;

  final int fyydId;
}

/// Genre commun aux catalogues (Apple Podcasts, Podcast Index, fyyd).
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.title,
    required this.genre,
    required this.fyydId,
    this.subcategories = const [],
  });

  final String id;

  /// Clé anglaise du libellé, aussi le nom du genre Apple.
  final String title;

  /// Nom transmis à Apple (`genre`) et à Podcast Index (`cat`).
  final String genre;

  final int fyydId;

  /// Sous-genres proposés avec le parent. L’accueil laisse les choisir.
  final List<CatalogSubcategory> subcategories;

  /// Genres PI / Apple : parent puis sous-genres.
  List<String> get regroupGenres => [
    for (final member in regroupMembers) member.genre,
  ];

  /// Identifiants fyyd : parent puis sous-genres.
  List<int> get regroupFyydIds => [
    for (final member in regroupMembers) member.fyydId,
  ];

  /// Parent puis sous-genres, dans l’ordre du catalogue.
  List<CatalogMember> get regroupMembers => [
    CatalogMember(genre: genre, fyydId: fyydId),
    for (final sub in subcategories)
      CatalogMember(genre: sub.genre, fyydId: sub.fyydId),
  ];
}

/// Taxonomie de premier niveau, la même chez Apple, Podcast Index et fyyd.
/// Chaque entrée est un regroupement : parent + sous-catégories.
const catalogCategories = <CatalogCategory>[
  CatalogCategory(
    id: 'comedy',
    title: 'Comedy',
    genre: 'Comedy',
    fyydId: 115,
    subcategories: [
      CatalogSubcategory(genre: 'Comedy Interviews', fyydId: 116),
      CatalogSubcategory(genre: 'Improv', fyydId: 117),
      CatalogSubcategory(genre: 'Stand-Up', fyydId: 118),
    ],
  ),
  CatalogCategory(
    id: 'news',
    title: 'News',
    genre: 'News',
    fyydId: 155,
    subcategories: [
      CatalogSubcategory(genre: 'Business News', fyydId: 156),
      CatalogSubcategory(genre: 'Daily News', fyydId: 157),
      CatalogSubcategory(genre: 'Entertainment News', fyydId: 158),
      CatalogSubcategory(genre: 'News Commentary', fyydId: 159),
      CatalogSubcategory(genre: 'Politics', fyydId: 160),
    ],
  ),
  CatalogCategory(
    id: 'society',
    title: 'Society & Culture',
    genre: 'Society & Culture',
    fyydId: 181,
    subcategories: [
      CatalogSubcategory(genre: 'Documentary', fyydId: 182),
      CatalogSubcategory(genre: 'Personal Journals', fyydId: 183),
      CatalogSubcategory(genre: 'Philosophy', fyydId: 184),
      CatalogSubcategory(genre: 'Relationships', fyydId: 186),
      CatalogSubcategory(genre: 'Social Sciences', fyydId: 180),
    ],
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
    subcategories: [
      CatalogSubcategory(genre: 'Courses', fyydId: 120),
      CatalogSubcategory(genre: 'How To', fyydId: 121),
      CatalogSubcategory(genre: 'Language Learning', fyydId: 122),
      CatalogSubcategory(genre: 'Self-Improvement', fyydId: 123),
    ],
  ),
  CatalogCategory(
    id: 'technology',
    title: 'Technology',
    genre: 'Technology',
    fyydId: 203,
    subcategories: [CatalogSubcategory(genre: 'Tech News', fyydId: 162)],
  ),
  CatalogCategory(
    id: 'business',
    title: 'Business',
    genre: 'Business',
    fyydId: 108,
    subcategories: [
      CatalogSubcategory(genre: 'Careers', fyydId: 109),
      CatalogSubcategory(genre: 'Entrepreneurship', fyydId: 110),
      CatalogSubcategory(genre: 'Investing', fyydId: 111),
      CatalogSubcategory(genre: 'Management', fyydId: 112),
      CatalogSubcategory(genre: 'Marketing', fyydId: 113),
      CatalogSubcategory(genre: 'Non-Profit', fyydId: 114),
    ],
  ),
  CatalogCategory(
    id: 'health',
    title: 'Health & Fitness',
    genre: 'Health & Fitness',
    fyydId: 130,
    subcategories: [
      CatalogSubcategory(genre: 'Alternative Health', fyydId: 131),
      CatalogSubcategory(genre: 'Fitness', fyydId: 132),
      CatalogSubcategory(genre: 'Medicine', fyydId: 133),
      CatalogSubcategory(genre: 'Mental Health', fyydId: 134),
      CatalogSubcategory(genre: 'Nutrition', fyydId: 135),
      CatalogSubcategory(genre: 'Sexuality', fyydId: 136),
    ],
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
    subcategories: [
      CatalogSubcategory(genre: 'Astronomy', fyydId: 172),
      CatalogSubcategory(genre: 'Chemistry', fyydId: 173),
      CatalogSubcategory(genre: 'Earth Sciences', fyydId: 174),
      CatalogSubcategory(genre: 'Life Sciences', fyydId: 175),
      CatalogSubcategory(genre: 'Mathematics', fyydId: 176),
      CatalogSubcategory(genre: 'Natural Sciences', fyydId: 177),
      CatalogSubcategory(genre: 'Physics', fyydId: 179),
    ],
  ),
  CatalogCategory(
    id: 'sports',
    title: 'Sports',
    genre: 'Sports',
    fyydId: 187,
    subcategories: [
      CatalogSubcategory(genre: 'Baseball', fyydId: 188),
      CatalogSubcategory(genre: 'Basketball', fyydId: 189),
      CatalogSubcategory(genre: 'Cricket', fyydId: 190),
      CatalogSubcategory(genre: 'Fantasy Sports', fyydId: 191),
      CatalogSubcategory(genre: 'Football', fyydId: 192),
      CatalogSubcategory(genre: 'Golf', fyydId: 193),
      CatalogSubcategory(genre: 'Hockey', fyydId: 194),
      CatalogSubcategory(genre: 'Rugby', fyydId: 195),
      CatalogSubcategory(genre: 'Running', fyydId: 196),
      CatalogSubcategory(genre: 'Soccer', fyydId: 197),
      CatalogSubcategory(genre: 'Swimming', fyydId: 198),
      CatalogSubcategory(genre: 'Tennis', fyydId: 199),
      CatalogSubcategory(genre: 'Sports News', fyydId: 161),
      CatalogSubcategory(genre: 'Volleyball', fyydId: 200),
      CatalogSubcategory(genre: 'Wrestling', fyydId: 202),
    ],
  ),
  CatalogCategory(
    id: 'music',
    title: 'Music',
    genre: 'Music',
    fyydId: 151,
    subcategories: [
      CatalogSubcategory(genre: 'Music Commentary', fyydId: 152),
      CatalogSubcategory(genre: 'Music History', fyydId: 153),
      CatalogSubcategory(genre: 'Music Interviews', fyydId: 154),
    ],
  ),
  CatalogCategory(
    id: 'tvFilm',
    title: 'TV & Film',
    genre: 'TV & Film',
    fyydId: 205,
    subcategories: [
      CatalogSubcategory(genre: 'After Shows', fyydId: 206),
      CatalogSubcategory(genre: 'Film History', fyydId: 207),
      CatalogSubcategory(genre: 'Film Interviews', fyydId: 208),
      CatalogSubcategory(genre: 'Animation & Manga', fyydId: 143),
      CatalogSubcategory(genre: 'Film Reviews', fyydId: 209),
      CatalogSubcategory(genre: 'TV Reviews', fyydId: 210),
    ],
  ),
  CatalogCategory(
    id: 'arts',
    title: 'Arts',
    genre: 'Arts',
    fyydId: 100,
    subcategories: [
      CatalogSubcategory(genre: 'Books', fyydId: 102),
      CatalogSubcategory(genre: 'Design', fyydId: 103),
      CatalogSubcategory(genre: 'Fashion & Beauty', fyydId: 104),
      CatalogSubcategory(genre: 'Performing Arts', fyydId: 106),
      CatalogSubcategory(genre: 'Visual Arts', fyydId: 107),
    ],
  ),
  CatalogCategory(
    id: 'kids',
    title: 'Kids & Family',
    genre: 'Kids & Family',
    fyydId: 137,
    subcategories: [
      CatalogSubcategory(genre: 'Education for Kids', fyydId: 138),
      CatalogSubcategory(genre: 'Parenting', fyydId: 139),
      CatalogSubcategory(genre: 'Stories for Kids', fyydId: 141),
    ],
  ),
  CatalogCategory(
    id: 'leisure',
    title: 'Leisure',
    genre: 'Leisure',
    fyydId: 142,
    subcategories: [
      CatalogSubcategory(genre: 'Automotive', fyydId: 144),
      CatalogSubcategory(genre: 'Aviation', fyydId: 145),
      CatalogSubcategory(genre: 'Crafts', fyydId: 146),
      CatalogSubcategory(genre: 'Hobbies', fyydId: 148),
      CatalogSubcategory(genre: 'Home & Garden', fyydId: 149),
      CatalogSubcategory(genre: 'Wilderness', fyydId: 201),
    ],
  ),
  CatalogCategory(
    id: 'religion',
    title: 'Religion & Spirituality',
    genre: 'Religion & Spirituality',
    fyydId: 163,
    subcategories: [
      CatalogSubcategory(genre: 'Buddhism', fyydId: 164),
      CatalogSubcategory(genre: 'Christianity', fyydId: 165),
      CatalogSubcategory(genre: 'Hinduism', fyydId: 166),
      CatalogSubcategory(genre: 'Islam', fyydId: 167),
      CatalogSubcategory(genre: 'Judaism', fyydId: 168),
      CatalogSubcategory(genre: 'Religion', fyydId: 169),
      CatalogSubcategory(genre: 'Spirituality', fyydId: 170),
    ],
  ),
  CatalogCategory(
    id: 'fiction',
    title: 'Fiction',
    genre: 'Fiction',
    fyydId: 124,
    subcategories: [
      CatalogSubcategory(genre: 'Comedy Fiction', fyydId: 125),
      CatalogSubcategory(genre: 'Drama', fyydId: 126),
      CatalogSubcategory(genre: 'Science Fiction', fyydId: 127),
    ],
  ),
  CatalogCategory(
    id: 'government',
    title: 'Government',
    genre: 'Government',
    fyydId: 128,
  ),
  CatalogCategory(id: 'food', title: 'Food', genre: 'Food', fyydId: 105),
  CatalogCategory(
    id: 'games',
    title: 'Games',
    genre: 'Games',
    fyydId: 147,
    subcategories: [CatalogSubcategory(genre: 'Video Games', fyydId: 150)],
  ),
  CatalogCategory(
    id: 'nature',
    title: 'Nature',
    genre: 'Nature',
    fyydId: 178,
    subcategories: [CatalogSubcategory(genre: 'Pets & Animals', fyydId: 140)],
  ),
  CatalogCategory(
    id: 'travel',
    title: 'Places & Travel',
    genre: 'Places & Travel',
    fyydId: 185,
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
  1306: 'food',
  1309: 'tvFilm',
  1310: 'music',
  1314: 'religion',
  1318: 'technology',
  1320: 'travel',
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
  1503: 'tvFilm',
  1504: 'leisure',
  1505: 'leisure',
  1506: 'leisure',
  1507: 'games',
  1508: 'leisure',
  1509: 'leisure',
  1510: 'games',
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
  1521: 'nature',
  1522: 'kids',
  1523: 'music',
  1524: 'music',
  1525: 'music',
  1526: 'news',
  1527: 'news',
  1528: 'news',
  1529: 'news',
  1530: 'sports',
  1531: 'technology',
  1532: 'religion',
  1533: 'science',
  1534: 'science',
  1535: 'science',
  1536: 'science',
  1537: 'science',
  1538: 'science',
  1539: 'science',
  1540: 'nature',
  1541: 'science',
  1542: 'society',
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
  1559: 'leisure',
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
  'Animation & Manga': 'tvFilm',
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
  'Food': 'food',
  'Football': 'sports',
  'Games': 'games',
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
  'Nature': 'nature',
  'News': 'news',
  'News Commentary': 'news',
  'Non-Profit': 'business',
  'Nutrition': 'health',
  'Parenting': 'kids',
  'Performing Arts': 'arts',
  'Personal Journals': 'society',
  'Pets & Animals': 'nature',
  'Philosophy': 'society',
  'Physics': 'science',
  'Places & Travel': 'travel',
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
  'Social Sciences': 'society',
  'Society & Culture': 'society',
  'Spirituality': 'religion',
  'Sports': 'sports',
  'Sports News': 'sports',
  'Stand-Up': 'comedy',
  'Stories for Kids': 'kids',
  'Swimming': 'sports',
  'TV & Film': 'tvFilm',
  'TV Reviews': 'tvFilm',
  'Tech News': 'technology',
  'Technology': 'technology',
  'Tennis': 'sports',
  'True Crime': 'trueCrime',
  'Video Games': 'games',
  'Visual Arts': 'arts',
  'Volleyball': 'sports',
  'Wilderness': 'leisure',
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

/// Tous les sujets, parents puis sous-genres, dans l’ordre du catalogue.
List<CatalogMember> get allCatalogMembers => [
  for (final category in catalogCategories) ...category.regroupMembers,
];

CatalogMember? catalogMemberByGenre(String genre) {
  for (final member in allCatalogMembers) {
    if (member.genre == genre) return member;
  }
  return null;
}

/// Sujets affichés pour une catégorie. [chosenGenres] absent : le regroupement.
/// Un choix enregistré ne garde que des genres encore connus, dans l’ordre
/// du catalogue. S’il ne reste rien, le genre parent.
List<CatalogMember> enabledSubjects(
  String categoryId,
  List<String>? chosenGenres,
) {
  final category = catalogCategoryById(categoryId);
  if (category == null) return const [];
  if (chosenGenres == null) return category.regroupMembers;
  final wanted = chosenGenres.toSet();
  final picked = [
    for (final member in allCatalogMembers)
      if (wanted.contains(member.genre)) member,
  ];
  if (picked.isNotEmpty) return picked;
  return [CatalogMember(genre: category.genre, fyydId: category.fyydId)];
}

/// Étiquettes fyyd qui sortent un podcast du sujet Histoire,
/// même quand 129 est aussi présent.
const historyExcludedFyydIds = <int>{
  102, // Books
  103, // Design
  104, // Fashion & Beauty
  105, // Food
  106, // Performing Arts
  107, // Visual Arts
  108, 109, 110, 111, 112, 113, 114, // Business
  115, 116, 117, 118, // Comedy
  124, 125, 126, 127, // Fiction
  130, 131, 132, 133, 134, 135, 136, // Health
  137, 138, 139, 140, 141, // Kids & Family
  142, 143, 144, 145, 146, 147, 148, 149, 150, // Leisure, games
  151, 152, 153, 154, // Music
  183, // Personal Journals
  185, // Places & Travel
  186, // Relationships
  187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201,
  202, // Sports
  204, // True Crime
  205, 206, 207, 208, 209, 210, // TV & Film
};

/// Un podcast de la catégorie fyyd Histoire (129).
///
/// 129 doit être le premier identifiant : un magazine scientifique qui
/// mentionne aussi l’histoire ne compte pas. Les étiquettes d’un autre
/// domaine (enfants, fiction, musique, sport, loisirs…) l’écartent.
bool fyydHistoryCategoriesStay(List<int> ids) {
  if (ids.isEmpty) return true;
  if (ids.first != 129) return false;
  for (final id in ids) {
    if (historyExcludedFyydIds.contains(id)) return false;
  }
  return true;
}

/// Noms Podcast Index, en minuscules, qui ne sont pas des sujets historiques.
const historyExcludedPodcastIndexNames = <String>{
  'kids',
  'kids & family',
  'family',
  'stories',
  'stories for kids',
  'fiction',
  'comedy',
  'comedy fiction',
  'drama',
  'science fiction',
  'true crime',
  'music',
  'music commentary',
  'music history',
  'music interviews',
  'leisure',
  'hobbies',
  'games',
  'video games',
  'animation & manga',
  'sports',
  'arts',
  'books',
  'design',
  'fashion & beauty',
  'food',
  'performing arts',
  'visual arts',
  'technology',
  'tech news',
  'health & fitness',
  'health',
  'fitness',
  'medicine',
  'business',
  'tv & film',
  'film',
  'personal journals',
  'places & travel',
  'relationships',
  'automotive',
  'aviation',
  'crafts',
  'home & garden',
  'wilderness',
};

/// Un podcast tendance Podcast Index demandé pour History.
///
/// Sans catégories, on le garde : le filtre `cat` a déjà choisi History.
/// Sinon History doit figurer, sans une étiquette d’un autre domaine
/// (histoires pour enfants, musique, true crime, livres audio…).
bool podcastIndexHistoryCategoriesStay(Iterable<String> names) {
  final lower = <String>{
    for (final name in names)
      if (name.trim().isNotEmpty) name.trim().toLowerCase(),
  };
  if (lower.isEmpty) return true;
  if (!lower.contains('history')) return false;
  for (final name in lower) {
    if (historyExcludedPodcastIndexNames.contains(name)) return false;
  }
  return true;
}
