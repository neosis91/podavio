/// Compteur affiché sur les jaquettes de la page Abonnements.
enum PodcastCounter {
  unread('unread', 'Épisodes non lus'),
  downloaded('downloaded', 'Épisodes téléchargés'),
  downloadedUnread('downloadedUnread', 'Téléchargés et non lus'),
  queue('queue', 'Playlist'),
  none('none', 'Aucun compteur');

  const PodcastCounter(this.id, this.label);

  final String id;
  final String label;

  static PodcastCounter byId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return PodcastCounter.none;
  }
}

/// Filtres de la page Abonnements (multi-sélection).
class PodcastFilters {
  const PodcastFilters({
    this.counterAboveZero = false,
    this.autoDownload,
    this.keepUpdated,
  });

  static const empty = PodcastFilters();

  /// Compteur (réglage Compteur) supérieur à zéro.
  final bool counterAboveZero;

  /// `true` = avec téléchargements auto, `false` = sans, `null` = indifférent.
  final bool? autoDownload;

  /// `true` = maintenu à jour, `false` = non maintenu, `null` = indifférent.
  final bool? keepUpdated;

  bool get isEmpty =>
      !counterAboveZero && autoDownload == null && keepUpdated == null;

  List<String> toIds() {
    return [
      if (counterAboveZero) 'counterAboveZero',
      if (autoDownload == true) 'withAutoDownload',
      if (autoDownload == false) 'withoutAutoDownload',
      if (keepUpdated == true) 'keepUpdated',
      if (keepUpdated == false) 'notKeepUpdated',
    ];
  }

  static PodcastFilters fromIds(List<String>? ids) {
    if (ids == null || ids.isEmpty) return empty;
    final set = ids.toSet();
    bool? autoDownload;
    if (set.contains('withAutoDownload')) {
      autoDownload = true;
    } else if (set.contains('withoutAutoDownload')) {
      autoDownload = false;
    }
    bool? keepUpdated;
    if (set.contains('keepUpdated')) {
      keepUpdated = true;
    } else if (set.contains('notKeepUpdated')) {
      keepUpdated = false;
    }
    return PodcastFilters(
      counterAboveZero: set.contains('counterAboveZero'),
      autoDownload: autoDownload,
      keepUpdated: keepUpdated,
    );
  }

  PodcastFilters copyWith({
    bool? counterAboveZero,
    bool? autoDownload,
    bool clearAutoDownload = false,
    bool? keepUpdated,
    bool clearKeepUpdated = false,
  }) {
    return PodcastFilters(
      counterAboveZero: counterAboveZero ?? this.counterAboveZero,
      autoDownload: clearAutoDownload
          ? null
          : (autoDownload ?? this.autoDownload),
      keepUpdated: clearKeepUpdated ? null : (keepUpdated ?? this.keepUpdated),
    );
  }
}

/// Tri de la page Abonnements.
enum PodcastSort {
  published('published', 'Date de publication'),
  alphabetical('alphabetical', 'Ordre alphabétique'),
  counter('counter', 'Compteur'),
  played('played', 'Nombre lus');

  const PodcastSort(this.id, this.label);

  final String id;
  final String label;

  static PodcastSort byId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return PodcastSort.published;
  }
}
