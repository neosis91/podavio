import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/analysis_overview.dart';
import 'package:podavio/data/episode_analysis.dart';

void main() {
  EpisodeAnalysisSnapshot episode({String? status, bool chromaprint = false}) {
    return EpisodeAnalysisSnapshot(
      episodeId: 1,
      title: 'Un',
      fingerprintStatus: status,
      chromaprint: chromaprint,
    );
  }

  test('an episode never analysed waits on every step', () {
    final view = describeEpisodeAnalysis(
      episode(),
      running: false,
      queued: false,
    );
    expect(view.status, AnalysisOverviewStatus.pending);
    expect(
      view.steps.map((step) => step.status),
      everyElement(AnalysisOverviewStatus.pending),
    );
  });

  test('a finished episode checks every step', () {
    final view = describeEpisodeAnalysis(
      episode(status: 'done', chromaprint: true),
      running: false,
      queued: false,
    );
    expect(view.status, AnalysisOverviewStatus.analysed);
    expect(
      view.steps.map((step) => step.status),
      everyElement(AnalysisOverviewStatus.analysed),
    );
  });

  test('a failed decode marks decoding and leaves the rest waiting', () {
    final view = describeEpisodeAnalysis(
      episode(status: 'failed'),
      running: false,
      queued: true,
    );
    expect(view.status, AnalysisOverviewStatus.failed);
    expect(view.steps[0].status, AnalysisOverviewStatus.analysed);
    expect(view.steps[1].phase, EpisodeAnalysisPhase.decoding);
    expect(view.steps[1].status, AnalysisOverviewStatus.failed);
    expect(view.steps[2].status, AnalysisOverviewStatus.pending);
    expect(view.steps[3].status, AnalysisOverviewStatus.pending);
  });

  test('the header percent groups the four steps', () {
    final waiting = describeEpisodeAnalysis(
      episode(),
      running: false,
      queued: true,
    );
    expect(groupedStepPercent(waiting.steps), 0);

    final decoding = describeEpisodeAnalysis(
      episode(),
      running: true,
      runningPhase: 1,
      queued: false,
    );
    expect(groupedStepPercent(decoding.steps), 25);
    expect(groupedStepPercent(decoding.steps, decodeFraction: 0.5), 38);
    expect(groupedStepPercent(decoding.steps, decodeFraction: 1), 50);

    final done = describeEpisodeAnalysis(
      episode(status: 'done', chromaprint: true),
      running: false,
      queued: false,
    );
    expect(groupedStepPercent(done.steps), 100);
  });

  test('decode progress gives the time left from samples already written', () {
    final started = DateTime.utc(2026, 1, 1, 0, 0, 0);
    final left = remainingFromDecode(
      DecodePace(
        samples: 1000,
        expected: 4000,
        sampleRate: 11025,
        started: started,
      ),
      started.add(const Duration(seconds: 10)),
    );
    expect(left, const Duration(seconds: 30));
  });

  test('a queued episode waits for the one being decoded', () {
    final started = DateTime.utc(2026, 1, 1, 0, 0, 0);
    final now = started.add(const Duration(seconds: 10));
    final left = episodeRemaining(
      episodeId: 2,
      runningEpisodeId: 1,
      runningDurationSeconds: 40,
      runningSince: started,
      decoding: true,
      pending: [(episodeId: 2, durationSeconds: 40)],
      now: now,
      pace: DecodePace(
        samples: 11025 * 10,
        expected: 11025 * 40,
        sampleRate: 11025,
        started: started,
      ),
    );
    // 30 s still on the current file, then 40 s at the same speed.
    expect(left, const Duration(seconds: 70));
  });

  test('the running episode shows the current step', () {
    final view = describeEpisodeAnalysis(
      episode(),
      running: true,
      runningPhase: 1,
      queued: true,
    );
    expect(view.status, AnalysisOverviewStatus.inProgress);
    expect(view.steps[0].status, AnalysisOverviewStatus.analysed);
    expect(view.steps[1].status, AnalysisOverviewStatus.inProgress);
    expect(view.steps[2].status, AnalysisOverviewStatus.pending);
    expect(view.steps[3].status, AnalysisOverviewStatus.pending);
  });
}
