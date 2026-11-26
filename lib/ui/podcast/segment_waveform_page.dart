import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/segment_edit.dart';
import '../../l10n/l10n.dart';

/// Lecture de [fromMs] à [toMs] dans l’épisode du passage.
typedef PassageListener = Future<void> Function(int fromMs, int toMs);

/// Écoute depuis le curseur.
const cursorPlayMs = 10000;

/// Fenêtre la plus étroite du zoom.
const minWaveViewMs = 4000;

/// Distance autour d’une poignée où le doigt la saisit.
const _handleSlop = 28.0;

/// Autre passage du même épisode, dessiné sans poignée.
class WaveformSpan {
  const WaveformSpan({
    required this.startMs,
    required this.endMs,
    required this.color,
  });

  final int startMs;
  final int endMs;
  final Color color;
}

/// Forme d’onde autour d’un passage, avec poignées de début et de fin.
///
/// L’onde vient de l’enveloppe RMS 20 ms calculée à l’analyse, stockée avec
/// l’empreinte : rien à redécoder. Une poignée se glisse, le reste de la
/// vue se déplace, et deux doigts zooment. L’enregistrement reste sur la
/// page qui contient ce bloc.
class SegmentWaveform extends StatefulWidget {
  const SegmentWaveform({
    super.key,
    required this.envelope,
    required this.durationMs,
    required this.startMs,
    required this.endMs,
    required this.onBounds,
    required this.onListen,
    this.playhead,
    this.accent,
    this.others = const [],
  });

  final Uint8List? envelope;
  final int durationMs;
  final int startMs;
  final int endMs;
  final void Function(int startMs, int endMs) onBounds;
  final PassageListener onListen;

  /// Position de lecture dans cet épisode, `null` s’il ne joue pas.
  final ValueListenable<int?>? playhead;

  /// Couleur du passage. Sans elle, les poignées restent neutres.
  final Color? accent;

  /// Autres passages du même épisode. Un épisode peut en porter plusieurs.
  final List<WaveformSpan> others;

  @override
  State<SegmentWaveform> createState() => _SegmentWaveformState();
}

final _noPlayhead = ValueNotifier<int?>(null);

enum _Handle { start, end }

class _SegmentWaveformState extends State<SegmentWaveform> {
  late int _cursor = widget.startMs;
  late int _viewStart;
  late int _viewEnd;
  _Handle? _dragging;
  int? _dragMs;
  var _gestureX = 0.0;
  var _gestureView = 0;
  var _gestureSpan = 1;
  var _pointerMoved = 0.0;
  double? _pinchBase;
  final _pointers = <int, Offset>{};

  var _settled = false;
  List<WaveColumn> _columns = const [];
  var _columnViewStart = 0;
  var _columnViewEnd = 0;
  var _columnCount = -1;
  Uint8List? _columnEnvelope;

  /// Colonnes de l’onde pour la vue et la largeur courantes.
  /// Recalculées seulement quand l’un des deux change.
  List<WaveColumn> _columnsFor(double width) {
    final envelope = widget.envelope;
    if (envelope == null) return const [];
    final count = math.max(1, width ~/ 3);
    if (identical(_columnEnvelope, envelope) &&
        _columnViewStart == _viewStart &&
        _columnViewEnd == _viewEnd &&
        _columnCount == count) {
      return _columns;
    }
    _columnEnvelope = envelope;
    _columnViewStart = _viewStart;
    _columnViewEnd = _viewEnd;
    _columnCount = count;
    return _columns = waveformColumns(
      envelope,
      startMs: _viewStart,
      endMs: _viewEnd,
      columns: count,
    );
  }

  @override
  void initState() {
    super.initState();
    _frame();
  }

  @override
  void didUpdateWidget(SegmentWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging != null) return;
    if (!_settled && !_sameWaveSpans(widget.others, oldWidget.others)) {
      _frame();
    }
    if (oldWidget.startMs != widget.startMs) _reveal(widget.startMs);
    if (oldWidget.endMs != widget.endMs) _reveal(widget.endMs);
  }

  void _frame() {
    var from = widget.startMs;
    var to = widget.endMs;
    for (final span in widget.others) {
      if (span.endMs < widget.startMs - 60000) continue;
      if (span.startMs > widget.endMs + 60000) continue;
      if (span.startMs < from) from = span.startMs;
      if (span.endMs > to) to = span.endMs;
    }
    final pad = math.max(10000, (to - from) ~/ 2);
    _setView(from - pad, to + pad);
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
    _settled = true;
    setState(() {
      final span = ((_viewEnd - _viewStart) * factor).round();
      final focus = (widget.startMs + widget.endMs) ~/ 2;
      _setView(focus - span ~/ 2, focus + span - span ~/ 2);
    });
  }

  void _reveal(int ms) {
    final span = _viewEnd - _viewStart;
    final margin = math.max(500, (span * 0.12).round());
    if (ms < _viewStart + margin) {
      _setView(ms - margin, ms - margin + span);
    } else if (ms > _viewEnd - margin) {
      _setView(ms + margin - span, ms + margin);
    }
  }

  void _move(_Handle handle, int ms) {
    final bounds = handle == _Handle.start
        ? clampBounds(ms, widget.endMs, durationMs: widget.durationMs)
        : clampBounds(widget.startMs, ms, durationMs: widget.durationMs);
    final moved = handle == _Handle.start ? bounds.startMs : bounds.endMs;
    _dragMs = moved;
    _reveal(moved);
    widget.onBounds(bounds.startMs, bounds.endMs);
  }

  int _boundOf(_Handle handle) {
    return handle == _Handle.start ? widget.startMs : widget.endMs;
  }

  _Handle? _handleAt(double x, double width) {
    _Handle? best;
    var bestDist = _handleSlop;
    for (final handle in _Handle.values) {
      final hx = _xOf(_boundOf(handle), width);
      if (hx < -_handleSlop || hx > width + _handleSlop) continue;
      final dist = (x - hx).abs();
      if (dist <= bestDist) {
        best = handle;
        bestDist = dist;
      }
    }
    return best;
  }

  int _msAt(double dx, double width) {
    final ratio = (dx / width).clamp(0.0, 1.0);
    return (_viewStart + ratio * (_viewEnd - _viewStart)).round();
  }

  double _xOf(int ms, double width) {
    return (ms - _viewStart) / (_viewEnd - _viewStart) * width;
  }

  void _pointerDown(PointerDownEvent event, double width) {
    _settled = true;
    final previous = _pointers[event.pointer];
    _pointers[event.pointer] = event.localPosition;
    if (previous != null) return;
    _pointerMoved = 0;
    if (_pointers.length == 1) {
      _gestureX = event.localPosition.dx;
      _gestureView = _viewStart;
      _gestureSpan = math.max(1, _viewEnd - _viewStart);
      _dragging = _handleAt(_gestureX, width);
      _dragMs = _dragging == null ? null : _boundOf(_dragging!);
      return;
    }
    _dragging = null;
    _dragMs = null;
    _gestureSpan = math.max(1, _viewEnd - _viewStart);
    _gestureView = _viewStart;
    _gestureX = _pointerMid().dx;
    _pinchBase = _pointerSpread();
  }

  void _pointerMove(PointerMoveEvent event, double width) {
    final previous = _pointers[event.pointer];
    if (previous == null) return;
    _pointerMoved += (event.localPosition - previous).distance;
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length >= 2) {
      final base = _pinchBase;
      if (base == null || base < 1) return;
      final scale = _pointerSpread() / base;
      if (scale <= 0) return;
      final span = (_gestureSpan / scale).round();
      final ratio = (_gestureX / width).clamp(0.0, 1.0);
      final focus = _gestureView + (ratio * _gestureSpan).round();
      final left = focus - (span * ratio).round();
      setState(() => _setView(left, left + span));
      return;
    }
    final handle = _dragging;
    if (handle != null) {
      final span = math.max(1, _viewEnd - _viewStart);
      final delta = ((event.localPosition.dx - _gestureX) / width * span)
          .round();
      _gestureX = event.localPosition.dx;
      if (delta != 0) _move(handle, (_dragMs ?? _boundOf(handle)) + delta);
      return;
    }
    final shift = -((event.localPosition.dx - _gestureX) / width * _gestureSpan)
        .round();
    setState(
      () => _setView(_gestureView + shift, _gestureView + _gestureSpan + shift),
    );
  }

  void _pointerUp(PointerUpEvent event, double width) {
    final position = _pointers.remove(event.pointer) ?? event.localPosition;
    if (_pointers.length == 1) {
      _dragging = null;
      _dragMs = null;
      _pinchBase = null;
      _gestureX = _pointers.values.first.dx;
      _gestureView = _viewStart;
      _gestureSpan = math.max(1, _viewEnd - _viewStart);
      return;
    }
    if (_pointers.isNotEmpty) return;
    final handle = _dragging;
    final moved = _pointerMoved;
    _dragging = null;
    _dragMs = null;
    _pinchBase = null;
    if (moved >= 8) return;
    if (handle != null) {
      _listenAround(_boundOf(handle));
      return;
    }
    setState(() => _cursor = _msAt(position.dx, width));
  }

  Offset _pointerMid() {
    var sum = Offset.zero;
    for (final point in _pointers.values) {
      sum += point;
    }
    return sum / _pointers.length.toDouble();
  }

  double _pointerSpread() {
    final points = _pointers.values.toList();
    if (points.length < 2) return 0;
    return (points[0] - points[1]).distance;
  }

  void _listenAround(int cutMs) {
    widget.onListen(
      math.max(0, cutMs - cutPreviewMs),
      math.min(widget.durationMs, cutMs + cutPreviewMs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.accent ?? scheme.onSurface;
    final timeStyle = Theme.of(context).textTheme.labelLarge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              '${context.tr('Start')} ${_clock(widget.startMs)}',
              style: timeStyle,
            ),
            const Spacer(),
            Text(
              _clock(widget.endMs - widget.startMs),
              style: timeStyle?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              '${context.tr('End')} ${_clock(widget.endMs)}',
              style: timeStyle,
            ),
          ],
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Listener(
                    key: const Key('waveform'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) => _pointerDown(event, width),
                    onPointerMove: (event) => _pointerMove(event, width),
                    onPointerUp: (event) => _pointerUp(event, width),
                    onPointerCancel: (event) {
                      _pointers.remove(event.pointer);
                      _dragging = null;
                      _dragMs = null;
                      _pinchBase = null;
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _WaveformPainter(
                                columns: _columnsFor(width),
                                viewStartMs: _viewStart,
                                viewEndMs: _viewEnd,
                                startMs: widget.startMs,
                                endMs: widget.endMs,
                                wave: scheme.onSurface,
                                accent: accent,
                                ink: scheme.onSurface,
                                active: _dragging,
                                others: widget.others,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: ValueListenableBuilder<int?>(
                            valueListenable: widget.playhead ?? _noPlayhead,
                            builder: (context, playhead, _) => CustomPaint(
                              painter: _PlayheadPainter(
                                viewStartMs: _viewStart,
                                viewEndMs: _viewEnd,
                                cursorMs: _cursor,
                                playheadMs: playhead,
                                cursor: scheme.tertiary,
                                playhead: scheme.error,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.envelope == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(context.tr('Analyse the episode to see its waveform.')),
          ),
        Row(
          children: [
            Text(
              _clock(_viewStart),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const Spacer(),
            IconButton(
              tooltip: context.tr('Zoom out'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.zoom_out),
              onPressed: () => _zoom(2),
            ),
            IconButton(
              tooltip: context.tr('Zoom in'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.zoom_in),
              onPressed: () => _zoom(0.5),
            ),
            const Spacer(),
            Text(
              _clock(_viewEnd),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        Row(
          children: [
            Text(
              '${context.tr('Cursor')} ${_clock(_cursor)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.play_arrow),
              label: Text(context.tr('Play from cursor')),
              onPressed: () => widget.onListen(
                _cursor,
                math.min(_cursor + cursorPlayMs, widget.durationMs),
              ),
            ),
          ],
        ),
      ],
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
    this.onHere,
  });

  /// `start` ou `end`, pour les clés des boutons.
  final String id;
  final String label;
  final int valueMs;
  final ValueChanged<int> onStep;
  final VoidCallback onListen;

  /// Pose la borne à la position de lecture. Sans elle, pas de bouton.
  final VoidCallback? onHere;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(_clock(valueMs)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onHere != null)
            IconButton(
              key: Key('$id-here'),
              tooltip: context.tr('Set to the playback position'),
              icon: const Icon(Icons.my_location),
              onPressed: onHere,
            ),
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

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.columns,
    required this.viewStartMs,
    required this.viewEndMs,
    required this.startMs,
    required this.endMs,
    required this.wave,
    required this.accent,
    required this.ink,
    required this.active,
    required this.others,
  });

  final List<WaveColumn> columns;
  final int viewStartMs;
  final int viewEndMs;
  final int startMs;
  final int endMs;
  final Color wave;
  final Color accent;
  final Color ink;
  final _Handle? active;
  final List<WaveformSpan> others;

  double _x(int ms, Size size) {
    return _msToX(ms, viewStartMs, viewEndMs, size.width);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final span in others) {
      final spanLeft = _x(span.startMs, size);
      final spanRight = _x(span.endMs, size);
      if (spanRight <= 0 || spanLeft >= size.width) continue;
      final band = Rect.fromLTRB(
        spanLeft.clamp(0.0, size.width),
        0,
        spanRight.clamp(0.0, size.width),
        size.height,
      );
      canvas.drawRect(
        band,
        Paint()..color = span.color.withValues(alpha: 0.22),
      );
      canvas.drawRect(
        Rect.fromLTWH(band.left, 0, band.width, 3),
        Paint()..color = span.color,
      );
    }
    final left = _x(startMs, size).clamp(0.0, size.width);
    final right = _x(endMs, size).clamp(0.0, size.width);
    canvas.drawRect(
      Rect.fromLTRB(left, 0, math.max(left, right), size.height),
      Paint()..color = accent.withValues(alpha: 0.16),
    );
    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()..color = ink.withValues(alpha: 0.14),
    );
    if (columns.isNotEmpty) {
      final step = size.width / columns.length;
      for (var i = 0; i < columns.length; i++) {
        final x = i * step;
        final center = x + step * 0.4;
        final inside = center >= left && center <= right;
        final column = columns[i];
        final peak = Paint()
          ..color = wave.withValues(alpha: inside ? 0.38 : 0.16);
        final rms = Paint()
          ..color = (inside ? accent : wave).withValues(
            alpha: inside ? 0.95 : 0.34,
          );
        final p = column.peak * (mid - 8);
        final r = column.rms * (mid - 8);
        canvas.drawRect(
          Rect.fromLTRB(x, mid - p, x + step * 0.72, mid + p),
          peak,
        );
        canvas.drawRect(
          Rect.fromLTRB(x, mid - r, x + step * 0.72, mid + r),
          rms,
        );
      }
    }
    _handle(canvas, size, startMs, active == _Handle.start);
    _handle(canvas, size, endMs, active == _Handle.end);
  }

  void _handle(Canvas canvas, Size size, int ms, bool active) {
    final x = _x(ms, size);
    if (x < -16 || x > size.width + 16) return;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = accent
        ..strokeWidth = active ? 3 : 2,
    );
    final knob = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, size.height / 2),
        width: active ? 18 : 14,
        height: active ? 44 : 36,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(knob, Paint()..color = accent);
    canvas.drawRRect(
      knob,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ink.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) {
    return old.columns != columns ||
        old.viewStartMs != viewStartMs ||
        old.viewEndMs != viewEndMs ||
        old.startMs != startMs ||
        old.endMs != endMs ||
        old.accent != accent ||
        old.wave != wave ||
        old.ink != ink ||
        old.active != active ||
        !_sameWaveSpans(old.others, others);
  }
}

/// Curseur et tête de lecture, au-dessus de l’onde déjà peinte.
class _PlayheadPainter extends CustomPainter {
  const _PlayheadPainter({
    required this.viewStartMs,
    required this.viewEndMs,
    required this.cursorMs,
    required this.playheadMs,
    required this.cursor,
    required this.playhead,
  });

  final int viewStartMs;
  final int viewEndMs;
  final int cursorMs;
  final int? playheadMs;
  final Color cursor;
  final Color playhead;

  @override
  void paint(Canvas canvas, Size size) {
    _paintMarker(
      canvas,
      size,
      _msToX(cursorMs, viewStartMs, viewEndMs, size.width),
      cursor,
      1.5,
      triangle: true,
    );
    final play = playheadMs;
    if (play == null) return;
    _paintMarker(
      canvas,
      size,
      _msToX(play, viewStartMs, viewEndMs, size.width),
      playhead,
      2,
    );
  }

  @override
  bool shouldRepaint(_PlayheadPainter old) {
    return old.viewStartMs != viewStartMs ||
        old.viewEndMs != viewEndMs ||
        old.cursorMs != cursorMs ||
        old.playheadMs != playheadMs ||
        old.cursor != cursor ||
        old.playhead != playhead;
  }
}

double _msToX(int ms, int viewStartMs, int viewEndMs, double width) {
  final span = viewEndMs - viewStartMs;
  if (span <= 0) return 0;
  return (ms - viewStartMs) / span * width;
}

void _paintMarker(
  Canvas canvas,
  Size size,
  double x,
  Color color,
  double width, {
  bool triangle = false,
}) {
  if (x < 0 || x > size.width) return;
  canvas.drawLine(
    Offset(x, 0),
    Offset(x, size.height),
    Paint()
      ..color = color
      ..strokeWidth = width,
  );
  if (!triangle) return;
  final head = Path()
    ..moveTo(x - 6, 0)
    ..lineTo(x + 6, 0)
    ..lineTo(x, 9)
    ..close();
  canvas.drawPath(head, Paint()..color = color);
}

bool _sameWaveSpans(List<WaveformSpan> a, List<WaveformSpan> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].startMs != b[i].startMs ||
        a[i].endMs != b[i].endMs ||
        a[i].color != b[i].color) {
      return false;
    }
  }
  return true;
}
