// Olaf index microbenchmark, outside `flutter test`.
//
// Host, AOT:  dart compile exe tool/olaf_index_bench.dart -o /tmp/bench
//             && /tmp/bench
// Device:     flutter run --release -d <device> -t tool/olaf_index_bench.dart
//             (the report is printed to the flutter console and logcat).
import '../test/support/olaf_index_bench.dart';

void main() {
  // ignore: avoid_print
  print(runOlafIndexBench());
}
