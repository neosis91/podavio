/// Événements locaux à envoyer au serveur de synchronisation.
///
/// Le contrôleur s’enregistre au démarrage. Pendant l’application d’un
/// changement distant, [applying] empêche de renvoyer la même action.
class SyncHooks {
  static var applying = false;
  static final silentEpisodes = <int>{};

  static void Function(String feedUrl)? subscribed;
  static void Function(String feedUrl)? unsubscribed;
  static void Function(SyncEpisodeReport report)? episode;

  static void reportSubscribed(String feedUrl) {
    if (applying) return;
    final url = feedUrl.trim();
    if (!url.startsWith('http')) return;
    subscribed?.call(url);
  }

  static void reportUnsubscribed(String feedUrl) {
    if (applying) return;
    final url = feedUrl.trim();
    if (!url.startsWith('http')) return;
    unsubscribed?.call(url);
  }

  static void reportEpisode(SyncEpisodeReport report) {
    if (applying || silentEpisodes.contains(report.episodeId)) return;
    if (!report.feedUrl.startsWith('http')) return;
    if (report.audioUrl.isEmpty) return;
    episode?.call(report);
  }
}

class SyncEpisodeReport {
  const SyncEpisodeReport({
    required this.episodeId,
    required this.feedUrl,
    required this.audioUrl,
    required this.guid,
    required this.action,
    this.positionSeconds = 0,
    this.startedSeconds = 0,
    this.totalSeconds = 0,
  });

  final int episodeId;
  final String feedUrl;
  final String audioUrl;
  final String guid;

  /// `play`, `new`, `download` ou `delete`.
  final String action;
  final int positionSeconds;
  final int startedSeconds;
  final int totalSeconds;
}
