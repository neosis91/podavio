import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../data/audio_analysis.dart';
import '../../data/providers.dart';
import '../../data/segment_edit.dart';
import '../../data/skip_segments.dart';
import '../../l10n/l10n.dart';
import '../../player/player_controller.dart';
import '../skip_kind_mark.dart';
import '../widgets/messages.dart';
import 'segment_waveform_page.dart';

/// Pose ou corrige un passage : forme d’onde en haut, type, nom et bornes
/// sur la même page. L’écoute se fait autour de chaque coupe, par pas de 0,5 s.
///
/// [SegmentEditorPage.create] pose un nouveau passage, à partir de la
/// position de lecture, avec son type et un nom facultatif.
class SegmentEditorPage extends ConsumerStatefulWidget {
  const SegmentEditorPage({super.key, required int this.segmentId})
    : episodeId = null,
      positionMs = 0;

  const SegmentEditorPage.create({
    super.key,
    required int this.episodeId,
    required this.positionMs,
  }) : segmentId = null;

  final int? segmentId;
  final int? episodeId;

  /// Début proposé pour un nouveau passage.
  final int positionMs;

  bool get creating => segmentId == null;

  @override
  ConsumerState<SegmentEditorPage> createState() => _SegmentEditorPageState();
}

class _SegmentEditorPageState extends ConsumerState<SegmentEditorPage> {
  SegmentEditTarget? _target;
  var _loaded = false;
  var _start = 0;
  var _end = 0;
  var _kind = SkipSegmentKind.ad;
  final _name = TextEditingController();
  final _playhead = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _playhead.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final database = ref.read(databaseProvider);
    final target = widget.creating
        ? await loadSegmentCreate(database, widget.episodeId!)
        : await loadSegmentEdit(database, widget.segmentId!);
    if (!mounted) return;
    final player = ref.read(playerProvider);
    if (target != null && player.episodeId == target.entry.episode.id) {
      _playhead.value = player.position.inMilliseconds;
    }
    setState(() {
      _target = target;
      _loaded = true;
      if (target == null) return;
      final segment = target.segment;
      if (segment != null) {
        _start = segment.startMs;
        _end = segment.endMs;
        _kind = segment.kind;
      } else {
        final bounds = initialCreatedBounds(
          widget.positionMs,
          durationMs: target.durationMs,
        );
        _start = bounds.startMs;
        _end = bounds.endMs;
      }
    });
  }

  void _setBounds({required bool start, required int ms}) {
    final target = _target!;
    final bounds = start
        ? clampBounds(ms, _end, durationMs: target.durationMs)
        : clampBounds(_start, ms, durationMs: target.durationMs);
    setState(() {
      _start = bounds.startMs;
      _end = bounds.endMs;
    });
  }

  void _step({required bool start, required int delta}) {
    _setBounds(start: start, ms: (start ? _start : _end) + delta);
  }

  Future<void> _listen(int fromMs, int toMs) async {
    final target = _target!;
    final path = target.entry.episode.downloadPath?.trim() ?? '';
    if (path.isEmpty) {
      showMessage(
        context,
        context.tr('Download the episode to preview this passage.'),
      );
      return;
    }
    await ref
        .read(playerProvider.notifier)
        .previewPassage(
          target.entry,
          position: Duration(milliseconds: fromMs),
          end: Duration(milliseconds: toMs),
          segmentId: target.segment?.id,
        );
  }

  Future<void> _listenAround(int cutMs) {
    final target = _target!;
    return _listen(
      (cutMs - cutPreviewMs).clamp(0, target.durationMs),
      (cutMs + cutPreviewMs).clamp(0, target.durationMs),
    );
  }

  Future<int?> _templateId(AppDatabase database, int segmentId) async {
    final segment = await database.skipSegmentById(segmentId);
    return segment?.templateId;
  }

  Future<void> _searchPassage({
    required int podcastId,
    required Set<int> templateIds,
  }) async {
    await ref
        .read(audioAnalysisProvider.notifier)
        .analyzeDownloaded(podcastId, spreadTemplateIds: templateIds);
  }

  Future<bool> _save(int startMs, int endMs) async {
    final database = ref.read(databaseProvider);
    final target = _target!;
    if (widget.creating) {
      final created = await createManualSegment(
        database,
        episodeId: target.entry.episode.id,
        startMs: startMs,
        endMs: endMs,
        kind: _kind,
        label: _name.text,
      );
      if (created.segmentId == null) {
        if (mounted) {
          showMessage(
            context,
            context.tr(
              'This passage overlaps one placed by hand. Adjust that one '
              'instead.',
            ),
          );
        }
        return false;
      }
      final templateId = await _templateId(database, created.segmentId!);
      unawaited(
        _searchPassage(
          podcastId: target.entry.episode.podcastId,
          templateIds: sharesAcrossPodcasts(_kind) && templateId != null
              ? {templateId}
              : const {},
        ),
      );
    } else {
      await saveSegmentBounds(
        database,
        segmentId: widget.segmentId!,
        startMs: startMs,
        endMs: endMs,
      );
      final segment = target.segment!;
      if (shownSkipKind(_kind) != shownSkipKind(segment.kind)) {
        final templateId = segment.templateId;
        if (templateId != null) {
          await database.setTemplateKind(templateId, _kind);
        } else {
          await database.setSkipSegmentKind(widget.segmentId!, _kind);
        }
      }
      if (sharesAcrossPodcasts(_kind)) {
        final id = segment.templateId;
        if (id != null) {
          unawaited(
            ref
                .read(audioAnalysisProvider.notifier)
                .spreadSharedAds(
                  exceptPodcastId: target.entry.episode.podcastId,
                  templateIds: {id},
                ),
          );
        }
      }
    }
    unawaited(ref.read(playerProvider.notifier).reloadSkipSegments());
    return true;
  }

  Future<void> _delete() async {
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
    if (ok != true || !mounted) return;
    await deleteManualSegment(ref.read(databaseProvider), widget.segmentId!);
    unawaited(ref.read(playerProvider.notifier).reloadSkipSegments());
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    if (target != null) {
      ref.listen(playerProvider, (_, state) {
        _playhead.value = state.episodeId == target.entry.episode.id
            ? state.position.inMilliseconds
            : null;
      });
    }
    final manual = target?.segment?.source == SkipSegmentSource.manual;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(widget.creating ? 'New passage' : 'Adjust bounds'),
        ),
        actions: [
          if (target != null && manual)
            IconButton(
              tooltip: context.tr('Delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          if (target != null)
            TextButton(
              onPressed: () async {
                final saved = await _save(_start, _end);
                if (saved && context.mounted) Navigator.of(context).pop(true);
              },
              child: Text(context.tr('Save')),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : target == null
          ? Center(child: Text(context.tr('This passage no longer exists.')))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SegmentWaveform(
                    envelope: target.envelope,
                    durationMs: target.durationMs,
                    startMs: _start,
                    endMs: _end,
                    accent: Color(skipKindArgb(shownSkipKind(_kind))),
                    others: [
                      for (final segment
                          in ref
                                  .watch(
                                    activeSkipSegmentsProvider(
                                      target.entry.episode.id,
                                    ),
                                  )
                                  .value ??
                              const <SkipSegment>[])
                        if (segment.id != widget.segmentId &&
                            segment.endMs > segment.startMs)
                          WaveformSpan(
                            startMs: segment.startMs,
                            endMs: segment.endMs,
                            color: Color(skipKindArgb(segment.kind)),
                          ),
                    ],
                    playhead: _playhead,
                    onBounds: (start, end) => setState(() {
                      _start = start;
                      _end = end;
                    }),
                    onListen: _listen,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<SkipSegmentKind>(
                        key: const Key('segment-kind'),
                        initialValue: shownSkipKind(_kind),
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.tr('Kind'),
                        ),
                        items: [
                          for (final kind in SkipSegmentKind.values)
                            if (kind != SkipSegmentKind.sponsor)
                              DropdownMenuItem(
                                value: kind,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SkipKindMark(kind, size: 12),
                                    const SizedBox(width: 8),
                                    Text(context.tr(skipKindLabel(kind))),
                                  ],
                                ),
                              ),
                        ],
                        onChanged: (kind) {
                          if (kind == null || shownSkipKind(_kind) == kind) {
                            return;
                          }
                          setState(() => _kind = kind);
                        },
                      ),
                      if (widget.creating) ...[
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('segment-name'),
                          controller: _name,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: context.tr('Name (optional)'),
                          ),
                        ),
                      ],
                      ValueListenableBuilder<int?>(
                        valueListenable: _playhead,
                        builder: (context, playhead, _) => Column(
                          children: [
                            BoundControls(
                              id: 'start',
                              label: context.tr('Start'),
                              valueMs: _start,
                              onStep: (delta) =>
                                  _step(start: true, delta: delta),
                              onListen: () => _listenAround(_start),
                              onHere: playhead == null
                                  ? null
                                  : () => _setBounds(start: true, ms: playhead),
                            ),
                            BoundControls(
                              id: 'end',
                              label: context.tr('End'),
                              valueMs: _end,
                              onStep: (delta) =>
                                  _step(start: false, delta: delta),
                              onListen: () => _listenAround(_end),
                              onHere: playhead == null
                                  ? null
                                  : () =>
                                        _setBounds(start: false, ms: playhead),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: Text(context.tr('Preview')),
                          onPressed: () => _listen(_start, _end),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr(
                          widget.creating
                              ? 'A passage placed by hand is kept by later '
                                    'analyses and searched for in the other '
                                    'episodes.'
                              : 'Saved bounds are kept by later analyses and '
                                    'become the reference for this passage.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
