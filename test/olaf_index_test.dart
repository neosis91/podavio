import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:olaf_ffi/olaf_ffi.dart';
import 'package:podavio/data/segment_finder.dart';
import 'package:podavio/data/olaf_ads.dart';
import 'package:podavio/data/olaf_index.dart';
import 'package:podavio/data/olaf_sting.dart';
import 'package:podavio/data/skip_segments.dart';

import 'support/olaf_legacy.dart';
import 'support/olaf_synthetic.dart';

const _seeds = [1, 2, 3];

void main() {
  test('packed index holds the same times and counts as the old maps', () {
    for (final seed in _seeds) {
      final data = SyntheticOlaf(seed: seed);
      for (final bytes in data.episodePrints) {
        final table = LegacyTable.parse(bytes);
        final legacy = LegacyIndex.of(table);
        final packed = OlafAdIndexed.parse(bytes)!.index;
        for (var i = 0; i < table.count; i++) {
          final hash = table.hashAt(i);
          final id = packed.find(hash);
          expect(id, packed.idOfLandmark(i));
          expect(packed.countOf(id), legacy.counts[hash]);
          expect(
            packed.times.sublist(packed.start(id), packed.end(id)),
            legacy.index[hash] ?? const <int>[],
          );
        }
        expect(packed.find(1 << 40), -1);
      }
    }
  });

  test('a hash with the top bit set is found', () {
    final hashes = [-1, 1 << 63, 42, -1];
    final index = OlafHashIndex.build(
      hashes.length,
      hashAt: (i) => hashes[i],
      timeAt: (i) => i * 10,
      maxHits: 8,
    );
    final id = index.find(-1);
    expect(index.countOf(id), 2);
    expect(index.times.sublist(index.start(id), index.end(id)), [0, 30]);
    expect(index.countOf(index.find(1 << 63)), 1);
    expect(index.find(7), -1);
  });

  test('template location: old, cached and packed agree', () {
    var found = 0;
    for (final seed in _seeds) {
      final data = SyntheticOlaf(seed: seed);
      for (final hay in data.episodePrints) {
        final legacyHay = LegacyTable.parse(hay);
        final cached = LegacyIndex.of(legacyHay);
        final packed = OlafAdIndexed.parse(hay)!;
        for (var t = 0; t < data.templatePrints.length; t++) {
          final needle = data.templatePrints[t];
          final duration = data.templateDurationMs[t];
          final old = legacyLocate(
            LegacyTable.parse(needle),
            legacyHay,
            durationMs: duration,
          );
          final reused = legacyLocateIn(
            LegacyTable.parse(needle),
            cached,
            durationMs: duration,
          );
          final now = packed.locate(needle, durationMs: duration);
          expect(reused, old);
          expect(now, old);
          if (now != null) found++;
        }
      }
    }
    expect(found, greaterThan(10));
  });

  test('pair alignment: old, cached and packed agree', () {
    var edges = 0;
    for (final seed in _seeds) {
      final data = SyntheticOlaf(seed: seed);
      final tables = data.episodePrints.map(LegacyTable.parse).toList();
      final counts = tables.map(legacyCounts).toList();
      final cached = tables.map(LegacyIndex.of).toList();
      final packed = data.episodePrints.map(OlafAdIndexed.parse).toList();
      for (var i = 0; i < tables.length; i++) {
        for (var j = 0; j < tables.length; j++) {
          if (i == j) continue;
          final old = legacyAlign(tables[i], tables[j]);
          expect(legacyAlignIn(tables[i], counts[i], cached[j]), old);
          expect(packed[i]!.alignWith(packed[j]!), old);
          edges += old.length;
        }
      }
    }
    expect(edges, greaterThan(10));
  });

  test('sting alignment: old and packed agree', () {
    var edges = 0;
    for (final seed in _seeds) {
      final episodes = _stingEpisodes(seed);
      for (var i = 0; i < episodes.length; i++) {
        for (var j = 0; j < episodes.length; j++) {
          if (i == j) continue;
          final old = legacyStingAlign(episodes[i], episodes[j]);
          expect(olafStingEdges(episodes[i], episodes[j]), old);
          edges += old.length;
        }
      }
    }
    expect(edges, greaterThan(10));
  });

  test('whole plans are unchanged on synthetic episodes', () {
    final digests = [
      for (final seed in _seeds) ...[
        _planDigest(SyntheticOlaf(seed: seed)),
        _planDigest(SyntheticOlaf(seed: seed), templates: false),
      ],
    ];
    expect(digests, _expectedPlans);
  });

  test('stings found are unchanged on synthetic openings', () {
    final digests = [
      for (final seed in _seeds) _stingDigest(_stingEpisodes(seed)),
    ];
    expect(digests, _expectedStings);
  });
}

/// Digests computed with the Map-based code before the packed index.
const _expectedPlans = <String>[
  '100 ad 33016 1720 [2:371456-404472x4,3:601600-634616x4,4:872960-905976x4,5:124000-157016x4]'
      ' | '
      '101 ad 11112 604 [1:868864-879976x5,2:918272-929384x5,4:986144-997256x5,5:266240-277352x5,6:802976-814088x5]'
      ' | '
      '102 ad 13720 664 [1:14432-28152x4,4:726496-740216x4,5:684000-697720x4,6:1117600-1131320x4]',
  '- ad 16016 1504 [1:863992-880000x2,2:913376-929392x2]'
      ' | '
      '- ad 42960 5512 [1:551600-585536x5,2:361520-404480x5,3:591808-634648x5,4:863168-905992x5,5:114200-157008x5]'
      ' | '
      '- ad 14408 1384 [4:725936-740224x3,5:683336-697744x3,6:1116936-1131320x3]'
      ' | '
      '- ad 16008 1648 [4:981248-997256x3,5:261368-277352x3,6:798104-814112x3]',
  '100 ad 31696 1564 [1:1111584-1143280x6,2:583456-615152x6,3:728160-759856x6,4:320960-352656x6,5:951616-983312x6,6:874816-906512x6]'
      ' | '
      '101 ad 32016 1588 [1:640800-672816x4,2:990976-1022992x4,5:575136-607152x4,6:818976-850992x4]'
      ' | '
      '102 ad 11160 580 [1:786976-798136x5,2:160384-171544x5,3:11072-22232x5,4:721920-733080x5,6:521120-532280x5]',
  '- ad 38728 3484 [1:111576-150296x4,2:910584-949288x4,3:633560-672288x4,4:847584-886248x4]'
      ' | '
      '- ad 33632 2980 [1:639208-672840x2,2:989392-1023000x2]'
      ' | '
      '- ad 34880 3292 [1:1109016-1143288x6,2:580304-615184x6,3:724992-759864x6,4:317800-352664x6,5:948464-983336x6,6:871656-906536x6]'
      ' | '
      '- ad 16504 1672 [1:781624-798128x4,2:155072-171576x4,3:5736-22232x4,4:716568-733072x4]'
      ' | '
      '- ad 33624 2956 [5:573536-607160x2,6:817400-851016x2]',
  '100 ad 32152 1588 [1:1010272-1042424x5,2:667680-699832x5,3:965696-997848x5,4:886848-919000x5,5:1078144-1110296x5]'
      ' | '
      '101 ad 25832 1264 [2:242176-268008x5,3:657760-683592x5,4:941888-967720x5,5:272064-297896x5,6:138560-164392x5]'
      ' | '
      '102 ad 36752 1768 [3:104256-141008x3,4:504224-540976x3,6:634848-671600x3]',
  '- ad 16200 1492 [1:700696-716480x4,2:948664-964456x4,3:371640-387840x4,4:65464-81656x4]'
      ' | '
      '- ad 47064 4300 [1:995368-1042424x5,2:652792-699856x5,3:950792-997856x5,4:872048-919008x5,5:1063368-1110312x5]'
      ' | '
      '- ad 29520 2728 [2:238520-268040x5,3:654104-683608x5,4:938232-967744x5,5:268424-297912x5,6:134896-164400x5]'
      ' | '
      '- ad 37024 3460 [3:104000-141008x2,4:503984-541008x2]',
];

const _expectedStings = <String>[
  '1:85944-88848x33,2:81848-84752x33,3:100000-102904x28,4:98368-101288x30,5:162416-165336x33',
  '1:8472-11168x31,3:23856-26552x29,4:164856-167512x32,5:125872-128584x33,2:8496-11192x33',
  '1:154560-157536x31,2:67968-70952x36,3:33192-36160x32,4:125784-128752x36,5:114336-117120x30',
];

String _planDigest(SyntheticOlaf data, {bool templates = true}) {
  final plan = planOlafAds(
    episodes: [
      for (var i = 0; i < data.episodePrints.length; i++)
        OlafAdEpisode(
          episodeId: i + 1,
          prints: data.episodePrints[i],
          durationMs: 20 * 60000,
        ),
    ],
    templates: [
      for (var t = 0; templates && t < data.templatePrints.length ~/ 2; t++)
        OlafAdTemplate(
          id: 100 + t,
          kind: SkipSegmentKind.ad,
          confirmed: true,
          durationMs: data.templateDurationMs[t],
          prints: data.templatePrints[t],
          confidence: null,
        ),
    ],
    contextLayer: false,
  );
  return [for (final pattern in plan.patterns) _pattern(pattern)].join(' | ');
}

String _pattern(PlannedPattern pattern) {
  final segments = [
    for (final s in pattern.segments)
      '${s.episodeId}:${s.startMs}-${s.endMs}x${s.matches}',
  ].join(',');
  return '${pattern.templateId ?? '-'} ${pattern.kind.name} '
      '${pattern.durationMs} ${pattern.fingerprintBytes?.length} [$segments]';
}

String _stingDigest(List<OlafEpisodePrints> episodes) => [
  for (final hit in findOlafContentSting(episodes))
    '${hit.episodeId}:${hit.startMs}-${hit.endMs}x${hit.votes}',
].join(',');

List<OlafEpisodePrints> _stingEpisodes(int seed) {
  final random = math.Random(seed);
  const frames = 180000 ~/ olafStepMs;
  final sting = [
    for (var i = 0; i < 40; i++)
      OlafLandmark(hash: random.nextInt(1 << 30), t1: random.nextInt(375)),
  ];
  final card = [
    for (var i = 0; i < 30; i++)
      OlafLandmark(hash: random.nextInt(1 << 30), t1: random.nextInt(300)),
  ];
  return [
    for (var e = 0; e < 5; e++)
      () {
        final offset = 1000 + random.nextInt(frames - 2000);
        final marks = <OlafLandmark>[
          for (var i = 0; i < 700; i++)
            OlafLandmark(
              hash: random.nextInt(1 << 14),
              t1: random.nextInt(frames),
            ),
          ...card,
          for (final mark in sting)
            if (random.nextInt(8) != 0)
              OlafLandmark(
                hash: mark.hash,
                t1: offset + mark.t1 + random.nextInt(3) - 1,
              ),
        ]..sort((a, b) => a.t1.compareTo(b.t1));
        return OlafEpisodePrints(episodeId: e + 1, prints: marks);
      }(),
  ];
}
