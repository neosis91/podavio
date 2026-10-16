/// Libère des fichiers avant un téléchargement automatique, seulement si le
/// cache est plein. Un favori n’est jamais concerné.
enum EpisodeCacheCleanup {
  never('never', 'Never'),
  notInPlaylist('notInPlaylist', 'Not in the playlist'),
  afterListening('afterListening', 'After listening'),
  after1Day('1', '1 day after listening'),
  after3Days('3', '3 days after listening'),
  after7Days('7', '7 days after listening'),
  after14Days('14', '14 days after listening'),
  after30Days('30', '30 days after listening');

  const EpisodeCacheCleanup(this.id, this.label);

  final String id;

  /// Clé anglaise, traduite par l’interface.
  final String label;

  /// Jours après l’écoute. `0` = dès la fin. `null` = ce n’est pas un délai.
  int? get daysAfterListening => switch (this) {
    afterListening => 0,
    after1Day => 1,
    after3Days => 3,
    after7Days => 7,
    after14Days => 14,
    after30Days => 30,
    never || notInPlaylist => null,
  };

  static EpisodeCacheCleanup byId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return EpisodeCacheCleanup.never;
  }
}

/// Vrai quand la fin de lecture doit effacer le fichier local.
///
/// Un favori est conservé. Sans fichier, il n’y a rien à faire.
/// Marquer un épisode lu à la main ne doit pas passer par ici : seul le lecteur,
/// quand la lecture se termine, appelle cette décision.
bool shouldDeleteAfterPlayback({
  required bool enabled,
  required bool favorite,
  required String? downloadPath,
}) {
  if (!enabled || favorite) return false;
  final path = downloadPath?.trim();
  return path != null && path.isNotEmpty;
}

/// Épisode candidat à un téléchargement automatique.
class DownloadCandidate {
  const DownloadCandidate({
    required this.id,
    required this.included,
    required this.played,
    required this.downloaded,
    this.publishedAt,
  });

  final int id;

  /// Le podcast est inclus dans le téléchargement automatique.
  final bool included;

  final bool played;
  final bool downloaded;

  /// Date de publication. Sert à prendre les plus récents d’abord.
  final DateTime? publishedAt;
}

/// Fichier local qui occupe une place du cache.
class LocalDownload {
  const LocalDownload({
    required this.id,
    required this.favorite,
    required this.inPlaylist,
    required this.played,
    this.downloadedAt,
    this.publishedAt,
    this.lastPlayedAt,
  });

  final int id;
  final bool favorite;

  /// Présent dans la file de lecture (la playlist par défaut).
  final bool inPlaylist;

  final bool played;
  final DateTime? downloadedAt;
  final DateTime? publishedAt;

  /// Moment où la lecture s’est terminée.
  final DateTime? lastPlayedAt;
}

/// Qui télécharger et qui effacer avant un téléchargement automatique.
class AutomaticDownloadDecision {
  const AutomaticDownloadDecision({
    required this.downloadIds,
    required this.deleteIds,
  });

  /// Les plus récents d’abord.
  final List<int> downloadIds;

  /// Les plus anciens d’abord, juste assez de places pour [downloadIds].
  final List<int> deleteIds;
}

/// Choisit les épisodes à télécharger et les fichiers à effacer.
///
/// Le mécanisme est arrêté quand [enabled] est faux : rien n’est téléchargé
/// ni effacé. Un cache illimité ([cacheSize] nul) télécharge les épisodes
/// inclus, non lus et pas déjà là, sans rien effacer.
///
/// Sinon, on ne dépasse pas le cache. S’il est plein, [cleanup] libère juste
/// assez de places pour les nouveautés qui rentrent encore. Un favori n’est
/// jamais effacé. Une bibliothèque déjà au-dessus du cache n’est pas vidée :
/// on retire au plus un ancien fichier par nouveauté.
AutomaticDownloadDecision decideAutomaticDownloads({
  required bool enabled,
  required int? cacheSize,
  required EpisodeCacheCleanup cleanup,
  required List<DownloadCandidate> incoming,
  required List<LocalDownload> cached,
  required DateTime now,
}) {
  if (!enabled) {
    return const AutomaticDownloadDecision(downloadIds: [], deleteIds: []);
  }

  final onDisk = <int, LocalDownload>{};
  for (final episode in cached) {
    onDisk.putIfAbsent(episode.id, () => episode);
  }

  final seen = <int>{};
  final eligible = <DownloadCandidate>[];
  for (final episode in incoming) {
    if (!seen.add(episode.id)) continue;
    if (!episode.included || episode.played || episode.downloaded) continue;
    if (onDisk.containsKey(episode.id)) continue;
    eligible.add(episode);
  }
  eligible.sort(_newerFirst);

  if (cacheSize == null) {
    return AutomaticDownloadDecision(
      downloadIds: [for (final episode in eligible) episode.id],
      deleteIds: const [],
    );
  }

  final victims = [
    for (final episode in onDisk.values)
      if (_canEvict(episode, cleanup, now)) episode,
  ]..sort(_olderFirst);

  final freeSlots = cacheSize - onDisk.length;
  final openSlots = freeSlots < 0 ? 0 : freeSlots;
  var downloadCount = eligible.length;
  final room = openSlots + victims.length;
  if (downloadCount > room) downloadCount = room;

  final deficit = downloadCount - openSlots;
  final deleteCount = deficit < 0 ? 0 : deficit;

  return AutomaticDownloadDecision(
    downloadIds: [
      for (final episode in eligible.take(downloadCount)) episode.id,
    ],
    deleteIds: [for (final episode in victims.take(deleteCount)) episode.id],
  );
}

int _newerFirst(DownloadCandidate a, DownloadCandidate b) {
  final aDate = a.publishedAt;
  final bDate = b.publishedAt;
  if (aDate == null && bDate == null) return b.id.compareTo(a.id);
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  final byDate = bDate.compareTo(aDate);
  if (byDate != 0) return byDate;
  return b.id.compareTo(a.id);
}

int _olderFirst(LocalDownload a, LocalDownload b) {
  final aDate = a.downloadedAt ?? a.publishedAt ?? a.lastPlayedAt;
  final bDate = b.downloadedAt ?? b.publishedAt ?? b.lastPlayedAt;
  if (aDate == null && bDate == null) return a.id.compareTo(b.id);
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  final byDate = aDate.compareTo(bDate);
  if (byDate != 0) return byDate;
  return a.id.compareTo(b.id);
}

bool _canEvict(
  LocalDownload episode,
  EpisodeCacheCleanup cleanup,
  DateTime now,
) {
  if (episode.favorite) return false;
  return switch (cleanup) {
    EpisodeCacheCleanup.never => false,
    EpisodeCacheCleanup.notInPlaylist => !episode.inPlaylist,
    EpisodeCacheCleanup.afterListening ||
    EpisodeCacheCleanup.after1Day ||
    EpisodeCacheCleanup.after3Days ||
    EpisodeCacheCleanup.after7Days ||
    EpisodeCacheCleanup.after14Days ||
    EpisodeCacheCleanup.after30Days => _listenedLongEnough(
      episode,
      cleanup,
      now,
    ),
  };
}

bool _listenedLongEnough(
  LocalDownload episode,
  EpisodeCacheCleanup cleanup,
  DateTime now,
) {
  if (!episode.played) return false;
  final days = cleanup.daysAfterListening;
  if (days == null) return false;
  if (days == 0) return true;
  final listened = episode.lastPlayedAt;
  if (listened == null) return false;
  return !listened.add(Duration(days: days)).isAfter(now);
}
