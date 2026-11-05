/// Densité des listes d’épisodes (compose avec le palier de largeur).
enum EpisodeListDensity {
  comfortable('comfortable', 'Comfortable'),
  compact('compact', 'Compact');

  const EpisodeListDensity(this.id, this.label);

  final String id;
  final String label;

  static EpisodeListDensity byId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return EpisodeListDensity.comfortable;
  }
}
