import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/olaf_index_bench.dart';

/// Run with `OLAF_INDEX_BENCH=1 flutter test test/olaf_index_bench_test.dart`.
void main() {
  test(
    'Olaf index: old, cached and packed timings',
    () {
      // ignore: avoid_print
      print(runOlafIndexBench());
    },
    skip: Platform.environment['OLAF_INDEX_BENCH'] != '1',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
