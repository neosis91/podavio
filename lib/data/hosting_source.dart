/// Famille d'hébergement d'une URL audio ou de flux.
///
/// `https://audio.audiomeans.fr/a.mp3` et `https://podcasts.audiomeans.fr/b`
/// partagent `audiomeans`. Une URL illisible donne une chaîne vide.
String hostingSourceKey(String? url) {
  final host = Uri.tryParse(url?.trim() ?? '')?.host.toLowerCase() ?? '';
  if (host.isEmpty) return '';
  final labels = host.split('.').where((part) => part.isNotEmpty).toList();
  if (labels.isEmpty) return '';
  if (labels.first == 'www' && labels.length > 1) {
    labels.removeAt(0);
  }
  const multiPartSuffix = {'co.uk', 'com.au', 'co.jp', 'com.br', 'co.nz'};
  if (labels.length >= 3) {
    final tail = '${labels[labels.length - 2]}.${labels.last}';
    if (multiPartSuffix.contains(tail)) return labels[labels.length - 3];
  }
  if (labels.length >= 2) return labels[labels.length - 2];
  return labels.single;
}

/// Source la plus fréquente. À égalité, la clé la plus petite gagne.
String dominantHostingSource(Iterable<String> urls) {
  final counts = <String, int>{};
  for (final url in urls) {
    final key = hostingSourceKey(url);
    if (key.isEmpty) continue;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  if (counts.isEmpty) return '';
  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
  return ranked.first.key;
}

/// Regroupe [items] par source d'hébergement. Les clés sont triées.
Map<String, List<T>> groupByHostingSource<T>(
  Iterable<T> items,
  String Function(T item) sourceOf,
) {
  final grouped = <String, List<T>>{};
  for (final item in items) {
    final key = sourceOf(item);
    (grouped[key] ??= <T>[]).add(item);
  }
  final keys = grouped.keys.toList()..sort();
  return {for (final key in keys) key: grouped[key]!};
}

typedef HostingDownload = ({int podcastId, String audioUrl, String feedUrl});

String hostingUrlOf(HostingDownload row) {
  final audio = row.audioUrl.trim();
  if (audio.isNotEmpty) return audio;
  return row.feedUrl.trim();
}

/// Podcasts dont les empreintes se comparent ensemble.
///
/// Avec moins de deux téléchargements sur le podcast suivi, on ne compare
/// pas encore : seuls les gabarits déjà connus s'appliquent. À partir du
/// deuxième, les autres podcasts du même hébergeur entrent dans le groupe.
List<int> comparisonPodcastIds({
  required int focusPodcastId,
  required int focusDownloadCount,
  required List<HostingDownload> hosts,
}) {
  if (focusDownloadCount < 2) return [focusPodcastId];
  final key = dominantHostingSource([
    for (final row in hosts)
      if (row.podcastId == focusPodcastId) hostingUrlOf(row),
  ]);
  if (key.isEmpty) return [focusPodcastId];
  final ids = <int>{focusPodcastId};
  for (final row in hosts) {
    if (hostingSourceKey(hostingUrlOf(row)) == key) ids.add(row.podcastId);
  }
  return ids.toList()..sort();
}
