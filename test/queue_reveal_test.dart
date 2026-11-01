import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/ui/player/player_sheets.dart';

void main() {
  const previousCount = 20;
  const rowHeight = 60.0;
  final target = queueRevealTarget(
    previousCount: previousCount,
    rowHeight: rowHeight,
  );
  const viewport = 640.0;
  const maxExtent = 796.0;

  test('up-next too short lets a scroll toward previous episodes stay', () {
    expect(target, 36 + previousCount * rowHeight);
    expect(target, greaterThan(maxExtent));

    var state = const QueueRevealState();
    final measuring = advanceQueueReveal(
      state: state,
      maxExtent: maxExtent,
      target: target,
      viewport: viewport,
      previousCount: previousCount,
    );
    expect(measuring.reschedule, isTrue);
    expect(measuring.jumpTo, maxExtent);
    state = measuring.state;

    // Le doigt remonte vers « Précédents » avant l’image suivante.
    state = QueueRevealState(
      revealed: state.revealed,
      extent: state.extent,
      offset: 40,
    );
    final settled = advanceQueueReveal(
      state: state,
      maxExtent: maxExtent,
      target: target,
      viewport: viewport,
      previousCount: previousCount,
    );
    expect(settled.jumpTo, isNull);
    expect(settled.reschedule, isFalse);
    expect(settled.state.revealed, isTrue);
    expect(settled.state.offset, 40);

    final later = advanceQueueReveal(
      state: settled.state,
      maxExtent: maxExtent,
      target: target,
      viewport: viewport,
      previousCount: previousCount,
    );
    expect(later.jumpTo, isNull);
    expect(later.state.offset, 40);
  });

  test('the scroll may follow the extent only while it is still growing', () {
    var state = const QueueRevealState();
    for (final extent in [120.0, 480.0, maxExtent]) {
      final update = advanceQueueReveal(
        state: state,
        maxExtent: extent,
        target: target,
        viewport: viewport,
        previousCount: previousCount,
      );
      expect(update.jumpTo, extent);
      expect(update.reschedule, isTrue);
      expect(update.state.revealed, isFalse);
      state = update.state;
    }

    final settled = advanceQueueReveal(
      state: state,
      maxExtent: maxExtent,
      target: target,
      viewport: viewport,
      previousCount: previousCount,
    );
    expect(settled.jumpTo, isNull);
    expect(settled.state.revealed, isTrue);
  });

  test('a sub-pixel extent change does not restart the jump', () {
    final update = advanceQueueReveal(
      state: const QueueRevealState(extent: maxExtent, offset: 40),
      maxExtent: maxExtent + 0.4,
      target: target,
      viewport: viewport,
      previousCount: previousCount,
    );
    expect(update.jumpTo, isNull);
    expect(update.state.offset, 40);
    expect(update.state.revealed, isTrue);
  });

  test('enough episodes below pin the current one at the top', () {
    const roomy = 2400.0;
    const pinned = 600.0;
    final update = advanceQueueReveal(
      state: const QueueRevealState(),
      maxExtent: roomy,
      target: pinned,
      viewport: viewport,
      previousCount: 10,
    );
    expect(update.jumpTo, pinned);
    expect(update.reschedule, isFalse);
    expect(update.state.revealed, isTrue);
    expect(update.state.offset, pinned);
  });

  test('previous episodes that already fit are not scrolled', () {
    final update = advanceQueueReveal(
      state: const QueueRevealState(offset: 12),
      maxExtent: 2000,
      target: 100,
      viewport: viewport,
      previousCount: 1,
    );
    expect(update.jumpTo, isNull);
    expect(update.state.offset, 12);
    expect(update.state.revealed, isTrue);
  });

  test('an empty previous section does not move the scroll', () {
    final update = advanceQueueReveal(
      state: const QueueRevealState(offset: 8),
      maxExtent: 500,
      target: 0,
      viewport: viewport,
      previousCount: 0,
    );
    expect(update.jumpTo, isNull);
    expect(update.state.offset, 8);
    expect(update.state.revealed, isTrue);
  });
}
