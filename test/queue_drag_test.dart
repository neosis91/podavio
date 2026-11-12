import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/ui/player/queue_sheet_drag.dart';

void main() {
  test('a drag that started in the list never closes the sheet', () {
    final decision = decideQueueDrag(
      locksScroll: true,
      movedSheet: false,
      atTop: true,
      sheetFullyOpen: true,
      delta: 40,
    );
    expect(decision.target, QueueDragTarget.list);
    expect(decision.movedSheet, isFalse);
    expect(decision.handOff, isFalse);
  });

  test('reaching the top mid-drag keeps the gesture on the list', () {
    final decision = decideQueueDrag(
      locksScroll: false,
      movedSheet: false,
      atTop: false,
      sheetFullyOpen: true,
      delta: 24,
    );
    expect(decision.target, QueueDragTarget.list);
    expect(decision.locksScroll, isTrue);
  });

  test('a downward drag from the top closes the sheet', () {
    final decision = decideQueueDrag(
      locksScroll: false,
      movedSheet: false,
      atTop: true,
      sheetFullyOpen: true,
      delta: 12,
    );
    expect(decision.target, QueueDragTarget.sheet);
    expect(decision.started, isTrue);
    expect(decision.locksScroll, isFalse);
  });

  test('an upward drag from the top scrolls the list', () {
    final decision = decideQueueDrag(
      locksScroll: false,
      movedSheet: false,
      atTop: true,
      sheetFullyOpen: true,
      delta: -12,
    );
    expect(decision.target, QueueDragTarget.list);
    expect(decision.started, isFalse);
  });

  test('reversing a close brings the sheet back before the list scrolls', () {
    final restoring = decideQueueDrag(
      locksScroll: false,
      movedSheet: true,
      atTop: true,
      sheetFullyOpen: false,
      delta: -8,
    );
    expect(restoring.target, QueueDragTarget.sheet);
    expect(restoring.handOff, isFalse);

    final handed = decideQueueDrag(
      locksScroll: false,
      movedSheet: true,
      atTop: true,
      sheetFullyOpen: true,
      delta: -8,
    );
    expect(handed.target, QueueDragTarget.list);
    expect(handed.handOff, isTrue);
    expect(handed.movedSheet, isFalse);
  });

  testWidgets('scrolling the queue does not drag the sheet', (tester) async {
    final events = <String>[];
    final controller = QueueSheetScrollController(
      sheetFullyOpen: () => true,
      onSheetStart: (_) => events.add('start'),
      onSheetDelta: (_) => events.add('delta'),
      onSheetEnd: (_) => events.add('end'),
      onSheetCancel: () => events.add('cancel'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_queue(controller));
    controller.jumpTo(240);
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pump();

    expect(events, isEmpty);
    expect(controller.offset, 0);
  });

  testWidgets('dragging down at the top moves the sheet and not the list', (
    tester,
  ) async {
    final deltas = <double>[];
    var open = true;
    final controller = QueueSheetScrollController(
      sheetFullyOpen: () => open,
      onSheetStart: (_) => open = false,
      onSheetDelta: deltas.add,
      onSheetEnd: (_) {},
      onSheetCancel: () {},
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_queue(controller));

    await tester.drag(find.byType(ListView), const Offset(0, 120));
    await tester.pump();

    expect(deltas, isNotEmpty);
    expect(deltas.every((delta) => delta > 0), isTrue);
    expect(controller.offset, 0);
  });

  testWidgets('dragging up at the top scrolls the list', (tester) async {
    final events = <String>[];
    final controller = QueueSheetScrollController(
      sheetFullyOpen: () => true,
      onSheetStart: (_) => events.add('start'),
      onSheetDelta: (_) => events.add('delta'),
      onSheetEnd: (_) => events.add('end'),
      onSheetCancel: () => events.add('cancel'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_queue(controller));

    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pump();

    expect(events, isEmpty);
    expect(controller.offset, greaterThan(0));
  });
}

Widget _queue(QueueSheetScrollController controller) {
  return MaterialApp(
    home: ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      itemCount: 40,
      itemBuilder: (context, index) =>
          SizedBox(height: 48, child: Text('$index')),
    ),
  );
}
