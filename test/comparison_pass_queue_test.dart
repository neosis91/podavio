import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/comparison_pass_queue.dart';

void main() {
  test('deux passages ne tournent pas en même temps', () async {
    final queue = ComparisonPassQueue();
    var depth = 0;
    var maxDepth = 0;
    Future<void> body() async {
      depth += 1;
      if (depth > maxDepth) maxDepth = depth;
      await Future<void>.delayed(Duration.zero);
      depth -= 1;
    }

    await Future.wait([
      queue.run(body),
      queue.run(body),
      queue.spread(1, (_) => body()),
      queue.spread(1, (_) => body()),
    ]);
    expect(maxDepth, 1);
  });

  test('les recherches simultanées ne font qu’une reprise', () async {
    final queue = ComparisonPassQueue();
    final seen = <int?>[];
    final hold = Completer<void>();
    Future<void> body(int? except) async {
      seen.add(except);
      if (seen.length == 1) await hold.future;
    }

    final first = queue.spread(4, body);
    await Future<void>.delayed(Duration.zero);
    final same = queue.spread(4, body);
    final other = queue.spread(9, body);
    expect(seen, [4]);
    hold.complete();
    await Future.wait([first, same, other]);
    expect(seen, [4, null]);
  });

  test('le même podcast sauté reste sauté dans la reprise', () async {
    final queue = ComparisonPassQueue();
    final seen = <int?>[];
    final hold = Completer<void>();
    Future<void> body(int? except) async {
      seen.add(except);
      if (seen.length == 1) await hold.future;
    }

    final first = queue.spread(4, body);
    await Future<void>.delayed(Duration.zero);
    final second = queue.spread(4, body);
    final third = queue.spread(4, body);
    hold.complete();
    await Future.wait([first, second, third]);
    expect(seen, [4, 4]);
  });

  test('une recherche déjà finie n’avale pas la suivante', () async {
    final queue = ComparisonPassQueue();
    final seen = <int?>[];
    Future<void> body(int? except) async {
      seen.add(except);
    }

    await queue.spread(4, body);
    await queue.spread(4, body);
    expect(seen, [4, 4]);
  });

  test('un autre passage attend la reprise fusionnée', () async {
    final queue = ComparisonPassQueue();
    final order = <String>[];
    final hold = Completer<void>();
    Future<void> body(int? except) async {
      order.add('spread $except');
      if (order.length == 1) await hold.future;
    }

    final first = queue.spread(1, body);
    await Future<void>.delayed(Duration.zero);
    final again = queue.spread(1, body);
    final other = queue.run(() async {
      order.add('run');
    });
    hold.complete();
    await Future.wait([first, again, other]);
    expect(order, ['spread 1', 'spread 1', 'run']);
  });

  test('plusieurs recherches derrière un passage n’en font qu’une', () async {
    final queue = ComparisonPassQueue();
    final order = <String>[];
    final hold = Completer<void>();
    final blocking = queue.run(() async {
      order.add('run');
      await hold.future;
    });
    await Future<void>.delayed(Duration.zero);
    Future<void> body(int? except) async {
      order.add('spread $except');
    }

    final left = queue.spread(2, body);
    final right = queue.spread(3, body);
    hold.complete();
    await Future.wait([blocking, left, right]);
    expect(order, ['run', 'spread null']);
  });
}
