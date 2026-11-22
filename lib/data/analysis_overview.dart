import 'hosting_source.dart';
import 'skip_segments.dart';

/// État d'analyse des épisodes déjà téléchargés d'un podcast.
enum AnalysisOverviewStatus { analysed, pending, failed, inProgress }

/// Pubs, virgules, sponsors et outros affichés sur la ligne.
const analysisCountKinds = <SkipSegmentKind>[
  SkipSegmentKind.ad,
  SkipSegmentKind.jingle,
  SkipSegmentKind.sponsor,
  SkipSegmentKind.outro,
];

/// Un podcast suivi, avec ou sans téléchargement.
class AnalysisCatalogPodcast {
  const AnalysisCatalogPodcast({
    required this.id,
    required this.title,
    this.imageUrl,
    this.imagePath,
    this.feedUrl = '',
  });

  final int id;
  final String title;
  final String? imageUrl;
  final String? imagePath;
  final String feedUrl;
}

/// Un épisode dont le fichier est sur l'appareil.
class AnalysisDownloadFact {
  const AnalysisDownloadFact({
    required this.podcastId,
    required this.audioUrl,
    required this.fingerprintStatus,
  });

  final int podcastId;
  final String audioUrl;

  /// `done`, `failed`, `running`, ou vide si l'empreinte n'existe pas.
  final String fingerprintStatus;
}

/// Nombre de séquences connues d'un type, pour un podcast.
class AnalysisSegmentFact {
  const AnalysisSegmentFact({
    required this.podcastId,
    required this.kind,
    required this.count,
  });

  final int podcastId;
  final SkipSegmentKind kind;
  final int count;
}

/// Ligne de la page globale.
class AnalysisOverviewPodcast {
  const AnalysisOverviewPodcast({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.imagePath,
    required this.downloadedEpisodes,
    required this.hostingSource,
    required this.status,
    required this.counts,
  });

  final int id;
  final String title;
  final String? imageUrl;
  final String? imagePath;
  final int downloadedEpisodes;
  final String hostingSource;
  final AnalysisOverviewStatus status;
  final Map<SkipSegmentKind, int> counts;

  int countOf(SkipSegmentKind kind) => counts[kind] ?? 0;
}

class AnalysisOverviewGroup {
  const AnalysisOverviewGroup({
    required this.hostingSource,
    required this.podcasts,
  });

  final String hostingSource;
  final List<AnalysisOverviewPodcast> podcasts;
}

/// Zéro téléchargement : la ligne n'existe pas. Un seul suffit.
bool showsOnAnalysisPage(int downloadedEpisodes) => downloadedEpisodes >= 1;

AnalysisOverviewStatus analysisStatus({
  required List<String> fingerprintStatuses,
  required bool running,
  required bool queued,
}) {
  if (running || fingerprintStatuses.contains('running')) {
    return AnalysisOverviewStatus.inProgress;
  }
  if (queued) return AnalysisOverviewStatus.pending;
  if (fingerprintStatuses.contains('failed')) {
    return AnalysisOverviewStatus.failed;
  }
  if (fingerprintStatuses.any((status) => status.isEmpty)) {
    return AnalysisOverviewStatus.pending;
  }
  return AnalysisOverviewStatus.analysed;
}

/// Podcasts avec au moins un téléchargement, et leurs séquences connues.
///
/// Un abonnement sans fichier n'est pas repris, même s'il est dans [catalog].
List<AnalysisOverviewPodcast> buildAnalysisOverview({
  required List<AnalysisCatalogPodcast> catalog,
  required List<AnalysisDownloadFact> downloads,
  required List<AnalysisSegmentFact> segments,
  Set<int> runningPodcastIds = const {},
  Set<int> queuedPodcastIds = const {},
}) {
  final byPodcast = <int, List<AnalysisDownloadFact>>{};
  for (final fact in downloads) {
    (byPodcast[fact.podcastId] ??= []).add(fact);
  }
  final counts = <int, Map<SkipSegmentKind, int>>{};
  for (final fact in segments) {
    if (!analysisCountKinds.contains(fact.kind)) continue;
    if (fact.count <= 0) continue;
    final map = counts.putIfAbsent(fact.podcastId, () => {});
    map[fact.kind] = (map[fact.kind] ?? 0) + fact.count;
  }
  final known = {for (final podcast in catalog) podcast.id: podcast};
  final ids = <int>{...known.keys, ...byPodcast.keys};
  final rows = <AnalysisOverviewPodcast>[];
  for (final id in ids) {
    final facts = byPodcast[id] ?? const <AnalysisDownloadFact>[];
    if (!showsOnAnalysisPage(facts.length)) continue;
    final podcast = known[id];
    final urls = [
      for (final fact in facts)
        if (fact.audioUrl.trim().isNotEmpty) fact.audioUrl,
      if (podcast != null && podcast.feedUrl.trim().isNotEmpty) podcast.feedUrl,
    ];
    rows.add(
      AnalysisOverviewPodcast(
        id: id,
        title: podcast?.title ?? '',
        imageUrl: _blank(podcast?.imageUrl),
        imagePath: _blank(podcast?.imagePath),
        downloadedEpisodes: facts.length,
        hostingSource: dominantHostingSource(urls),
        status: analysisStatus(
          fingerprintStatuses: [
            for (final fact in facts) fact.fingerprintStatus,
          ],
          running: runningPodcastIds.contains(id),
          queued: queuedPodcastIds.contains(id),
        ),
        counts: Map.unmodifiable(counts[id] ?? const {}),
      ),
    );
  }
  rows.sort((a, b) {
    final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    if (byTitle != 0) return byTitle;
    return a.id.compareTo(b.id);
  });
  return rows;
}

/// Sections de la page, une par hébergeur. La source inconnue finit en dernier.
List<AnalysisOverviewGroup> groupAnalysisRows(
  List<AnalysisOverviewPodcast> rows,
) {
  final grouped = groupByHostingSource(rows, (row) => row.hostingSource);
  final keys = grouped.keys.toList()
    ..sort((a, b) {
      if (a.isEmpty && b.isEmpty) return 0;
      if (a.isEmpty) return 1;
      if (b.isEmpty) return -1;
      return a.compareTo(b);
    });
  return [
    for (final key in keys)
      AnalysisOverviewGroup(hostingSource: key, podcasts: grouped[key]!),
  ];
}

String hostingSourceLabel(String key) {
  if (key.isEmpty) return 'Other';
  if (key.length == 1) return key.toUpperCase();
  return '${key[0].toUpperCase()}${key.substring(1)}';
}

String? _blank(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed;
}
