/// Étagères de l’accueil, dans l’ordre d’affichage.
/// Un identifiant précédé de `-` est masqué.
class HomeShelves {
  const HomeShelves({this.order = known, this.enabled = _defaultEnabled});

  static const known = [
    'continue',
    'fresh',
    'favorites',
    'recent',
    'random',
    'preferred',
    'downloads',
  ];

  static const _defaultEnabled = {
    'continue',
    'fresh',
    'favorites',
    'recent',
    'random',
    'preferred',
    'downloads',
  };

  static const defaults = HomeShelves();

  /// Toutes les étagères, affichées ou non, dans l’ordre choisi.
  final List<String> order;

  /// Étagères affichées.
  final Set<String> enabled;

  bool isOn(String id) => enabled.contains(id);

  /// Étagères réellement dessinées, dans l’ordre.
  List<String> get visible => [
    for (final id in order)
      if (known.contains(id) && isOn(id)) id,
  ];

  List<String> toIds() => [
    for (final id in order)
      if (known.contains(id)) isOn(id) ? id : '-$id',
  ];

  /// `null` (jamais configuré) → défauts ([defaults]).
  /// Un identifiant inconnu est ignoré. Un identifiant absent est ajouté
  /// à la fin, visible.
  static HomeShelves fromIds(List<String>? ids) {
    if (ids == null) return defaults;
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
    return HomeShelves(order: order, enabled: enabled);
  }

  HomeShelves copyWith({List<String>? order, Set<String>? enabled}) {
    return HomeShelves(
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Clé anglaise du titre d’une étagère de l’accueil.
String homeShelfTitle(String id) {
  return switch (id) {
    'continue' => 'Continue listening',
    'fresh' => "What's new",
    'favorites' => 'Favorites',
    'recent' => 'Recent plays',
    'random' => 'Random',
    'preferred' => 'Preferred subscriptions',
    'downloads' => 'Recent downloads',
    _ => id,
  };
}
