import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/analysis_overview.dart';
import '../../data/audio_analysis.dart';
import '../../data/providers.dart';
import '../../data/skip_segments.dart';
import '../../l10n/l10n.dart';
import '../../settings/global_skip.dart';
import '../podcast/passage_creation.dart';
import '../router.dart';
import '../skip_kind_mark.dart';
import '../widgets/cover.dart';
import '../widgets/empty_state.dart';
import 'analysis_status_mark.dart';
import 'settings_section_title.dart';

final analysisOverviewProvider = StreamProvider<List<AnalysisOverviewPodcast>>((
  ref,
) {
  final database = ref.watch(databaseProvider);
  return database.watchAnalysisFacts().map(
    (facts) => buildAnalysisOverview(
      catalog: [
        for (final row in facts.catalog)
          AnalysisCatalogPodcast(
            id: row.id,
            title: row.title,
            imageUrl: row.imageUrl,
            imagePath: row.imagePath,
            feedUrl: row.feedUrl,
          ),
      ],
      downloads: [
        for (final row in facts.downloads)
          AnalysisDownloadFact(
            podcastId: row.podcastId,
            audioUrl: row.audioUrl,
            fingerprintStatus: row.status,
          ),
      ],
      segments: [
        for (final row in facts.segments)
          if (_kindOf(row.kind) != null)
            AnalysisSegmentFact(
              podcastId: row.podcastId,
              kind: _kindOf(row.kind)!,
              count: row.count,
            ),
      ],
      manualSegments: facts.manual,
    ),
  );
});

SkipSegmentKind? _kindOf(String name) {
  for (final kind in SkipSegmentKind.values) {
    if (kind.name == name) return kind;
  }
  return null;
}

class AnalysisSettingsPage extends ConsumerWidget {
  const AnalysisSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skip = ref.watch(globalSkipSettingsProvider);
    final overview = ref.watch(analysisOverviewProvider);
    final progress = ref.watch(audioAnalysisProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Analysis management'))),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          title: context.tr('Analysis management'),
          message: error.toString(),
        ),
        data: (rows) {
          final live = [for (final row in rows) _withLiveStatus(row, progress)];
          final groups = groupAnalysisRows(live);
          return ListView(
            children: [
              SettingsSectionTitle(context.tr('Skip automatically')),
              SwitchListTile(
                title: Text(context.tr('Skip automatically')),
                subtitle: Text(
                  context.tr('Skips the chosen kinds in downloaded episodes'),
                ),
                value: skip.enabled,
                onChanged: (enabled) => ref
                    .read(globalSkipSettingsProvider.notifier)
                    .setEnabled(enabled),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.tr('Applies to every podcast.'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SettingsSectionTitle(context.tr('Kinds to skip')),
              for (final kind in SkipSegmentKind.values)
                if (kind != SkipSegmentKind.sponsor) SkipKindSwitch(kind),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  context.tr(
                    'The analysis prepares each downloaded episode (fingerprint and waveform), then searches it for the passages created by hand. Nothing is detected on its own.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Text(
                    context.tr('No downloaded episodes to analyse.'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final group in groups) ...[
                  SettingsSectionTitle(
                    group.hostingSource.isEmpty
                        ? context.tr('Other')
                        : hostingSourceLabel(group.hostingSource),
                  ),
                  for (final row in group.podcasts)
                    _AnalysisPodcastTile(row: row),
                ],
            ],
          );
        },
      ),
    );
  }
}

AnalysisOverviewPodcast _withLiveStatus(
  AnalysisOverviewPodcast row,
  AudioAnalysisProgress progress,
) {
  final running = progress.runningPodcastId == row.id;
  final queued = progress.pending.any((job) => job.podcastId == row.id);
  if (!running && !queued) return row;
  return AnalysisOverviewPodcast(
    id: row.id,
    title: row.title,
    imageUrl: row.imageUrl,
    imagePath: row.imagePath,
    downloadedEpisodes: row.downloadedEpisodes,
    hostingSource: row.hostingSource,
    status: analysisStatus(
      fingerprintStatuses: const [],
      running: running,
      queued: queued,
    ),
    counts: row.counts,
    manualSegments: row.manualSegments,
  );
}

class _AnalysisPodcastTile extends ConsumerWidget {
  const _AnalysisPodcastTile({required this.row});

  final AnalysisOverviewPodcast row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final counts = [
      for (final kind in analysisCountKinds)
        if (kind != SkipSegmentKind.sponsor)
          if (_countOf(row, kind) > 0)
            SkipKindCount(kind: kind, count: _countOf(row, kind)),
    ];
    return ListTile(
      titleAlignment: ListTileTitleAlignment.center,
      leading: PodcastCover(
        localPath: row.imagePath,
        label: row.title,
        size: 48,
      ),
      title: Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      isThreeLine: true,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _downloadLabel(context, row.downloadedEpisodes),
            style: detailStyle,
          ),
          if (counts.isEmpty)
            Text(context.tr('No passages created yet'), style: detailStyle)
          else
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: counts,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.tr('Create a passage'),
            icon: const Icon(Icons.content_cut),
            onPressed: () => pickEpisodeForPassage(context, ref, row.id),
          ),
          AnalysisStatusMark(
            status: row.status,
            label: context.tr(_statusLabel(row.status)),
          ),
        ],
      ),
      onTap: () => context.push(AppRoutes.podcastSkipSegments(row.id)),
    );
  }
}

int _countOf(AnalysisOverviewPodcast row, SkipSegmentKind kind) {
  if (kind == SkipSegmentKind.ad) {
    return row.countOf(SkipSegmentKind.ad) +
        row.countOf(SkipSegmentKind.sponsor);
  }
  return row.countOf(kind);
}

String _downloadLabel(BuildContext context, int count) {
  if (count == 1) return context.tr('1 episode');
  return context.tr('{count} episodes', {'count': '$count'});
}

String _statusLabel(AnalysisOverviewStatus status) {
  return switch (status) {
    AnalysisOverviewStatus.analysed => 'Analysed',
    AnalysisOverviewStatus.pending => 'Pending',
    AnalysisOverviewStatus.failed => 'Failed',
    AnalysisOverviewStatus.inProgress => 'In progress',
  };
}
