import 'package:podavio/data/olaf_ads.dart';

import 'olaf_legacy.dart';
import 'olaf_synthetic.dart';

/// Times template location (every template x episode) and pair alignment
/// (every pair, both directions folded into i < j) on synthetic landmarks.
///
/// - old: the Map index and counts rebuilt for every call, as before.
/// - cached: the same Maps, built once per episode.
/// - packed: [OlafAdIndexed], built once per episode, as planOlafAds does.
///
/// Each variant runs [runs] times after one warm-up; the median is kept.
/// Returns a report and fails if a variant disagrees with the old one.
String runOlafIndexBench({
  int episodes = 12,
  int minutes = 60,
  int templates = 20,
  int runs = 5,
}) {
  final data = SyntheticOlaf(
    seed: 7,
    episodes: episodes,
    durationMs: minutes * 60000,
    ads: 8,
    templates: templates,
  );

  String old() {
    final tables = data.episodePrints.map(LegacyTable.parse).toList();
    final out = StringBuffer();
    for (var t = 0; t < data.templatePrints.length; t++) {
      final needle = LegacyTable.parse(data.templatePrints[t]);
      for (final hay in tables) {
        out.write(
          legacyLocate(needle, hay, durationMs: data.templateDurationMs[t]),
        );
      }
    }
    for (var i = 0; i < tables.length; i++) {
      for (var j = i + 1; j < tables.length; j++) {
        out.write(legacyAlign(tables[i], tables[j]));
      }
    }
    return out.toString();
  }

  String cached() {
    final tables = data.episodePrints.map(LegacyTable.parse).toList();
    final counts = tables.map(legacyCounts).toList();
    final indexes = tables.map(LegacyIndex.of).toList();
    final out = StringBuffer();
    for (var t = 0; t < data.templatePrints.length; t++) {
      final needle = LegacyTable.parse(data.templatePrints[t]);
      for (final index in indexes) {
        out.write(
          legacyLocateIn(needle, index, durationMs: data.templateDurationMs[t]),
        );
      }
    }
    for (var i = 0; i < tables.length; i++) {
      for (var j = i + 1; j < tables.length; j++) {
        out.write(legacyAlignIn(tables[i], counts[i], indexes[j]));
      }
    }
    return out.toString();
  }

  String packed() {
    final parsed = [
      for (final bytes in data.episodePrints) OlafAdIndexed.parse(bytes)!,
    ];
    final out = StringBuffer();
    for (var t = 0; t < data.templatePrints.length; t++) {
      for (final hay in parsed) {
        out.write(
          hay.locate(
            data.templatePrints[t],
            durationMs: data.templateDurationMs[t],
          ),
        );
      }
    }
    for (var i = 0; i < parsed.length; i++) {
      for (var j = i + 1; j < parsed.length; j++) {
        out.write(parsed[i].alignWith(parsed[j]));
      }
    }
    return out.toString();
  }

  final variants = {'old': old, 'cached': cached, 'packed': packed};
  final reference = old();
  final report = StringBuffer()
    ..writeln(
      'Olaf index bench: $episodes episodes x $minutes min, '
      '${data.landmarks} landmarks, $templates templates, '
      '${episodes * (episodes - 1) ~/ 2} pairs, median of $runs runs',
    );
  int? baseline;
  for (final entry in variants.entries) {
    if (entry.value() != reference) {
      throw StateError('${entry.key} disagrees with old');
    }
    final times = <int>[];
    for (var r = 0; r < runs; r++) {
      final watch = Stopwatch()..start();
      entry.value();
      times.add(watch.elapsedMicroseconds);
    }
    times.sort();
    final median = times[times.length ~/ 2];
    baseline ??= median;
    report.writeln(
      '${entry.key.padRight(7)} ${(median / 1000).toStringAsFixed(1)} ms'
      '  x${(baseline / median).toStringAsFixed(2)}',
    );
  }
  final one = OlafAdIndexed.parse(data.episodePrints.first)!;
  report.writeln(
    'packed index of one episode: ${one.index.sizeInBytes} bytes '
    'for ${(data.episodePrints.first.length - 4) ~/ 12} landmarks',
  );
  return report.toString();
}
