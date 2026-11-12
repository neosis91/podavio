import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Où va le déplacement du doigt.
enum QueueDragTarget { list, sheet }

/// Répartition d’un déplacement entre la liste et la fermeture de la file.
class QueueDragDecision {
  const QueueDragDecision({
    required this.target,
    required this.locksScroll,
    required this.movedSheet,
    required this.handOff,
    required this.started,
  });

  final QueueDragTarget target;

  /// Le geste ne ferme plus la file, même s’il atteint le haut.
  final bool locksScroll;

  /// La file suit le doigt.
  final bool movedSheet;

  /// La file est revenue en place : la suite du geste défile la liste.
  final bool handOff;

  /// Premier déplacement qui entraîne la file.
  final bool started;
}

/// Un geste commencé dans la liste ne fait que défiler.
/// Un geste commencé en haut, vers le bas, ferme la file.
/// Revenir vers le haut ramène d’abord la file, puis défile la liste.
QueueDragDecision decideQueueDrag({
  required bool locksScroll,
  required bool movedSheet,
  required bool atTop,
  required bool sheetFullyOpen,
  required double delta,
}) {
  if (locksScroll || !atTop) {
    return QueueDragDecision(
      target: QueueDragTarget.list,
      locksScroll: true,
      movedSheet: movedSheet,
      handOff: false,
      started: false,
    );
  }
  if (movedSheet && sheetFullyOpen && delta < 0) {
    return const QueueDragDecision(
      target: QueueDragTarget.list,
      locksScroll: false,
      movedSheet: false,
      handOff: true,
      started: false,
    );
  }
  if (movedSheet || (sheetFullyOpen && delta > 0)) {
    return QueueDragDecision(
      target: QueueDragTarget.sheet,
      locksScroll: false,
      movedSheet: true,
      handOff: false,
      started: !movedSheet,
    );
  }
  return const QueueDragDecision(
    target: QueueDragTarget.list,
    locksScroll: false,
    movedSheet: false,
    handOff: false,
    started: false,
  );
}

/// Liste de la file : le doigt ferme le panneau ou défile, jamais les deux.
class QueueSheetScrollController extends ScrollController {
  QueueSheetScrollController({
    required this.sheetFullyOpen,
    required this.onSheetStart,
    required this.onSheetDelta,
    required this.onSheetEnd,
    required this.onSheetCancel,
  });

  final bool Function() sheetFullyOpen;
  final GestureDragStartCallback onSheetStart;
  final void Function(double delta) onSheetDelta;
  final GestureDragEndCallback onSheetEnd;
  final GestureDragCancelCallback onSheetCancel;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return QueueSheetScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      sheet: this,
    );
  }
}

class QueueSheetScrollPosition extends ScrollPositionWithSingleContext {
  QueueSheetScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.sheet,
  });

  final QueueSheetScrollController sheet;
  var _locksScroll = false;
  var _movedSheet = false;
  var _suppressBallistic = false;

  bool get _atTop => pixels <= minScrollExtent + 0.5;

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    _locksScroll = pixels > minScrollExtent + 0.5;
    _movedSheet = false;
    _suppressBallistic = false;
    return _QueueSheetDrag(super.drag(details, dragCancelCallback), this);
  }

  @override
  void applyUserOffset(double delta) {
    final decision = decideQueueDrag(
      locksScroll: _locksScroll,
      movedSheet: _movedSheet,
      atTop: _atTop,
      sheetFullyOpen: sheet.sheetFullyOpen(),
      delta: delta,
    );
    if (decision.handOff) {
      _movedSheet = false;
      sheet.onSheetEnd(
        DragEndDetails(primaryVelocity: 0, velocity: Velocity.zero),
      );
    }
    _locksScroll = decision.locksScroll;
    _movedSheet = decision.movedSheet;
    if (decision.target == QueueDragTarget.sheet) {
      if (decision.started) {
        sheet.onSheetStart(DragStartDetails(globalPosition: Offset.zero));
      }
      sheet.onSheetDelta(delta);
      return;
    }
    super.applyUserOffset(delta);
    if (pixels > minScrollExtent + 0.5) _locksScroll = true;
  }

  @override
  void goBallistic(double velocity) {
    if (_suppressBallistic) {
      _suppressBallistic = false;
      super.goBallistic(0);
      return;
    }
    super.goBallistic(velocity);
  }

  void _endSheet(DragEndDetails details) {
    if (!_movedSheet) return;
    _movedSheet = false;
    _suppressBallistic = true;
    sheet.onSheetEnd(details);
  }

  void _cancelSheet() {
    if (!_movedSheet) return;
    _movedSheet = false;
    _suppressBallistic = true;
    sheet.onSheetCancel();
  }
}

class _QueueSheetDrag implements Drag {
  _QueueSheetDrag(this._inner, this._position);

  final Drag _inner;
  final QueueSheetScrollPosition _position;

  @override
  void update(DragUpdateDetails details) => _inner.update(details);

  @override
  void end(DragEndDetails details) {
    _position._endSheet(details);
    _inner.end(details);
  }

  @override
  void cancel() {
    _position._cancelSheet();
    _inner.cancel();
  }
}
