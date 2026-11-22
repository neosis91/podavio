import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:olaf_ffi/olaf_ffi.dart';
import 'package:podavio/data/envelope.dart';
import 'package:podavio/data/log_mel.dart';
import 'package:podavio/data/log_mel_match.dart';
import 'package:podavio/data/olaf_sting.dart';
import 'package:podavio/data/segment_match.dart';

/// Compares Olaf with the log-mel sting finder on the nine RTL openings.
///
/// Point [rtlPcmDir] at 11025 Hz mono s16le files. CI does not download them.
void main() {
  final dir = Platform.environment['RTL_PCM_DIR'];
  test(
    'Olaf against the log-mel sting on the RTL openings',
    () async {
      expect(await ensureOlafLibrary(), isTrue);
      const names = [
        'palatine',
        'tigre',
        'archimede',
        'ruggieri',
        'cesar',
        'salem',
        'dreyfus',
        'lesseps',
        'gaulle',
      ];
      final episodes = <_Opening>[];
      final rssBefore = ProcessInfo.currentRss;
      final extractWatch = Stopwatch()..start();
      for (var i = 0; i < names.length; i++) {
        final path = '$dir/${names[i]}.pcm';
        final prints = fingerprintPcmFile(
          path,
          sampleRate: 11025,
          maxMs: logMelSearchWindowMs,
        );
        expect(prints, isNotNull);
        final bytes = File(path).readAsBytesSync();
        final samples = Int16List.view(Uint8List.fromList(bytes).buffer);
        final envelope = EnergyEnvelopeBuilder()..add(samples);
        episodes.add(
          _Opening(
            id: i + 1,
            name: names[i],
            samples: samples,
            envelope: envelope.finish(),
            prints: prints!,
          ),
        );
      }
      extractWatch.stop();
      final rssAfterOlaf = ProcessInfo.currentRss;

      final melWatch = Stopwatch()..start();
      final mels = <EpisodeMel>[];
      for (final episode in episodes) {
        mels.add(
          EpisodeMel(
            episodeId: episode.id,
            podcastId: 1,
            clip: computeLogMel(
              resampleToLogMelRate(
                episode.samples,
                11025,
                maxMs: logMelSearchWindowMs,
              ),
            ),
            durationMs: logMelSearchWindowMs,
          ),
        );
      }
      final searchWatch = Stopwatch()..start();
      final raw = findContentStings(episodes: mels);
      searchWatch.stop();
      final matchWatch = Stopwatch()..start();
      final rough = findOlafContentSting([
        for (final episode in episodes)
          OlafEpisodePrints(episodeId: episode.id, prints: episode.prints),
      ]);
      matchWatch.stop();
      final focusWatch = Stopwatch()..start();
      final focused = findContentStings(
        episodes: mels,
        focus: [
          for (final hit in rough)
            (episodeId: hit.episodeId, startMs: hit.startMs, endMs: hit.endMs),
        ],
      );
      focusWatch.stop();
      melWatch.stop();
      final byId = {for (final episode in episodes) episode.id: episode};
      final logMel = [
        for (final hit in raw)
          _placed(byId[hit.episodeId]!, hit.startMs, hit.endMs),
      ];
      final chapter = [
        for (final hit in focused)
          _placed(byId[hit.episodeId]!, hit.startMs, hit.endMs),
      ];

      final printBytes = episodes.fold<int>(
        0,
        (sum, episode) => sum + episode.prints.length * 12,
      );
      final melBytes = mels.fold<int>(
        0,
        (sum, episode) => sum + episode.clip.frames.length * 40 * 8,
      );
      final olafMs =
          extractWatch.elapsedMilliseconds +
          matchWatch.elapsedMilliseconds +
          focusWatch.elapsedMilliseconds;
      // ignore: avoid_print
      print(
        'olaf $olafMs ms (extract ${extractWatch.elapsedMilliseconds}, '
        'match ${matchWatch.elapsedMilliseconds}), prints $printBytes bytes, '
        'rss ${rssAfterOlaf - rssBefore}',
      );
      // ignore: avoid_print
      print(
        'log-mel ${melWatch.elapsedMilliseconds} ms '
        '(search ${searchWatch.elapsedMilliseconds}, '
        'focus ${focusWatch.elapsedMilliseconds}), frames $melBytes bytes',
      );
      for (final episode in episodes) {
        final chapterHit = chapter.where((hit) => hit.episodeId == episode.id);
        final melHit = logMel.where((hit) => hit.episodeId == episode.id);
        // ignore: avoid_print
        print(
          '${episode.name} '
          'chapter ${chapterHit.map((hit) => _clocked(hit.startMs, hit.endMs)).join(", ")} '
          'logmel ${melHit.map((hit) => _clocked(hit.startMs, hit.endMs)).join(", ")}',
        );
      }

      expect(chapter.map((hit) => hit.episodeId).toSet(), {
        for (final hit in logMel) hit.episodeId,
      });
      expect(chapter, hasLength(6));
      for (final hit in chapter) {
        final other = logMel.singleWhere(
          (item) => item.episodeId == hit.episodeId,
        );
        expect((hit.startMs - other.startMs).abs(), lessThan(40));
        expect((hit.endMs - other.endMs).abs(), lessThan(40));
      }
      expect(olafMs * 2 < melWatch.elapsedMilliseconds, isTrue);
      expect(printBytes * 10 < melBytes, isTrue);
    },
    skip: dir == null || dir.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

({int episodeId, int startMs, int endMs}) _placed(
  _Opening episode,
  int startMs,
  int endMs,
) {
  final snapped = snapPortionToSilence(
    episode.envelope,
    startMs,
    endMs,
    durationMs: logMelSearchWindowMs,
  );
  return (
    episodeId: episode.id,
    startMs: snapped.startMs,
    endMs: snapped.endMs,
  );
}

String _clocked(int startMs, int endMs) {
  String clock(int ms) {
    final minutes = ms ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final centis = (ms % 1000) ~/ 10;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.'
        '${centis.toString().padLeft(2, '0')}';
  }

  return '${clock(startMs)}-${clock(endMs)}';
}

class _Opening {
  _Opening({
    required this.id,
    required this.name,
    required this.samples,
    required this.envelope,
    required this.prints,
  });

  final int id;
  final String name;
  final Int16List samples;
  final Uint8List envelope;
  final List<OlafLandmark> prints;
}
