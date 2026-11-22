import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/segment_edit.dart';
import '../../l10n/l10n.dart';

/// Lecture de [fromMs] à [toMs] dans l’épisode du passage.
typedef PassageListener = Future<void> Function(int fromMs, int toMs);

/// Enregistre les bornes ; renvoie `false` si rien n’a été écrit.
typedef BoundsSaver = Future<bool> Function(int startMs, int endMs);

/// Écoute depuis le curseur.
const cursorPlayMs = 10000;

/// Fenêtre la plus étroite du zoom.
const minWaveViewMs = 4000;

/// Forme d’onde autour d’un passage, avec poignées de début et de fin.
///
/// L’onde vient de l’enveloppe RMS 20 ms calculée à l’analyse, stockée avec
/// l’empreinte : rien à redécoder. Les bornes suivent les mêmes règles que
/// les boutons ±0,5 s de l’éditeur, et l’enregistrement passe par le même
/// chemin (empreinte Chromaprint retaillée, passage validé, vérité terrain).
class SegmentWaveformPage extends StatefulWidget {
  const SegmentWaveformPage({
    super.key,
    required this.envelope,
    required this.durationMs,
    required this.startMs,
    required this.endMs,
    required this.onListen,
    required this.onSave,
    this.playhead,
  });

  final Uint8List? envelope;
  final int durationMs;
  final int startMs;
  final int endMs;
  final PassageListener onListen;
  final BoundsSaver onSave;

  /// Position de lecture dans cet épisode, `null` s’il ne joue pas.
  final ValueListenable<int?>? playhead;

  @override
  State<SegmentWaveformPage> createState() => _SegmentWaveformPageState();
}

enum _Handle { start, end }

class _SegmentWaveformPageState extends State<SegmentWaveformPage> {
  late int _start = widget.startMs;
  late int _end = widget.endMs;
  late int _cursor = widget.startMs;
  late int _viewStart;
  late int _viewEnd;
  _Handle? _dragging;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final context = math.max(10000, (_end - _start) ~/ 2);
    _setView(_start - context, _end + context);
  }

  void _setView(int from, int to) {
    final span = math.min(
      math.max(to - from, minWaveViewMs),
      math.max(widget.durationMs, minWaveViewMs),
    );
    var start = from;
    if (start + span > widget.durationMs) start = widget.durationMs - span;
    if (start < 0) start = 0;
    _viewStart = start;
    _viewEnd = start + span;
  }

  void _zoom(double factor) {
    setState(() {
      final span = ((_viewEnd - _viewStart) * factor).round();
      _setView(_cursor - span ~/ 2, _cursor + span - span ~/ 2);
    });
  }

  void _move(_Handle handle, int ms) {
    final bounds = handle == _Handle.start
        ? clampBounds(ms, _end, durationMs: widget.durationMs)
        : clampBounds(_start, ms, durationMs: widget.durationMs);
    setState(() {
      _start = bounds.startMs;
      _end = bounds.endMs;
    });
  }

  int _msAt(double dx, double width) {
    final ratio = (dx / width).clamp(0.0, 1.0);
    return (_viewStart + ratio * (_viewEnd - _viewStart)).round();
  }

  double _xOf(int ms, double width) {
    return (ms - _viewStart) / (_viewEnd - _viewStart) * width;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await widget.onSave(_start, _end);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Waveform')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(context.tr('Save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 180,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  key: const Key('waveform'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => setState(
                    () => _cursor = _msAt(details.localPosition.dx, width),
                  ),
                  onHorizontalDragStart: (details) {
                    final x = details.localPosition.dx;
                    final toStart = (x - _xOf(_start, width)).abs();
                    final toEnd = (x - _xOf(_end, width)).abs();
                    _dragging = toStart <= toEnd ? _Handle.start : _Handle.end;
                  },
                  onHorizontalDragUpdate: (details) {
                    final handle = _dragging;
                    if (handle == null) return;
                    _move(handle, _msAt(details.localPosition.dx, width));
                  },
                  onHorizontalDragEnd: (_) => _dragging = null,
                  child: ValueListenableBuilder<int?>(
                    valueListenable:
                        widget.playhead ?? ValueNotifier<int?>(null),
                    builder: (context, playhead, _) => CustomPaint(
                      size: Size(width, 180),
                      painter: WaveformPainter(
                        columns: widget.envelope == null
                            ? const []
                            : waveformColumns(
                                widget.envelope!,
                                startMs: _viewStart,
                                endMs: _viewEnd,
                                columns: math.max(1, width ~/ 3),
                              ),
                        viewStartMs: _viewStart,
                        viewEndMs: _viewEnd,
                        startMs: _start,
                        endMs: _end,
                        cursorMs: _cursor,
                        playheadMs: playhead,
                        wave: scheme.onSurfaceVariant,
                        region: scheme.primary,
                        cursor: scheme.tertiary,
                        playheadColor: scheme.error,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.envelope == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.tr('Analyse the episode to see its waveform.'),
              ),
            ),
          Row(
            children: [
              Text(_clock(_viewStart)),
              const Spacer(),
              IconButton(
                tooltip: context.tr('Zoom out'),
                icon: const Icon(Icons.zoom_out),
                onPressed: () => _zoom(2),
              ),
              IconButton(
                tooltip: context.tr('Zoom in'),
                icon: const Icon(Icons.zoom_in),
                onPressed: () => _zoom(0.5),
              ),
              const Spacer(),
              Text(_clock(_viewEnd)),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Cursor')),
            subtitle: Text(_clock(_cursor)),
            trailing: FilledButton.tonalIcon(
              icon: const Icon(Icons.play_arrow),
              label: Text(context.tr('Play from cursor')),
              onPressed: () => widget.onListen(
                _cursor,
                math.min(_cursor + cursorPlayMs, widget.durationMs),
              ),
            ),
          ),
          BoundControls(
            id: 'start',
            label: context.tr('Start'),
            valueMs: _start,
            onStep: (delta) => _move(_Handle.start, _start + delta),
            onListen: () => _listenAround(_start),
          ),
          BoundControls(
            id: 'end',
            label: context.tr('End'),
            valueMs: _end,
            onStep: (delta) => _move(_Handle.end, _end + delta),
            onListen: () => _listenAround(_end),
          ),
        ],
      ),
    );
  }

  Future<void> _listenAround(int cutMs) {
    return widget.onListen(
      math.max(0, cutMs - cutPreviewMs),
      math.min(widget.durationMs, cutMs + cutPreviewMs),
    );
  }
}

String _clock(int ms) {
  final tenths = (ms % 1000) ~/ 100;
  return '${formatClock(Duration(milliseconds: ms))}.$tenths';
}

/// Une borne : heure au dixième, ±0,5 s, écoute autour de la coupe.
class BoundControls extends StatelessWidget {
  const BoundControls({
    super.key,
    required this.id,
    required this.label,
    required this.valueMs,
    required this.onStep,
    required this.onListen,
  });

  /// `start` ou `end`, pour les clés des boutons.
  final String id;
  final String label;
  final int valueMs;
  final ValueChanged<int> onStep;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(_clock(valueMs)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('$id-minus'),
            tooltip: context.tr('0.5 s earlier'),
            icon: const Icon(Icons.remove),
            onPressed: () => onStep(-boundaryStepMs),
          ),
          IconButton(
            key: Key('$id-plus'),
            tooltip: context.tr('0.5 s later'),
            icon: const Icon(Icons.add),
            onPressed: () => onStep(boundaryStepMs),
          ),
          IconButton(
            tooltip: context.tr('Listen around the cut'),
            icon: const Icon(Icons.hearing),
            onPressed: onListen,
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  const WaveformPainter({
    required this.columns,
    required this.viewStartMs,
    required this.viewEndMs,
    required this.startMs,
    required this.endMs,
    required this.cursorMs,
    required this.playheadMs,
    required this.wave,
    required this.region,
    required this.cursor,
    required this.playheadColor,
  });

  final List<WaveColumn> columns;
  final int viewStartMs;
  final int viewEndMs;
  final int startMs;
  final int endMs;
  final int cursorMs;
  final int? playheadMs;
  final Color wave;
  final Color region;
  final Color cursor;
  final Color playheadColor;

  double _x(int ms, Size size) {
    return (ms - viewStartMs) / (viewEndMs - viewStartMs) * size.width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final left = _x(startMs, size).clamp(0.0, size.width);
    final right = _x(endMs, size).clamp(0.0, size.width);
    canvas.drawRect(
      Rect.fromLTRB(left, 0, right, size.height),
      Paint()..color = region.withValues(alpha: 0.18),
    );
    final mid = size.height / 2;
    if (columns.isNotEmpty) {
      final step = size.width / columns.length;
      final peak = Paint()..color = wave.withValues(alpha: 0.45);
      final rms = Paint()..color = wave;
      for (var i = 0; i < columns.length; i++) {
        final x = i * step;
        final column = columns[i];
        final p = column.peak * mid;
        final r = column.rms * mid;
        canvas.drawRect(
          Rect.fromLTRB(x, mid - p, x + step * 0.8, mid + p),
          peak,
        );
        canvas.drawRect(
          Rect.fromLTRB(x, mid - r, x + step * 0.8, mid + r),
          rms,
        );
      }
    }
    final handle = Paint()
      ..color = region
      ..strokeWidth = 3;
    for (final ms in [startMs, endMs]) {
      final x = _x(ms, size);
      if (x < 0 || x > size.width) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), handle);
      canvas.drawCircle(Offset(x, size.height - 8), 8, handle);
    }
    _line(canvas, size, cursorMs, cursor, 1.5);
    final play = playheadMs;
    if (play != null) _line(canvas, size, play, playheadColor, 2);
  }

  void _line(Canvas canvas, Size size, int ms, Color color, double width) {
    final x = _x(ms, size);
    if (x < 0 || x > size.width) return;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(WaveformPainter old) {
    return old.columns != columns ||
        old.viewStartMs != viewStartMs ||
        old.viewEndMs != viewEndMs ||
        old.startMs != startMs ||
        old.endMs != endMs ||
        old.cursorMs != cursorMs ||
        old.playheadMs != playheadMs;
  }
}
