/// Boutons du mini-lecteur, dans l’ordre d’affichage.
/// Lecture/pause est toujours présent.
class MiniPlayerButtons {
  const MiniPlayerButtons({
    this.order = _defaultOrder,
    this.enabled = _defaultEnabled,
  });

  static const known = [
    'favorite',
    'skipBack',
    'skipForward',
    'nextEpisode',
    'close',
    'play',
  ];

  static const _defaultOrder = [
    'favorite',
    'play',
    'skipBack',
    'skipForward',
    'nextEpisode',
    'close',
  ];

  static const _defaultEnabled = {'favorite', 'play'};

  static const defaults = MiniPlayerButtons();

  /// Tous les boutons, activés ou non, dans l’ordre choisi.
  final List<String> order;

  /// Boutons affichés, en plus de `play`.
  final Set<String> enabled;

  bool isOn(String id) => id == 'play' || enabled.contains(id);

  /// Boutons réellement dessinés, dans l’ordre.
  List<String> get visible {
    final ids = <String>[
      for (final id in order)
        if (known.contains(id) && isOn(id)) id,
    ];
    if (!ids.contains('play')) ids.add('play');
    return ids;
  }

  List<String> toIds() => [
    for (final id in order)
      if (known.contains(id)) isOn(id) ? id : '-$id',
  ];

  /// `null` (jamais configuré) → défauts ([defaults]).
  static MiniPlayerButtons fromIds(List<String>? ids) {
    if (ids == null) return defaults;
    final modern = ids.any((id) => id == 'play' || id.startsWith('-'));
    if (!modern) {
      const optional = [
        'favorite',
        'skipBack',
        'skipForward',
        'nextEpisode',
        'close',
      ];
      final enabled = ids.where(known.contains).toSet()..add('play');
      return MiniPlayerButtons(
        order: [
          for (final id in optional)
            if (enabled.contains(id)) id,
          'play',
          for (final id in optional)
            if (!enabled.contains(id)) id,
        ],
        enabled: enabled,
      );
    }
    final order = <String>[];
    final enabled = <String>{'play'};
    for (final raw in ids) {
      final off = raw.startsWith('-');
      final id = off ? raw.substring(1) : raw;
      if (!known.contains(id) || order.contains(id)) continue;
      order.add(id);
      if (!off) enabled.add(id);
    }
    for (final id in known) {
      if (!order.contains(id)) order.add(id);
    }
    enabled.add('play');
    return MiniPlayerButtons(order: order, enabled: enabled);
  }

  MiniPlayerButtons copyWith({List<String>? order, Set<String>? enabled}) {
    return MiniPlayerButtons(
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
    );
  }

  String get summary => visible.map(_miniButtonName).join(', ');
}

String _miniButtonName(String id) {
  return switch (id) {
    'play' => 'Lecture',
    'favorite' => 'Favoris',
    'skipBack' => 'Retour',
    'skipForward' => 'Avance',
    'nextEpisode' => 'Suivant',
    'close' => 'Fermer',
    _ => id,
  };
}
