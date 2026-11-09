/// Filtres de la page Épisodes (multi-sélection, AND).
class EpisodeFilters {
  const EpisodeFilters({
    this.unreadOnly = false,
    this.downloadsOnly = false,
    this.inProgressOnly = false,
  });

  static const empty = EpisodeFilters();

  /// Défaut première ouverture (inbox non lus).
  static const inboxDefault = EpisodeFilters(unreadOnly: true);

  final bool unreadOnly;
  final bool downloadsOnly;
  final bool inProgressOnly;

  bool get isEmpty => !unreadOnly && !downloadsOnly && !inProgressOnly;

  List<String> toIds() => [
    if (unreadOnly) 'unreadOnly',
    if (downloadsOnly) 'downloadsOnly',
    if (inProgressOnly) 'inProgressOnly',
  ];

  /// `null` (jamais configuré) → [inboxDefault] ; liste vide → [empty].
  static EpisodeFilters fromIds(List<String>? ids) {
    if (ids == null) return inboxDefault;
    if (ids.isEmpty) return empty;
    final set = ids.toSet();
    return EpisodeFilters(
      unreadOnly: set.contains('unreadOnly'),
      downloadsOnly: set.contains('downloadsOnly'),
      inProgressOnly: set.contains('inProgressOnly'),
    );
  }

  EpisodeFilters copyWith({
    bool? unreadOnly,
    bool? downloadsOnly,
    bool? inProgressOnly,
  }) {
    return EpisodeFilters(
      unreadOnly: unreadOnly ?? this.unreadOnly,
      downloadsOnly: downloadsOnly ?? this.downloadsOnly,
      inProgressOnly: inProgressOnly ?? this.inProgressOnly,
    );
  }
}
