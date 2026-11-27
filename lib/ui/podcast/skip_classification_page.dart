import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/analysis_overview.dart';
import '../../data/app_database.dart';
import '../../data/audio_analysis.dart';
import '../../data/providers.dart';
import '../../settings/settings_controller.dart';
import '../../data/segment_match.dart';
import '../../data/skip_segments.dart';
import '../../l10n/l10n.dart';
import '../router.dart';
import '../settings/analysis_settings_page.dart';
import '../settings/analysis_status_mark.dart';
import '../../player/player_controller.dart';
import '../skip_kind_mark.dart';
import '../widgets/choice_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/messages.dart';
import 'passage_creation.dart';
import 'segment_editor_page.dart';

final skipClassificationProvider =
    StreamProvider.family<SkipClassification, int>((ref, podcastId) {
      return ref.watch(databaseProvider).watchSkipClassification(podcastId);
    });

class SkipClassificationPage extends ConsumerWidget {
  const SkipClassificationPage({super.key, required this.podcastId});

  final int podcastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcast = ref.watch(podcastProvider(podcastId));
    return podcast.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          title: 'Podcast introuvable',
          message: error.toString(),
        ),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              title: 'Podcast introuvable',
              message: 'Cet abonnement n’est plus dans la bibliothèque.',
            ),
          );
        }
        final theme = Theme.of(context);
        final classification = ref.watch(skipClassificationProvider(podcastId));
        ref.watch(podcastAnalysisKickProvider(podcastId));
        final analysis = ref.watch(audioAnalysisProvider);
        final pending = analysis.pendingFor(podcastId);
        final runningHere = analysis.runningPodcastId == podcastId
            ? analysis.runningEpisodeId
            : null;
        final runningTitle = runningHere == null
            ? null
            : ref
                  .watch(episodeProvider(runningHere))
                  .asData
                  ?.value
                  ?.episode
                  .title;
        final stored = ref
            .watch(analysisOverviewProvider)
            .asData
            ?.value
            .where((row) => row.id == podcastId)
            .firstOrNull;
        final status = _podcastAnalysisStatus(stored, analysis, podcastId);
        final playing = ref.watch(
          playerProvider.select((state) => state.hasEpisode),
        );
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            actions: [
              IconButton(
                key: const Key('pick-episode-for-passage'),
                tooltip: context.tr('Create a passage'),
                icon: const Icon(Icons.content_cut),
                onPressed: () => pickEpisodeForPassage(context, ref, podcastId),
              ),
            ],
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Skip ads and jingles'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    _AnalysisEntry(
                      pending: pending,
                      countLabel: context.tr(
                        'Analyzing episodes ({count} left)',
                        {'count': '$pending'},
                      ),
                      detail: pending > 0
                          ? _analysisDetail(
                              context,
                              analysis,
                              podcastId,
                              runningTitle,
                            )
                          : null,
                      remainingAt: (now) =>
                          analysis.remainingFor(podcastId, now),
                      onOpen: () => context.push(
                        AppRoutes.podcastEpisodeAnalyses(podcastId),
                      ),
                    ),
                    SwitchListTile(
                      title: Text(
                        context.tr('Analyze downloads automatically'),
                      ),
                      value: ref.watch(settingsProvider).automaticAudioAnalysis,
                      onChanged: (enabled) => ref
                          .read(settingsProvider.notifier)
                          .setAutomaticAudioAnalysis(enabled),
                    ),
                    ..._segmentTiles(context, ref, classification),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: _aboveShellChrome(context, player: playing),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: pending > 0
                                ? null
                                : () => ref
                                      .read(audioAnalysisProvider.notifier)
                                      .analyzeDownloaded(podcastId),
                            child: Text(
                              context.tr('Analyze downloaded episodes'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnalysisStatusMark(
                          status: status,
                          label: context.tr(_analysisMarkLabel(status)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _segmentTiles(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<SkipClassification> classification,
  ) {
    return classification.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, _) => [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error.toString()),
        ),
      ],
      data: (data) {
        final grouped = <SkipSegmentKind, List<_Row>>{};
        for (final template in data.templates) {
          grouped
              .putIfAbsent(template.kind, () => [])
              .add(
                _Row.template(
                  template,
                  confirmed: data.templateConfirmed[template.id],
                ),
              );
        }
        for (final loose in data.segments) {
          grouped
              .putIfAbsent(loose.segment.kind, () => [])
              .add(_Row.segment(loose));
        }
        if (grouped.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                context.tr(
                  'No passage created yet. Create one from an episode, the player or the button above: the analysis then searches for it in the other downloaded episodes.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ];
        }
        return [_RankedSegments(podcastId: podcastId, grouped: grouped)];
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label, {this.mark});

  final String label;
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: mark == null
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          if (mark != null) ...[mark!, const SizedBox(width: 8)],
          Flexible(child: Text(label, style: style)),
        ],
      ),
    );
  }
}

/// Tri par confiance. Les candidats intra-épisode peu sûrs restent derrière
/// un bouton : ils ne sont jamais sautés, le score ne fait que les ranger.
class _RankedSegments extends StatefulWidget {
  const _RankedSegments({required this.podcastId, required this.grouped});

  final int podcastId;
  final Map<SkipSegmentKind, List<_Row>> grouped;

  @override
  State<_RankedSegments> createState() => _RankedSegmentsState();
}

class _RankedSegmentsState extends State<_RankedSegments> {
  var _showUncertain = false;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    var uncertain = 0;
    for (final kind in SkipSegmentKind.values) {
      if (kind == SkipSegmentKind.sponsor) continue;
      final rows = [
        ...?widget.grouped[kind],
        if (kind == SkipSegmentKind.ad)
          ...?widget.grouped[SkipSegmentKind.sponsor],
      ];
      if (rows.isEmpty) continue;
      final sorted = [...rows]
        ..sort((a, b) {
          final byConfidence = _confidenceOf(b).compareTo(_confidenceOf(a));
          if (byConfidence != 0) return byConfidence;
          return _startOf(a).compareTo(_startOf(b));
        });
      final visible = <_Row>[];
      for (final row in sorted) {
        if (_uncertain(row)) {
          uncertain++;
          if (!_showUncertain) continue;
        }
        visible.add(row);
      }
      if (visible.isEmpty) continue;
      tiles.add(
        _Section(context.tr(skipKindLabel(kind)), mark: SkipKindMark(kind)),
      );
      for (final row in visible) {
        tiles.add(_SegmentTile(podcastId: widget.podcastId, row: row));
      }
    }
    if (uncertain > 0) {
      tiles.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _showUncertain = !_showUncertain),
              child: Text(
                _showUncertain
                    ? context.tr('Hide uncertain passages')
                    : context.tr('Show uncertain passages ({count})', {
                        'count': '$uncertain',
                      }),
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: tiles,
    );
  }
}

int _confidenceOf(_Row row) {
  final value = row.template?.confidence ?? row.loose?.segment.confidence;
  return value ?? crossEpisodeConfidence;
}

int _startOf(_Row row) {
  return row.loose?.segment.startMs ?? row.template?.id ?? 0;
}

/// Candidat d’une seule épisode, déjà ignoré pour le saut, score bas.
bool _uncertain(_Row row) {
  if (_confidenceOf(row) >= lowConfidenceCutoff) return false;
  final confirmed = row.template != null
      ? row.confirmed
      : row.loose!.segment.confirmed;
  final matches = row.template?.occurrences ?? row.loose!.segment.matches;
  return confirmed == false && matches <= 1;
}

class _Row {
  const _Row.template(this.template, {required this.confirmed}) : loose = null;

  const _Row.segment(this.loose) : template = null, confirmed = null;

  final SegmentTemplate? template;
  final LooseSkipSegment? loose;

  /// Avis du modèle. Ignoré pour un passage isolé (il a le sien).
  final bool? confirmed;

  bool get isTemplate => template != null;
}

class _SegmentTile extends ConsumerWidget {
  const _SegmentTile({required this.podcastId, required this.row});

  final int podcastId;
  final _Row row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = row.template;
    final loose = row.loose;
    final title = template != null
        ? _templateTitle(context, template)
        : loose!.episodeTitle;
    final durationMs =
        template?.durationMs ?? (loose!.segment.endMs - loose.segment.startMs);
    final count = template?.occurrences ?? loose!.segment.matches;
    final review = template != null ? row.confirmed : loose!.segment.confirmed;
    final range = loose == null
        ? null
        : '${formatClock(Duration(milliseconds: loose.segment.startMs))}'
              '–${formatClock(Duration(milliseconds: loose.segment.endMs))}';
    final source = loose?.segment.source;
    final subtitle = [
      ?range,
      formatClock(Duration(milliseconds: durationMs < 0 ? 0 : durationMs)),
      _episodeCount(context, count),
      if (source == SkipSegmentSource.network) context.tr('Network sting'),
      context.tr(_reviewKey(review)),
    ].join(' · ');
    return ListTile(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.tr('Preview'),
            icon: const Icon(Icons.play_arrow),
            onPressed: () => _preview(context, ref),
          ),
          PopupMenuButton<_SegmentAction>(
            onSelected: (action) => _run(context, ref, action),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _SegmentAction.kind,
                child: Text(context.tr('Change kind')),
              ),
              PopupMenuItem(
                value: _SegmentAction.adjust,
                child: Text(context.tr('Adjust bounds')),
              ),
              PopupMenuItem(
                value: _SegmentAction.create,
                child: Text(context.tr('Create a passage')),
              ),
              PopupMenuItem(
                value: _SegmentAction.confirm,
                child: Text(context.tr('Confirm')),
              ),
              PopupMenuItem(
                value: _SegmentAction.ignore,
                child: Text(context.tr('Ignore')),
              ),
              if (template != null)
                PopupMenuItem(
                  value: _SegmentAction.rename,
                  child: Text(context.tr('Rename')),
                ),
              PopupMenuItem(
                value: _SegmentAction.delete,
                child: Text(context.tr('Delete')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _preview(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final int episodeId;
    final int startMs;
    final int endMs;
    final int segmentId;
    final template = row.template;
    if (template != null) {
      final target = await db.previewTargetForTemplate(template.id);
      if (!context.mounted) return;
      if (target == null) {
        showMessage(
          context,
          context.tr('Download the episode to preview this passage.'),
        );
        return;
      }
      episodeId = target.episodeId;
      startMs = target.startMs;
      endMs = target.endMs;
      segmentId = target.segmentId;
    } else {
      final loose = row.loose!;
      final path = loose.downloadPath?.trim() ?? '';
      if (path.isEmpty) {
        showMessage(
          context,
          context.tr('Download the episode to preview this passage.'),
        );
        return;
      }
      episodeId = loose.segment.episodeId;
      startMs = loose.segment.startMs;
      endMs = loose.segment.endMs;
      segmentId = loose.segment.id;
    }
    final entry = await db.getEpisode(episodeId);
    if (!context.mounted) return;
    final path = entry?.episode.downloadPath?.trim() ?? '';
    if (entry == null || path.isEmpty) {
      showMessage(
        context,
        context.tr('Download the episode to preview this passage.'),
      );
      return;
    }
    await ref
        .read(playerProvider.notifier)
        .previewPassage(
          entry,
          position: Duration(milliseconds: startMs),
          end: Duration(milliseconds: endMs),
          segmentId: segmentId,
        );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _SegmentAction action,
  ) async {
    final db = ref.read(databaseProvider);
    final template = row.template;
    final segment = row.loose?.segment;
    switch (action) {
      case _SegmentAction.kind:
        final current = template?.kind ?? segment!.kind;
        final choice = await showChoiceDialog<SkipSegmentKind>(
          context,
          title: 'Change kind',
          selected: shownSkipKind(current),
          leading: (kind) => SkipKindMark(kind),
          options: [
            for (final kind in SkipSegmentKind.values)
              if (kind != SkipSegmentKind.sponsor)
                (value: kind, label: skipKindLabel(kind)),
          ],
        );
        if (choice == null || shownSkipKind(choice) == shownSkipKind(current)) {
          return;
        }
        if (template != null) {
          await db.setTemplateKind(template.id, choice);
          if (sharesAcrossPodcasts(choice)) {
            unawaited(
              ref
                  .read(audioAnalysisProvider.notifier)
                  .spreadSharedAds(
                    exceptPodcastId: podcastId,
                    templateIds: {template.id},
                  ),
            );
          }
        } else {
          await db.setSkipSegmentKind(segment!.id, choice);
        }
      case _SegmentAction.adjust:
        var segmentId = segment?.id;
        if (template != null) {
          final target = await db.previewTargetForTemplate(template.id);
          segmentId = target?.segmentId;
        }
        if (!context.mounted) return;
        final editId = segmentId;
        if (editId == null) {
          showMessage(
            context,
            context.tr('Download the episode to preview this passage.'),
          );
          return;
        }
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => SegmentEditorPage(segmentId: editId),
          ),
        );
      case _SegmentAction.create:
        var episodeId = segment?.episodeId;
        if (template != null) {
          final target = await db.previewTargetForTemplate(template.id);
          episodeId = target?.episodeId;
        }
        if (!context.mounted) return;
        if (episodeId == null) {
          await pickEpisodeForPassage(context, ref, podcastId);
          return;
        }
        await openPassageCreator(context, ref, episodeId);
      case _SegmentAction.confirm:
        if (template != null) {
          await db.setTemplateReview(template.id, confirmed: true);
        } else {
          await db.setSkipSegmentReview(segment!.id, confirmed: true);
        }
      case _SegmentAction.ignore:
        if (template != null) {
          await db.setTemplateReview(template.id, confirmed: false);
        } else {
          await db.setSkipSegmentReview(segment!.id, confirmed: false);
        }
      case _SegmentAction.rename:
        if (template == null) return;
        final label = await _askLabel(context, template.label);
        if (label == null) return;
        await db.setTemplateLabel(template.id, label);
      case _SegmentAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('Delete this passage?')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.tr('Delete')),
              ),
            ],
          ),
        );
        if (ok != true) return;
        if (template != null) {
          await db.deleteSegmentTemplate(template.id);
        } else {
          await db.deleteSkipSegment(segment!.id);
        }
        unawaited(ref.read(playerProvider.notifier).reloadSkipSegments());
    }
  }
}

enum _SegmentAction { kind, adjust, create, confirm, ignore, rename, delete }

String _templateTitle(BuildContext context, SegmentTemplate template) {
  final label = template.label?.trim() ?? '';
  if (label.isNotEmpty) return label;
  return context.tr('Unnamed pattern');
}

String _episodeCount(BuildContext context, int count) {
  if (count == 1) return context.tr('1 episode');
  return context.tr('{count} episodes', {'count': '$count'});
}

String _reviewKey(bool? confirmed) {
  if (confirmed == true) return 'Confirmed';
  if (confirmed == false) return 'Ignored';
  return 'Unreviewed';
}

Future<String?> _askLabel(BuildContext context, String? current) async {
  final controller = TextEditingController(text: current ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('Rename label')),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: context.tr('Label')),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(context.tr('Apply')),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// Hauteur de la barre du bas sur téléphone, pour laisser le bouton au-dessus.
///
/// Sur un écran large, la coque réserve déjà cet espace.
double _aboveShellChrome(BuildContext context, {required bool player}) {
  if (MediaQuery.sizeOf(context).width >= 600) return 0;
  const bar = 4.0 + 64.0 + 8.0;
  final playerSlot = player ? 56.0 + 8.0 : 0.0;
  return bar + playerSlot;
}

String? _remainingLabel(BuildContext context, Duration? remaining) {
  if (remaining == null) return null;
  if (remaining.inSeconds < 60) return context.tr('Less than a minute left');
  final minutes = (remaining.inSeconds / 60).ceil();
  if (minutes < 60) {
    return context.tr('About {minutes} min left', {'minutes': '$minutes'});
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return context.tr('About {hours} h left', {'hours': '$hours'});
  return context.tr('About {hours} h {minutes} min left', {
    'hours': '$hours',
    'minutes': '$rest',
  });
}

String _analysisDetail(
  BuildContext context,
  AudioAnalysisProgress analysis,
  int podcastId,
  String? title,
) {
  final name = title?.trim();
  final named = name != null && name.isNotEmpty;
  if (analysis.runningPodcastId != podcastId) {
    if (analysis.runningEpisodeId != null) {
      return context.tr('Finishing another podcast first');
    }
    return context.tr('Waiting in the queue');
  }
  return switch (analysis.step) {
    AnalysisStep.decoding =>
      named
          ? context.tr('Decoding the audio of {title}', {'title': name})
          : context.tr('Decoding the audio'),
    AnalysisStep.saving =>
      named
          ? context.tr('Saving the fingerprint of {title}', {'title': name})
          : context.tr('Saving the fingerprint'),
    AnalysisStep.matching =>
      named
          ? context.tr('Comparing {title} with the other episodes', {
              'title': name,
            })
          : context.tr('Comparing episodes'),
    _ =>
      named
          ? context.tr('Preparing {title}', {'title': name})
          : context.tr('Preparing the episode'),
  };
}

/// Même pastille que la gestion des analyses, pour ce podcast.
AnalysisOverviewStatus _podcastAnalysisStatus(
  AnalysisOverviewPodcast? stored,
  AudioAnalysisProgress progress,
  int podcastId,
) {
  final running = progress.runningPodcastId == podcastId;
  final queued = progress.pending.any((job) => job.podcastId == podcastId);
  if (stored != null && !running && !queued) return stored.status;
  if (running || queued) {
    return analysisStatus(
      fingerprintStatuses: const [],
      running: running,
      queued: queued,
    );
  }
  return AnalysisOverviewStatus.pending;
}

String _analysisMarkLabel(AnalysisOverviewStatus status) {
  return switch (status) {
    AnalysisOverviewStatus.analysed => 'Analysed',
    AnalysisOverviewStatus.pending => 'Pending',
    AnalysisOverviewStatus.failed => 'Failed',
    AnalysisOverviewStatus.inProgress => 'In progress',
  };
}

/// Une seule ligne : le détail des étapes, et l’avancement quand il y en a.
class _AnalysisEntry extends StatefulWidget {
  const _AnalysisEntry({
    required this.pending,
    required this.countLabel,
    required this.detail,
    required this.remainingAt,
    required this.onOpen,
  });

  final int pending;
  final String countLabel;
  final String? detail;
  final Duration? Function(DateTime now) remainingAt;
  final VoidCallback onOpen;

  @override
  State<_AnalysisEntry> createState() => _AnalysisEntryState();
}

class _AnalysisEntryState extends State<_AnalysisEntry> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncTick();
  }

  @override
  void didUpdateWidget(covariant _AnalysisEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTick();
  }

  void _syncTick() {
    if (widget.pending <= 0) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
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
    final theme = Theme.of(context);
    final busy = widget.pending > 0;
    final remaining = busy
        ? _remainingLabel(context, widget.remainingAt(DateTime.now()))
        : null;
    final subtle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListTile(
      title: Text(busy ? widget.countLabel : context.tr('Analysis details')),
      subtitle: busy && widget.detail != null
          ? Text(widget.detail!, style: subtle)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (remaining != null) ...[
            Text(remaining, style: subtle),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: widget.onOpen,
    );
  }
}
