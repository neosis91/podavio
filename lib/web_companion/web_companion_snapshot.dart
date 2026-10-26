const webCompanionEpisodeCap = 30;

class WebCompanionEpisodeRef {
  const WebCompanionEpisodeRef({
    required this.id,
    required this.publishedAt,
    required this.positionMs,
    required this.played,
  });

  final int id;
  final DateTime? publishedAt;
  final int positionMs;
  final bool played;
}

/// Épisodes récents, plus ceux déjà commencés s’ils sortent du plafond.
List<T> capWebCompanionEpisodes<T extends WebCompanionEpisodeRef>(
  List<T> episodes, {
  int cap = webCompanionEpisodeCap,
}) {
  final ordered = [...episodes]..sort((a, b) {
    final left = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  });
  final picked = <T>[];
  final seen = <int>{};
  for (final episode in ordered) {
    if (picked.length >= cap) break;
    picked.add(episode);
    seen.add(episode.id);
  }
  for (final episode in ordered) {
    if (seen.contains(episode.id)) continue;
    if (episode.positionMs > 0 && !episode.played) picked.add(episode);
  }
  return picked;
}

class WebProgress {
  const WebProgress({required this.episodeId, required this.positionMs});

  final int episodeId;
  final int positionMs;

  static WebProgress? parse(Object? raw) {
    if (raw is! Map) return null;
    if (raw['type'] != 'progress') return null;
    final episodeId = raw['episodeId'];
    final positionMs = raw['positionMs'];
    if (episodeId is! int || episodeId <= 0) return null;
    if (positionMs is! int || positionMs < 0 || positionMs > 86400000 * 2) {
      return null;
    }
    return WebProgress(episodeId: episodeId, positionMs: positionMs);
  }
}
