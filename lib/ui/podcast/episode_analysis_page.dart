import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/analysis_overview.dart';
import '../../data/audio_analysis.dart';
import '../../data/episode_analysis.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../settings/analysis_status_mark.dart';
import '../widgets/empty_state.dart';
import '../widgets/list_metrics.dart';

final episodeAnalysisSnapshotsProvider =
    FutureProvider.family<List<EpisodeAnalysisSnapshot>, int>((ref, podcastId) {
      ref.watch(
        audioAnalysisProvider.select(
          (progress) => (
            progress.runningEpisodeId,
            progress.step,
            progress.pending.length,
          ),
        ),
      );
      return ref
          .watch(databaseProvider)
          .episodeAnalysisFacts(podcastId)
          .then(
            (rows) => [
              for (final row in rows)
                EpisodeAnalysisSnapshot(
                  episodeId: row.episodeId,
                  title: row.title,
                  fingerprintStatus: row.fingerprintStatus,
                  chromaprint: row.chromaprint,
                ),
            ],
          );
    });

class EpisodeAnalysisPage extends ConsumerWidget {
  const EpisodeAnalysisPage({super.key, required this.podcastId});

  final int podcastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshots = ref.watch(episodeAnalysisSnapshotsProvider(podcastId));
    final progress = ref.watch(audioAnalysisProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Analysis details'))),
      body: snapshots.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          title: context.tr('Analysis details'),
          message: error.toString(),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              title: context.tr('Analysis details'),
              message: context.tr('No downloaded episodes to analyse.'),
            );
          }
          return _AnalysisList(rows: rows, progress: progress);
        },
      ),
    );
  }
}

class _AnalysisList extends StatefulWidget {
  const _AnalysisList({required this.rows, required this.progress});

  final List<EpisodeAnalysisSnapshot> rows;
  final AudioAnalysisProgress progress;

  @override
  State<_AnalysisList> createState() => _AnalysisListState();
}

class _AnalysisListState extends State<_AnalysisList> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final queued = {for (final job in progress.pending) job.episodeId};
    final now = DateTime.now();
    final pace = _pace(progress);
    final views = [
      for (final row in widget.rows)
        describeEpisodeAnalysis(
          row,
          running: progress.runningEpisodeId == row.episodeId,
          runningPhase: progress.runningEpisodeId == row.episodeId
              ? _phase(progress.step)
              : null,
          queued: queued.contains(row.episodeId),
        ),
    ];
    return ListView(
      padding: underChrome(context, const EdgeInsets.only(bottom: 32)),
      children: [
        for (final view in views)
          _EpisodeAnalysisTile(
            view: view,
            percent: _percentLabel(
              context,
              view,
              decodeFraction:
                  progress.runningEpisodeId == view.episodeId &&
                      progress.step == AnalysisStep.decoding &&
                      pace != null &&
                      pace.expected > 0
                  ? pace.samples / pace.expected
                  : null,
            ),
            remaining: _label(
              context,
              episodeRemaining(
                episodeId: view.episodeId,
                runningEpisodeId: progress.runningEpisodeId,
                runningDurationSeconds: progress.runningDurationSeconds,
                runningSince: progress.runningSince,
                decoding: progress.step == AnalysisStep.decoding,
                pending: [
                  for (final job in progress.pending)
                    (
                      episodeId: job.episodeId,
                      durationSeconds: job.durationSeconds,
                    ),
                ],
                now: now,
                pace: pace,
                measuredMs: progress.measuredMs,
                measuredAudioSeconds: progress.measuredAudioSeconds,
              ),
            ),
          ),
      ],
    );
  }
}

DecodePace? _pace(AudioAnalysisProgress progress) {
  final samples = progress.decodeSamples;
  final expected = progress.decodeExpected;
  final rate = progress.decodeSampleRate;
  final started = progress.decodeStarted;
  if (samples == null ||
      expected == null ||
      rate == null ||
      started == null ||
      samples <= 0) {
    return null;
  }
  return DecodePace(
    samples: samples,
    expected: expected,
    sampleRate: rate,
    started: started,
  );
}

String? _percentLabel(
  BuildContext context,
  EpisodeAnalysisView view, {
  double? decodeFraction,
}) {
  if (view.status == AnalysisOverviewStatus.analysed) return null;
  final percent = groupedStepPercent(
    view.steps,
    decodeFraction: decodeFraction,
  );
  return context.tr('{percent} %', {'percent': '$percent'});
}

String? _label(BuildContext context, Duration? remaining) {
  if (remaining == null) return null;
  final total = remaining.inSeconds;
  return context.tr('{minutes} min {seconds} s', {
    'minutes': '${total ~/ 60}',
    'seconds': (total % 60).toString().padLeft(2, '0'),
  });
}

int _phase(AnalysisStep? step) {
  return switch (step) {
    AnalysisStep.decoding => 1,
    AnalysisStep.saving => 2,
    AnalysisStep.matching => 3,
    _ => 0,
  };
}

class _EpisodeAnalysisTile extends StatelessWidget {
  const _EpisodeAnalysisTile({
    required this.view,
    required this.percent,
    required this.remaining,
  });

  final EpisodeAnalysisView view;
  final String? percent;
  final String? remaining;

  @override
  Widget build(BuildContext context) {
    final label = context.tr(_statusLabel(view.status));
    return ExpansionTile(
      key: PageStorageKey<int>(view.episodeId),
      initiallyExpanded: view.status == AnalysisOverviewStatus.inProgress,
      leading: AnalysisStatusMark(status: view.status, label: label),
      title: Row(
        children: [
          Expanded(
            child: Text(
              view.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (percent != null) ...[
            const SizedBox(width: 12),
            Text(
              percent!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      childrenPadding: const EdgeInsets.fromLTRB(28, 0, 16, 12),
      children: [
        for (final step in view.steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                AnalysisStatusMark(
                  status: step.status,
                  label: context.tr(_statusLabel(step.status)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(episodeAnalysisPhaseLabel[step.phase]!),
                  ),
                ),
                if (remaining != null &&
                    step.status == AnalysisOverviewStatus.inProgress &&
                    step.phase == EpisodeAnalysisPhase.decoding) ...[
                  const SizedBox(width: 12),
                  Text(
                    remaining!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

String _statusLabel(AnalysisOverviewStatus status) {
  return switch (status) {
    AnalysisOverviewStatus.analysed => 'Analysed',
    AnalysisOverviewStatus.pending => 'Pending',
    AnalysisOverviewStatus.failed => 'Failed',
    AnalysisOverviewStatus.inProgress => 'In progress',
  };
}
