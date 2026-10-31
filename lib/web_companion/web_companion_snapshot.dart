const webCompanionEpisodeCap = 30;

class WebCompanionEpisodeRef {
  const WebCompanionEpisodeRef({
    required this.id,
    required this.publishedAt,
    required this.positionMs,
    required this.played,
    this.favorite = false,
    this.downloaded = false,
    this.pinned = false,
    this.lastPlayedAt,
  });

  final int id;
  final DateTime? publishedAt;
  final int positionMs;
  final bool played;
  final bool favorite;
  final bool downloaded;

  /// Dans une playlist ou la file : à garder même hors du plafond récent.
  final bool pinned;
  final DateTime? lastPlayedAt;

  bool get keptBeyondCap =>
      (positionMs > 0 && !played) ||
      favorite ||
      downloaded ||
      pinned ||
      lastPlayedAt != null;
}

/// Épisodes récents, plus ceux déjà commencés s’ils sortent du plafond.
List<T> capWebCompanionEpisodes<T extends WebCompanionEpisodeRef>(
  List<T> episodes, {
  int cap = webCompanionEpisodeCap,
}) {
  final ordered = [...episodes]
    ..sort((a, b) {
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
    if (episode.keptBeyondCap) picked.add(episode);
  }
  return picked;
}

class WebProgress {
  const WebProgress({
    required this.episodeId,
    required this.positionMs,
    this.ended = false,
    this.playing,
    this.durationMs,
  });

  final int episodeId;
  final int positionMs;
  final bool ended;

  /// `null` si l’ancien navigateur n’envoie pas l’état de lecture.
  final bool? playing;
  final int? durationMs;

  static WebProgress? parse(Object? raw) {
    if (raw is! Map) return null;
    if (raw['type'] != 'progress') return null;
    final episodeId = raw['episodeId'];
    final positionMs = raw['positionMs'];
    if (episodeId is! int || episodeId <= 0) return null;
    if (positionMs is! int || positionMs < 0 || positionMs > 86400000 * 2) {
      return null;
    }
    final durationMs = raw['durationMs'];
    return WebProgress(
      episodeId: episodeId,
      positionMs: positionMs,
      ended: raw['ended'] == true,
      playing: raw['playing'] is bool ? raw['playing'] as bool : null,
      durationMs: durationMs is int && durationMs >= 0 ? durationMs : null,
    );
  }
}

enum WebLibraryKind {
  favorite,
  download,
  removeDownload,
  playlist,
  createPlaylist,
}

/// Action de bibliothèque demandée par le navigateur et exécutée sur le téléphone.
class WebLibraryAction {
  const WebLibraryAction({
    required this.kind,
    required this.episodeId,
    this.favorite,
    this.playlistId,
    this.member,
    this.name,
  });

  final WebLibraryKind kind;
  final int episodeId;
  final bool? favorite;
  final int? playlistId;
  final bool? member;
  final String? name;

  static const maxNameLength = 80;

  static WebLibraryAction? parse(Object? raw) {
    if (raw is! Map) return null;
    if (raw['type'] != 'library') return null;
    final episodeId = raw['episodeId'];
    if (episodeId is! int || episodeId <= 0) return null;
    switch (raw['action']) {
      case 'favorite':
        final favorite = raw['favorite'];
        if (favorite is! bool) return null;
        return WebLibraryAction(
          kind: WebLibraryKind.favorite,
          episodeId: episodeId,
          favorite: favorite,
        );
      case 'download':
        return WebLibraryAction(
          kind: WebLibraryKind.download,
          episodeId: episodeId,
        );
      case 'remove-download':
        return WebLibraryAction(
          kind: WebLibraryKind.removeDownload,
          episodeId: episodeId,
        );
      case 'playlist':
        final playlistId = raw['playlistId'];
        final member = raw['member'];
        if (playlistId is! int || playlistId <= 0 || member is! bool) {
          return null;
        }
        return WebLibraryAction(
          kind: WebLibraryKind.playlist,
          episodeId: episodeId,
          playlistId: playlistId,
          member: member,
        );
      case 'create-playlist':
        final name = raw['name'];
        if (name is! String) return null;
        final trimmed = name.trim();
        if (trimmed.isEmpty || trimmed.length > maxNameLength) return null;
        return WebLibraryAction(
          kind: WebLibraryKind.createPlaylist,
          episodeId: episodeId,
          name: trimmed,
        );
      default:
        return null;
    }
  }
}
