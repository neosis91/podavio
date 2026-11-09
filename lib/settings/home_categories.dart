import '../data/catalog_categories.dart';

/// Pastilles de catégories sur l’accueil, dans l’ordre d’affichage.
/// Un identifiant précédé de `-` est masqué. La pastille « Tout » n’en fait
/// pas partie : elle reste toujours là.
class HomeCategories {
  const HomeCategories({this.order = known, this.enabled = _defaultEnabled});

  static const known = [
    'comedy',
    'news',
    'society',
    'trueCrime',
    'education',
    'technology',
    'business',
    'health',
    'history',
    'science',
    'sports',
    'music',
    'tvFilm',
    'arts',
    'kids',
    'leisure',
    'religion',
    'fiction',
    'government',
    'food',
    'games',
    'nature',
    'travel',
  ];

  /// Celles que la plupart des gens gardent au départ.
  static const _defaultEnabled = {
    'comedy',
    'news',
    'society',
    'trueCrime',
    'education',
    'technology',
    'business',
    'health',
    'history',
  };

  static const defaults = HomeCategories();

  final List<String> order;
  final Set<String> enabled;

  bool isOn(String id) => enabled.contains(id);

  List<String> get visible => [
    for (final id in order)
      if (known.contains(id) && isOn(id)) id,
  ];

  List<String> toIds() => [
    for (final id in order)
      if (known.contains(id)) isOn(id) ? id : '-$id',
  ];

  /// `null` (jamais configuré) → défauts ([defaults]).
  /// Une liste sans aucun genre connu (anciennes pastilles d’humeur) aussi.
  /// Un identifiant inconnu est ignoré. Un identifiant absent est ajouté
  /// à la fin, visible.
  static HomeCategories fromIds(List<String>? ids) {
    if (ids == null || !_containsKnown(ids)) return defaults;
    final order = <String>[];
    final enabled = <String>{};
    for (final raw in ids) {
      final off = raw.startsWith('-');
      final id = off ? raw.substring(1) : raw;
      if (!known.contains(id) || order.contains(id)) continue;
      order.add(id);
      if (!off) enabled.add(id);
    }
    for (final id in known) {
      if (!order.contains(id)) {
        order.add(id);
        enabled.add(id);
      }
    }
    return HomeCategories(order: order, enabled: enabled);
  }

  static bool _containsKnown(List<String> ids) {
    for (final raw in ids) {
      final id = raw.startsWith('-') ? raw.substring(1) : raw;
      if (known.contains(id)) return true;
    }
    return false;
  }

  /// Vrai quand l’utilisateur a enregistré un choix de catégories.
  static bool recognizes(List<String>? ids) {
    if (ids == null) return false;
    return _containsKnown(ids);
  }

  /// Les [monthlyHomeCategoryCount] genres les plus cités, plus Histoire
  /// si le mois ne l’a pas déjà placée dedans. Le reste est présent, masqué.
  static HomeCategories fromPlayRanks(List<String> ranked) {
    final picked = <String>[];
    for (final id in ranked) {
      if (!known.contains(id) || picked.contains(id)) continue;
      picked.add(id);
      if (picked.length >= monthlyHomeCategoryCount) break;
    }
    if (!picked.contains(pinnedHomeCategoryId) &&
        known.contains(pinnedHomeCategoryId)) {
      picked.add(pinnedHomeCategoryId);
    }
    final order = [
      ...picked,
      for (final id in known)
        if (!picked.contains(id)) id,
    ];
    return HomeCategories(order: order, enabled: picked.toSet());
  }

  HomeCategories copyWith({List<String>? order, Set<String>? enabled}) {
    return HomeCategories(
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
    );
  }
}
