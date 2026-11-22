import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/segment_edit.dart';
import '../../data/skip_segments.dart';
import '../../l10n/l10n.dart';
import '../../player/player_controller.dart';
import '../widgets/messages.dart';
import 'segment_waveform_page.dart';

/// Corrige le début et la fin d’un passage détecté, par pas de 0,5 s, avec
/// une écoute autour de chaque coupe. La forme d’onde s’ouvre d’ici.
class SegmentEditorPage extends ConsumerStatefulWidget {
  const SegmentEditorPage({super.key, required this.segmentId});

  final int segmentId;

  @override
  ConsumerState<SegmentEditorPage> createState() => _SegmentEditorPageState();
}

class _SegmentEditorPageState extends ConsumerState<SegmentEditorPage> {
  SegmentEditTarget? _target;
  var _loaded = false;
  var _start = 0;
  var _end = 0;
  final _playhead = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _playhead.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final target = await loadSegmentEdit(
      ref.read(databaseProvider),
      widget.segmentId,
    );
    if (!mounted) return;
    setState(() {
      _target = target;
      _loaded = true;
      if (target != null) {
        _start = target.segment.startMs;
        _end = target.segment.endMs;
      }
    });
  }

  void _step({required bool start, required int delta}) {
    final target = _target!;
    final bounds = start
        ? clampBounds(_start + delta, _end, durationMs: target.durationMs)
        : clampBounds(_start, _end + delta, durationMs: target.durationMs);
    setState(() {
      _start = bounds.startMs;
      _end = bounds.endMs;
    });
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
          segmentId: target.segment.id,
        );
  }

  Future<void> _listenAround(int cutMs) {
    final target = _target!;
    return _listen(
      (cutMs - cutPreviewMs).clamp(0, target.durationMs),
      (cutMs + cutPreviewMs).clamp(0, target.durationMs),
    );
  }

  Future<bool> _save(int startMs, int endMs) async {
    await saveSegmentBounds(
      ref.read(databaseProvider),
      segmentId: widget.segmentId,
      startMs: startMs,
      endMs: endMs,
    );
    return true;
  }

  Future<void> _openWaveform() async {
    final target = _target!;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SegmentWaveformPage(
          envelope: target.envelope,
          durationMs: target.durationMs,
          startMs: _start,
          endMs: _end,
          onListen: _listen,
          onSave: _save,
          playhead: _playhead,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    if (target != null) {
      ref.listen(playerProvider, (_, state) {
        _playhead.value = state.episodeId == target.segment.episodeId
            ? state.position.inMilliseconds
            : null;
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Adjust bounds')),
        actions: [
          if (target != null)
            TextButton(
              onPressed: () async {
                await _save(_start, _end);
                if (context.mounted) Navigator.of(context).pop(true);
              },
              child: Text(context.tr('Save')),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : target == null
          ? Center(child: Text(context.tr('This passage no longer exists.')))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.tr(skipKindLabel(target.segment.kind)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                BoundControls(
                  id: 'start',
                  label: context.tr('Start'),
                  valueMs: _start,
                  onStep: (delta) => _step(start: true, delta: delta),
                  onListen: () => _listenAround(_start),
                ),
                BoundControls(
                  id: 'end',
                  label: context.tr('End'),
                  valueMs: _end,
                  onStep: (delta) => _step(start: false, delta: delta),
                  onListen: () => _listenAround(_end),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text(context.tr('Preview')),
                      onPressed: () => _listen(_start, _end),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.graphic_eq),
                      label: Text(context.tr('Waveform')),
                      onPressed: _openWaveform,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr(
                    'Saved bounds are kept by later analyses and become '
                    'the reference for this passage.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
