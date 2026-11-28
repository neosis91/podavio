import 'analysis_overview.dart';

/// Étapes montrées pour un épisode, dans l’ordre où l’analyse les fait.
enum EpisodeAnalysisPhase { preparing, decoding, saving, matching }

const episodeAnalysisPhaseLabel = <EpisodeAnalysisPhase, String>{
  EpisodeAnalysisPhase.preparing: 'Preparing the episode',
  EpisodeAnalysisPhase.decoding: 'Decoding the audio',
  EpisodeAnalysisPhase.saving: 'Saving the fingerprint',
  EpisodeAnalysisPhase.matching: 'Comparing episodes',
};

/// Ce que la base sait d’un épisode téléchargé, sans l’état en direct.
class EpisodeAnalysisSnapshot {
  const EpisodeAnalysisSnapshot({
    required this.episodeId,
    required this.title,
    this.fingerprintStatus,
    this.chromaprint = false,
  });

  final int episodeId;
  final String title;

  /// `done`, `failed`, `running`, ou nul si aucune empreinte n’a été tentée.
  final String? fingerprintStatus;

  /// L’empreinte stockée est un Chromaprint utilisable.
  final bool chromaprint;
}

class EpisodeAnalysisStep {
  const EpisodeAnalysisStep({required this.phase, required this.status});

  final EpisodeAnalysisPhase phase;
  final AnalysisOverviewStatus status;
}

class EpisodeAnalysisView {
  const EpisodeAnalysisView({
    required this.episodeId,
    required this.title,
    required this.status,
    required this.steps,
  });

  final int episodeId;
  final String title;
  final AnalysisOverviewStatus status;
  final List<EpisodeAnalysisStep> steps;
}

/// [runningPhase] vaut 0 à 3 quand cet épisode est celui en cours.
/// 0 prépare, 1 décode, 2 enregistre, 3 compare.
EpisodeAnalysisView describeEpisodeAnalysis(
  EpisodeAnalysisSnapshot episode, {
  required bool running,
  int? runningPhase,
  required bool queued,
}) {
  return EpisodeAnalysisView(
    episodeId: episode.episodeId,
    title: episode.title,
    status: _headerStatus(episode, running: running, queued: queued),
    steps: _steps(episode, running: running, runningPhase: runningPhase),
  );
}

AnalysisOverviewStatus _headerStatus(
  EpisodeAnalysisSnapshot episode, {
  required bool running,
  required bool queued,
}) {
  if (running || episode.fingerprintStatus == 'running') {
    return AnalysisOverviewStatus.inProgress;
  }
  if (episode.fingerprintStatus == 'failed') {
    return AnalysisOverviewStatus.failed;
  }
  if (queued || (episode.fingerprintStatus ?? '').isEmpty) {
    return AnalysisOverviewStatus.pending;
  }
  return AnalysisOverviewStatus.analysed;
}

List<EpisodeAnalysisStep> _steps(
  EpisodeAnalysisSnapshot episode, {
  required bool running,
  int? runningPhase,
}) {
  if (running) {
    final current = (runningPhase ?? 0).clamp(0, 3);
    return [
      for (var index = 0; index < EpisodeAnalysisPhase.values.length; index++)
        EpisodeAnalysisStep(
          phase: EpisodeAnalysisPhase.values[index],
          status: index < current
              ? AnalysisOverviewStatus.analysed
              : index == current
              ? AnalysisOverviewStatus.inProgress
              : AnalysisOverviewStatus.pending,
        ),
    ];
  }
  if (episode.fingerprintStatus == 'done') {
    return [
      for (final phase in EpisodeAnalysisPhase.values)
        EpisodeAnalysisStep(
          phase: phase,
          status: AnalysisOverviewStatus.analysed,
        ),
    ];
  }
  if (episode.fingerprintStatus == 'failed') {
    final failedAt = episode.chromaprint ? 2 : 1;
    return [
      for (var index = 0; index < EpisodeAnalysisPhase.values.length; index++)
        EpisodeAnalysisStep(
          phase: EpisodeAnalysisPhase.values[index],
          status: index < failedAt
              ? AnalysisOverviewStatus.analysed
              : index == failedAt
              ? AnalysisOverviewStatus.failed
              : AnalysisOverviewStatus.pending,
        ),
    ];
  }
  if (episode.fingerprintStatus == 'running') {
    final current = episode.chromaprint ? 2 : 1;
    return [
      for (var index = 0; index < EpisodeAnalysisPhase.values.length; index++)
        EpisodeAnalysisStep(
          phase: EpisodeAnalysisPhase.values[index],
          status: index < current
              ? AnalysisOverviewStatus.analysed
              : index == current
              ? AnalysisOverviewStatus.inProgress
              : AnalysisOverviewStatus.pending,
        ),
    ];
  }
  return [
    for (final phase in EpisodeAnalysisPhase.values)
      EpisodeAnalysisStep(phase: phase, status: AnalysisOverviewStatus.pending),
  ];
}

/// Pourcentage déjà fait sur les quatre étapes, chacune pour un quart.
///
/// Le décodage en cours ajoute la part d’audio déjà écrite, donc cette
/// étape avance de 25 % à 50 %. Les autres étapes en cours comptent
/// quand elles sont finies.
int groupedStepPercent(
  List<EpisodeAnalysisStep> steps, {
  double? decodeFraction,
}) {
  if (steps.isEmpty) return 0;
  var done = 0.0;
  for (final step in steps) {
    if (step.status == AnalysisOverviewStatus.analysed) {
      done += 1;
      continue;
    }
    if (step.status != AnalysisOverviewStatus.inProgress) continue;
    if (step.phase == EpisodeAnalysisPhase.decoding && decodeFraction != null) {
      done += decodeFraction.clamp(0.0, 1.0);
    }
  }
  final percent = done / steps.length * 100;
  if (percent <= 0) return 0;
  if (percent >= 100) return 100;
  return percent.round();
}

/// Vitesse mesurée sur le décodage en cours.
class DecodePace {
  const DecodePace({
    required this.samples,
    required this.expected,
    required this.sampleRate,
    required this.started,
  });

  final int samples;
  final int expected;
  final int sampleRate;
  final DateTime started;
}

/// Temps qui reste à ce décodage, d’après les échantillons déjà écrits.
Duration? remainingFromDecode(DecodePace pace, DateTime now) {
  if (pace.samples <= 0 || pace.expected <= 0) return null;
  final elapsed = now.difference(pace.started).inMilliseconds;
  if (elapsed <= 0) return null;
  if (pace.samples >= pace.expected) return Duration.zero;
  final left = elapsed * (pace.expected - pace.samples) ~/ pace.samples;
  if (left <= 0) return Duration.zero;
  return Duration(milliseconds: left);
}

/// Temps avant la fin de [episodeId] : le décodage mesuré s’il est en cours,
/// sinon la même vitesse appliquée aux épisodes qui le précèdent.
Duration? episodeRemaining({
  required int episodeId,
  required int? runningEpisodeId,
  required int? runningDurationSeconds,
  required DateTime? runningSince,
  required bool decoding,
  required List<({int episodeId, int? durationSeconds})> pending,
  required DateTime now,
  DecodePace? pace,
  int measuredMs = 0,
  int measuredAudioSeconds = 0,
  int fallbackMsPerAudioSecond = 150,
}) {
  Duration? runningLeft() {
    if (runningEpisodeId == null) return null;
    if (decoding && pace != null) {
      final live = remainingFromDecode(pace, now);
      if (live != null) return live;
    }
    return _fromRate(
      runningDurationSeconds,
      spentSince: runningSince,
      now: now,
      pace: pace,
      measuredMs: measuredMs,
      measuredAudioSeconds: measuredAudioSeconds,
      fallbackMsPerAudioSecond: fallbackMsPerAudioSecond,
    );
  }

  if (episodeId == runningEpisodeId) {
    if (!decoding) return null;
    return runningLeft();
  }
  final index = pending.indexWhere((job) => job.episodeId == episodeId);
  if (index < 0) return null;
  var ms = runningLeft()?.inMilliseconds ?? 0;
  for (var i = 0; i <= index; i++) {
    ms += _fromRate(
      pending[i].durationSeconds,
      now: now,
      pace: pace,
      measuredMs: measuredMs,
      measuredAudioSeconds: measuredAudioSeconds,
      fallbackMsPerAudioSecond: fallbackMsPerAudioSecond,
    ).inMilliseconds;
  }
  if (ms <= 0) return null;
  return Duration(milliseconds: ms);
}

Duration _fromRate(
  int? seconds, {
  DateTime? spentSince,
  required DateTime now,
  DecodePace? pace,
  required int measuredMs,
  required int measuredAudioSeconds,
  required int fallbackMsPerAudioSecond,
}) {
  if (seconds == null || seconds <= 0) return Duration.zero;
  var ms = seconds * fallbackMsPerAudioSecond;
  if (pace != null && pace.samples > 0 && pace.sampleRate > 0) {
    final elapsed = now.difference(pace.started).inMilliseconds;
    if (elapsed > 0) {
      ms = seconds * elapsed * pace.sampleRate ~/ pace.samples;
    }
  } else if (measuredAudioSeconds > 0 && measuredMs > 0) {
    ms = seconds * measuredMs ~/ measuredAudioSeconds;
  }
  if (spentSince != null) {
    final spent = now.difference(spentSince).inMilliseconds;
    if (spent > 0) ms = ms > spent ? ms - spent : 0;
  }
  return Duration(milliseconds: ms);
}
