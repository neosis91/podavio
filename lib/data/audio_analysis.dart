import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analysis_pace.dart';
import 'app_database.dart';
import 'chromaprint.dart';
import 'envelope.dart';
import 'episode_audio_analyzer.dart';
import 'log_mel.dart';
import 'log_mel_match.dart';
import 'network_stings.dart';
import 'pcm_decoder.dart';
import 'providers.dart';
import '../settings/settings_controller.dart';
import 'segment_finder.dart';
import 'segment_match.dart';
import 'skip_segments.dart';

final pcmDecoderProvider = Provider<PcmDecoder>((ref) {
  return const PlatformPcmDecoder();
});

/// Vrai moteur : décodage natif, empreinte Chromaprint, motifs du podcast.
final episodeAudioAnalyzerProvider = Provider<EpisodeAudioAnalyzer>((ref) {
  return ChromaprintEpisodeAudioAnalyzer(
    database: ref.watch(databaseProvider),
    decoder: ref.watch(pcmDecoderProvider),
  );
});

/// Durée max d’un épisode. Au-delà, il est marqué en échec et la file avance.
const audioAnalysisBudget = Duration(minutes: 8);

/// Le décodeur natif s’arrête avant le délai Dart, pour rendre la main.
const nativeDecodeBudget = Duration(minutes: 6);

final audioAnalysisBudgetProvider = Provider<Duration>(
  (ref) => audioAnalysisBudget,
);

/// `--dart-define=PODAVIO_ANALYSIS_TRACE=true` journalise durée et RSS.
const audioAnalysisTraceFromEnvironment = bool.fromEnvironment(
  'PODAVIO_ANALYSIS_TRACE',
);

bool audioAnalysisTrace = audioAnalysisTraceFromEnvironment;

/// File d’analyse. Une empreinte à la fois, hors de l’isolate d’interface.
final audioAnalysisProvider =
    NotifierProvider<AudioAnalysisController, AudioAnalysisProgress>(
      AudioAnalysisController.new,
    );

/// Au démarrage : les analyses interrompues deviennent des échecs, puis
/// les épisodes jamais empreintés sont mis en file si l’automatisme est actif.
final audioAnalysisBootstrapProvider = Provider<void>((ref) {
  if (ref.watch(databasePhaseProvider) != DatabasePhase.open) return;
  final notifier = ref.read(audioAnalysisProvider.notifier);
  unawaited(notifier.recoverInterrupted());
  final automatic = ref.watch(
    settingsProvider.select((settings) => settings.automaticAudioAnalysis),
  );
  if (!automatic) {
    notifier.cancelAutomatic();
    return;
  }
  unawaited(notifier.enqueueMissing());
});

/// À l’ouverture de l’écran de classement, pour ce podcast.
final podcastAnalysisKickProvider = Provider.family<void, int>((
  ref,
  podcastId,
) {
  if (ref.watch(databasePhaseProvider) != DatabasePhase.open) return;
  if (!ref.watch(
    settingsProvider.select((settings) => settings.automaticAudioAnalysis),
  )) {
    return;
  }
  unawaited(
    ref
        .read(audioAnalysisProvider.notifier)
        .enqueueMissing(podcastId: podcastId),
  );
});

enum AnalysisStep { preparing, decoding, saving, matching }

/// Rythme observé sur ce téléphone avant la première mesure de la session :
/// 1447 s d’audio en 217 s, 1512 s en 211 s, 321 s en 53 s.
const analysisMsPerAudioSecond = 150;

/// Temps restant pour [podcastId], y compris l’épisode déjà en cours,
/// qui bloque la file même s’il appartient à un autre podcast.
Duration? estimateAnalysisRemaining({
  required int podcastId,
  required int? runningPodcastId,
  required int? runningDurationSeconds,
  required DateTime? runningSince,
  required DateTime now,
  required List<({int podcastId, int? durationSeconds})> pending,
  required int measuredMs,
  required int measuredAudioSeconds,
}) {
  var total = 0;
  var any = false;
  void add(int? seconds, {bool running = false}) {
    if (seconds == null || seconds <= 0) return;
    var ms = measuredAudioSeconds > 0 && measuredMs > 0
        ? seconds * measuredMs ~/ measuredAudioSeconds
        : seconds * analysisMsPerAudioSecond;
    if (running && runningSince != null) {
      final spent = now.difference(runningSince).inMilliseconds;
      if (spent > 0) ms = ms > spent ? ms - spent : 0;
    }
    total += ms;
    any = true;
  }

  if (runningPodcastId != null) {
    add(runningDurationSeconds, running: true);
  }
  for (final job in pending) {
    if (job.podcastId == podcastId) add(job.durationSeconds);
  }
  if (!any) return null;
  return Duration(milliseconds: total);
}

class AudioAnalysisProgress {
  const AudioAnalysisProgress({
    this.runningEpisodeId,
    this.runningPodcastId,
    this.runningDurationSeconds,
    this.runningSince,
    this.step,
    this.stepAt,
    this.measuredMs = 0,
    this.measuredAudioSeconds = 0,
    this.pending = const [],
  });

  final int? runningEpisodeId;
  final int? runningPodcastId;
  final int? runningDurationSeconds;
  final DateTime? runningSince;
  final AnalysisStep? step;
  final DateTime? stepAt;
  final int measuredMs;
  final int measuredAudioSeconds;
  final List<({int episodeId, int podcastId, int? durationSeconds})> pending;

  Duration? remainingFor(int podcastId, DateTime now) {
    return estimateAnalysisRemaining(
      podcastId: podcastId,
      runningPodcastId: runningPodcastId,
      runningDurationSeconds: runningDurationSeconds,
      runningSince: runningSince,
      now: now,
      pending: [
        for (final job in pending)
          (podcastId: job.podcastId, durationSeconds: job.durationSeconds),
      ],
      measuredMs: measuredMs,
      measuredAudioSeconds: measuredAudioSeconds,
    );
  }

  int pendingFor(int podcastId) {
    var count = 0;
    for (final job in pending) {
      if (job.podcastId == podcastId) count++;
    }
    if (runningPodcastId == podcastId) count++;
    return count;
  }
}

class _Job {
  _Job({
    required this.episodeId,
    required this.podcastId,
    required this.durationSeconds,
    required this.force,
    required this.automatic,
  });

  final int episodeId;
  final int podcastId;
  final int? durationSeconds;
  bool force;
  final bool automatic;
  var finished = false;
  final done = Completer<void>();
  final followers = <Completer<void>>[];
  var again = false;
}

class AudioAnalysisController extends Notifier<AudioAnalysisProgress> {
  final _wait = <_Job>[];
  final _reserved = <int>{};
  final _joiners = <int, List<Completer<void>>>{};
  final _joinForce = <int>{};
  int? _frontPodcast;
  _Job? _running;
  DateTime? _runningSince;
  var _measuredMs = 0;
  var _measuredAudioSeconds = 0;
  Future<void>? _pumpFuture;
  Isolate? _worker;
  Timer? _budgetTimer;
  var _epoch = 0;

  @override
  AudioAnalysisProgress build() {
    ref.onDispose(_abandon);
    return const AudioAnalysisProgress();
  }

  /// Annule le délai tout de suite : un test qui ferme l’arbre ne doit pas
  /// garder un timer de 8 minutes, et l’interface non plus.
  void _abandon() {
    _budgetTimer?.cancel();
    _budgetTimer = null;
    _epoch++;
    _worker?.kill(priority: Isolate.immediate);
    final running = _running;
    if (running != null) _complete(running);
    for (final job in _wait) {
      _complete(job);
    }
    _wait.clear();
    _reserved.clear();
  }

  bool get _automaticAllowed {
    try {
      return ref.read(settingsProvider).automaticAudioAnalysis;
    } catch (_) {
      return true;
    }
  }

  Duration get _budget {
    try {
      return ref.read(audioAnalysisBudgetProvider);
    } catch (_) {
      return audioAnalysisBudget;
    }
  }

  /// Les analyses tuées au milieu (force-stop) ne sont pas relancées.
  Future<void> recoverInterrupted() async {
    try {
      if (!ref.mounted) return;
      await ref.read(databaseProvider).failInterruptedFingerprints();
    } catch (error, stack) {
      debugPrint('Analyse audio: $error\n$stack');
    }
  }

  /// Vide la file automatique et abandonne l’épisode en cours s’il l’est.
  void cancelAutomatic() {
    if (_running?.automatic == true) {
      _running!.again = false;
      _epoch++;
      _worker?.kill(priority: Isolate.immediate);
    }
    final dropped = [
      for (final job in _wait)
        if (job.automatic) job,
    ];
    _wait.removeWhere((job) => job.automatic);
    for (final job in dropped) {
      _reserved.remove(job.episodeId);
      _complete(job);
    }
    _publish();
  }

  /// [force] recalcule l’empreinte. [automatic] respecte le réglage.
  Future<void> enqueueEpisode(
    int episodeId, {
    bool force = false,
    bool automatic = false,
  }) async {
    try {
      if (!ref.mounted) return;
      if (automatic && !_automaticAllowed) return;
      if (_reserved.contains(episodeId)) {
        await _join(episodeId, force: force);
        return;
      }
      _reserved.add(episodeId);
      final episode = await ref.read(databaseProvider).episodeById(episodeId);
      if (!ref.mounted || episode == null || _dropped(episodeId)) {
        _release(episodeId);
        return;
      }
      final path = episode.downloadPath?.trim() ?? '';
      if (path.isEmpty) {
        _release(episodeId);
        return;
      }
      final job = _Job(
        episodeId: episode.id,
        podcastId: episode.podcastId,
        durationSeconds: episode.durationSeconds,
        force: force || _joinForce.remove(episodeId),
        automatic: automatic,
      );
      final waiting = _joiners.remove(episodeId);
      if (waiting != null) job.followers.addAll(waiting);
      _wait.add(job);
      final podcastId = job.podcastId;
      if (podcastId == _frontPodcast) _bringToFront(podcastId);
      _publish();
      unawaited(_ensurePump());
      await job.done.future;
    } catch (error, stack) {
      _release(episodeId);
      debugPrint('Analyse audio: $error\n$stack');
    }
  }

  Future<void> enqueueMissing({int? podcastId}) async {
    try {
      if (!ref.mounted || !_automaticAllowed) return;
      // Pas de notification pendant la construction de l’écran : le lecteur
      // ouvert par-dessus se reconstruit en même temps et l’arbre casse.
      if (podcastId != null) _frontPodcast = podcastId;
      final rows = await ref
          .read(databaseProvider)
          .downloadedEpisodesMissingFingerprint(podcastId: podcastId);
      if (!ref.mounted) return;
      if (podcastId != null) _prefer(podcastId);
      final pending = <Future<void>>[];
      for (final row in rows) {
        pending.add(enqueueEpisode(row.id, automatic: true));
      }
      await Future.wait(pending);
    } catch (error, stack) {
      debugPrint('Analyse audio: $error\n$stack');
    }
  }

  Future<void> _join(int episodeId, {required bool force}) {
    final running = _running;
    if (running != null && running.episodeId == episodeId) {
      if (force) {
        running.force = true;
        running.again = true;
        final follower = Completer<void>();
        running.followers.add(follower);
        return follower.future;
      }
      return running.done.future;
    }
    for (final job in _wait) {
      if (job.episodeId != episodeId) continue;
      if (force) job.force = true;
      return job.done.future;
    }
    final follower = Completer<void>();
    (_joiners[episodeId] ??= []).add(follower);
    if (force) _joinForce.add(episodeId);
    return follower.future;
  }

  bool _dropped(int episodeId) => !_reserved.contains(episodeId);

  void _release(int episodeId) {
    _reserved.remove(episodeId);
    _joinForce.remove(episodeId);
    final waiting = _joiners.remove(episodeId);
    if (waiting == null) return;
    for (final follower in waiting) {
      if (!follower.isCompleted) follower.complete();
    }
  }

  void _complete(_Job job) {
    if (!job.done.isCompleted) job.done.complete();
    for (final follower in job.followers) {
      if (!follower.isCompleted) follower.complete();
    }
    job.followers.clear();
  }

  /// Bouton de l’écran de classement. Recalcule les empreintes manquantes,
  /// puis les motifs, même si tout est déjà empreinté.
  Future<void> analyzeDownloaded(int podcastId) async {
    try {
      if (!ref.mounted) return;
      final database = ref.read(databaseProvider);
      final episodes = await database.episodesForPodcast(podcastId);
      var queued = false;
      for (final episode in episodes) {
        final path = episode.downloadPath?.trim() ?? '';
        if (path.isEmpty) continue;
        final stored = await database.fingerprintForEpisode(episode.id);
        final mel = await database.logMelForEpisode(episode.id);
        final status = await database.fingerprintStatus(episode.id);
        if (stored == null ||
            !isChromaprintPrint(stored.data) ||
            stored.speech == null ||
            mel == null ||
            status == 'failed' ||
            status == 'running') {
          queued = true;
          await enqueueEpisode(episode.id);
        }
      }
      if (!queued && ref.mounted) {
        await syncPodcastAnalysis(database, podcastId);
      }
    } catch (error, stack) {
      debugPrint('Analyse audio: $error\n$stack');
    }
  }

  /// L’écran de classement de [podcastId] passe devant le reste de la file.
  ///
  /// Le compteur de cet écran ne baisse que pour ses propres épisodes.
  /// Sans ça, un podcast qui n’a plus qu’un épisode reste affiché à 1
  /// pendant que la file traite d’abord tous les autres.
  void _prefer(int podcastId) {
    _frontPodcast = podcastId;
    final moved = _bringToFront(podcastId);
    if (moved) _publish();
  }

  bool _bringToFront(int podcastId) {
    final mine = <_Job>[];
    final rest = <_Job>[];
    for (final job in _wait) {
      if (job.podcastId == podcastId) {
        mine.add(job);
      } else {
        rest.add(job);
      }
    }
    if (mine.isEmpty || rest.isEmpty) return false;
    for (var i = 0; i < mine.length; i++) {
      if (identical(_wait[i], mine[i])) continue;
      _wait
        ..clear()
        ..addAll(mine)
        ..addAll(rest);
      return true;
    }
    return false;
  }

  void _publish() {
    if (!ref.mounted) return;
    state = _view(step: state.step, stepAt: state.stepAt);
  }

  AudioAnalysisProgress _view({AnalysisStep? step, DateTime? stepAt}) {
    final job = _running;
    return AudioAnalysisProgress(
      runningEpisodeId: job?.episodeId,
      runningPodcastId: job?.podcastId,
      runningDurationSeconds: job?.durationSeconds,
      runningSince: job == null ? null : _runningSince,
      step: job == null ? null : step,
      stepAt: job == null ? null : stepAt,
      measuredMs: _measuredMs,
      measuredAudioSeconds: _measuredAudioSeconds,
      pending: [
        for (final waiting in _wait)
          (
            episodeId: waiting.episodeId,
            podcastId: waiting.podcastId,
            durationSeconds: waiting.durationSeconds,
          ),
      ],
    );
  }

  void _rememberFinished(_Job job) {
    final started = _runningSince;
    final seconds = job.durationSeconds;
    if (started == null ||
        !job.finished ||
        job.again ||
        seconds == null ||
        seconds <= 0) {
      return;
    }
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    if (elapsed <= 0) return;
    _measuredMs += elapsed;
    _measuredAudioSeconds += seconds;
  }

  void _step(AnalysisStep step) {
    if (!ref.mounted || state.runningEpisodeId == null || state.step == step) {
      return;
    }
    state = _view(step: step, stepAt: DateTime.now());
  }

  Future<void> _ensurePump() {
    return _pumpFuture ??= _run();
  }

  Future<void> _run() async {
    try {
      while (_wait.isNotEmpty && ref.mounted) {
        final job = _wait.removeAt(0);
        if (job.automatic && !_automaticAllowed) {
          _reserved.remove(job.episodeId);
          _complete(job);
          continue;
        }
        _running = job;
        _runningSince = DateTime.now();
        state = _view(step: AnalysisStep.preparing, stepAt: _runningSince);
        try {
          await _analyze(job);
        } catch (error, stack) {
          debugPrint('Analyse audio: $error\n$stack');
        } finally {
          _running = null;
          if (job.again &&
              ref.mounted &&
              (!job.automatic || _automaticAllowed)) {
            final next = _Job(
              episodeId: job.episodeId,
              podcastId: job.podcastId,
              durationSeconds: job.durationSeconds,
              force: true,
              automatic: job.automatic,
            );
            next.followers.addAll(job.followers);
            job.followers.clear();
            _wait.insert(0, next);
            job.again = false;
          } else {
            _reserved.remove(job.episodeId);
          }
          _complete(job);
        }
      }
    } finally {
      _pumpFuture = null;
      if (ref.mounted) {
        state = _view();
      }
      if (_wait.isNotEmpty && ref.mounted) {
        unawaited(_ensurePump());
      }
    }
  }

  Future<void> _analyze(_Job job) async {
    final done = Completer<void>();
    unawaited(() async {
      try {
        await _analyzeBody(job);
        if (!done.isCompleted) done.complete();
      } catch (error, stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      }
    }());
    var timedOut = false;
    _budgetTimer?.cancel();
    _budgetTimer = Timer(_budget, () {
      if (done.isCompleted) return;
      timedOut = true;
      _epoch++;
      _worker?.kill(priority: Isolate.immediate);
      done.complete();
    });
    try {
      await done.future;
    } finally {
      _budgetTimer?.cancel();
      _budgetTimer = null;
    }
    if (!timedOut) {
      _rememberFinished(job);
      return;
    }
    debugPrint('Analyse audio: délai dépassé pour l’épisode ${job.episodeId}.');
    if (!ref.mounted) return;
    await ref.read(databaseProvider).markFingerprintFailed(job.episodeId);
  }

  Future<void> _analyzeBody(_Job job) async {
    final epoch = _epoch;
    bool live() => epoch == _epoch && ref.mounted;
    if (!live()) return;
    final database = ref.read(databaseProvider);
    try {
      final episode = await database.episodeById(job.episodeId);
      if (!live() || episode == null) return;
      final path = episode.downloadPath?.trim() ?? '';
      if (path.isEmpty) return;
      final existing = job.force
          ? null
          : await database.fingerprintForEpisode(episode.id);
      final mel = job.force
          ? null
          : await database.logMelForEpisode(episode.id);
      if (!live()) return;
      final needPrint = existing == null || !isChromaprintPrint(existing.data);
      final needSpeech = existing == null || existing.speech == null;
      final watch = Stopwatch()..start();
      if (needPrint || mel == null || needSpeech) {
        _step(AnalysisStep.decoding);
        await database.markFingerprintRunning(episode.id);
        if (!live()) return;
        final analyzed = await _analyzeDecoded(
          ref.read(pcmDecoderProvider),
          path,
          paced: true,
          offUi: _offUiPaced,
        );
        if (!live()) return;
        if (analyzed == null) {
          await database.markFingerprintFailed(episode.id);
          debugPrint(
            'Analyse audio: pas d’empreinte pour l’épisode ${episode.id}.',
          );
          return;
        }
        debugPrint(
          'Analyse audio: épisode ${episode.id}, '
          '${analyzed.fingerprint.length} valeurs, '
          '${analyzed.elapsedMs} ms.',
        );
        traceAnalysis(
          'épisode ${episode.id} empreinte ${analyzed.fingerprintMs} ms, '
          'log-mel ${analyzed.logMelMs} ms, parole ${analyzed.speechMs} ms, '
          'rss ${analyzed.peakRss} o, retenu ${analyzed.retainedBytes} o',
        );
        if (!live()) return;
        if (needPrint || job.force || needSpeech) {
          _step(AnalysisStep.saving);
          await database.upsertEpisodeFingerprint(
            episodeId: episode.id,
            data: encodeFingerprint(analyzed.fingerprint),
            hopMicros: chromaprintStoredHopMicros,
            speech: analyzed.speech,
          );
        }
        if (!live()) return;
        if (analyzed.envelope.isNotEmpty) {
          await database.setFingerprintEnvelope(episode.id, analyzed.envelope);
        }
        if (!live()) return;
        if (analyzed.logMel != null) {
          await database.upsertEpisodeLogMel(
            episodeId: episode.id,
            data: analyzed.logMel!,
          );
        }
        if (!live()) return;
        await database.markFingerprintDone(episode.id);
      }
      if (!live()) return;
      _step(AnalysisStep.matching);
      final match = Stopwatch()..start();
      await syncPodcastAnalysis(
        database,
        episode.podcastId,
        focusEpisodeId: episode.id,
        offUi: _offUi,
      );
      debugPrint(
        'Analyse audio: podcast ${episode.podcastId}, '
        'rapprochement ${match.elapsedMilliseconds} ms '
        '(décodage compris ${watch.elapsedMilliseconds} ms).',
      );
      job.finished = true;
    } finally {
      if (!live() && ref.mounted) {
        final status = await database.fingerprintStatus(job.episodeId);
        if (status == 'running') {
          await database.markFingerprintFailed(job.episodeId);
        }
      }
    }
  }

  Future<Object?> _offUi(
    void Function(List<Object?> message) entry,
    Object? message,
  ) {
    return _spawnTracked(entry, message, paced: false);
  }

  Future<Object?> _offUiPaced(
    void Function(List<Object?> message) entry,
    Object? message,
  ) {
    return _spawnTracked(entry, message, paced: true);
  }

  Future<Object?> _spawnTracked(
    void Function(List<Object?> message) entry,
    Object? message, {
    required bool paced,
  }) async {
    final port = ReceivePort();
    final isolate = await Isolate.spawn(entry, <Object?>[
      port.sendPort,
      message,
    ], debugName: 'podavio-analysis');
    _worker = isolate;
    Timer? pace;
    try {
      final result = Completer<Object?>();
      SendPort? control;
      port.listen((event) {
        if (paced && event is SendPort) {
          control = event;
          void push() {
            control?.send(AnalysisPace.mode);
          }

          push();
          pace = Timer.periodic(const Duration(milliseconds: 250), (_) {
            push();
          });
          return;
        }
        if (!result.isCompleted) result.complete(event);
      });
      final value = await result.future;
      if (value is List && value.isNotEmpty && value.first == 'error') {
        throw StateError('${value[1]}');
      }
      return value;
    } finally {
      pace?.cancel();
      if (identical(_worker, isolate)) _worker = null;
      isolate.kill(priority: Isolate.immediate);
      port.close();
    }
  }
}

class ChromaprintEpisodeAudioAnalyzer implements EpisodeAudioAnalyzer {
  ChromaprintEpisodeAudioAnalyzer({
    required this.database,
    required this.decoder,
  });

  final AppDatabase database;
  final PcmDecoder decoder;

  @override
  Future<Uint8List?> computeFingerprint(File file) async {
    final analyzed = await _analyzeDecoded(decoder, file.path);
    if (analyzed == null || analyzed.fingerprint.isEmpty) return null;
    return encodeFingerprint(analyzed.fingerprint);
  }

  @override
  Future<void> findSegments(int podcastId) {
    return syncPodcastAnalysis(database, podcastId);
  }
}

Future<PcmAnalysis?> _analyzeDecoded(
  PcmDecoder decoder,
  String path, {
  bool paced = false,
  Future<Object?> Function(void Function(List<Object?>), Object?)? offUi,
}) async {
  final decoded = await decoder.decode(path, budget: nativeDecodeBudget);
  if (decoded == null) return null;
  try {
    if (decoded.sampleRate != chromaprintSampleRate) {
      debugPrint(
        'Décodage audio: ${decoded.sampleRate} Hz au lieu de $chromaprintSampleRate.',
      );
      return null;
    }
    final raw = await (offUi ?? _spawn)(
      paced ? analyzePcmPacedEntry : analyzePcmEntry,
      decoded.path,
    );
    if (raw is! List || raw.length < 9 || raw.first == 'error') return null;
    return PcmAnalysis(
      fingerprint: (raw[0]! as List).cast<int>(),
      logMel: raw[1] as Uint8List?,
      speech: raw[2]! as Uint8List,
      envelope: raw.length > 9 && raw[9] is Uint8List
          ? raw[9]! as Uint8List
          : Uint8List(0),
      peakRss: raw[3]! as int,
      retainedBytes: raw[4]! as int,
      elapsedMs: raw[5]! as int,
      fingerprintMs: raw[6]! as int,
      logMelMs: raw[7]! as int,
      speechMs: raw[8]! as int,
    );
  } finally {
    await _deleteDecoded(decoded.path);
  }
}

/// Isolate annulable. Le premier élément `error` signale un échec.
Future<Object?> _spawn(
  void Function(List<Object?> message) entry,
  Object? message,
) async {
  final port = ReceivePort();
  final isolate = await Isolate.spawn(entry, <Object?>[
    port.sendPort,
    message,
  ], debugName: 'podavio-analysis');
  try {
    return await port.first;
  } finally {
    isolate.kill(priority: Isolate.immediate);
    port.close();
  }
}

void analyzePcmEntry(List<Object?> args) {
  final send = args[0]! as SendPort;
  final path = args[1]! as String;
  try {
    send.send(_pcmMessage(analyzePcmFileSync(path)));
  } catch (error, stack) {
    send.send(<Object?>['error', '$error', '$stack']);
  }
}

/// Premier message : [SendPort] de contrôle (`play`, `front`, `fast`).
///
/// Le [ReceivePort] ouvert garde l’isolate en vie le temps du calcul.
void analyzePcmPacedEntry(List<Object?> args) {
  final send = args[0]! as SendPort;
  final path = args[1]! as String;
  final inbox = ReceivePort();
  send.send(inbox.sendPort);
  var mode = 'fast';
  inbox.listen((message) {
    if (message is String) mode = message;
  });
  unawaited(() async {
    try {
      final result = await analyzePcmFilePaced(path, () => mode);
      send.send(_pcmMessage(result));
    } catch (error, stack) {
      send.send(<Object?>['error', '$error', '$stack']);
    } finally {
      inbox.close();
    }
  }());
}

List<Object?> _pcmMessage(PcmAnalysis result) {
  return <Object?>[
    result.fingerprint,
    result.logMel,
    result.speech,
    result.peakRss,
    result.retainedBytes,
    result.elapsedMs,
    result.fingerprintMs,
    result.logMelMs,
    result.speechMs,
    result.envelope,
  ];
}

void planAnalysisEntry(List<Object?> args) {
  final send = args[0]! as SendPort;
  try {
    send.send(planAnalysisMessage(Map<String, Object?>.from(args[1]! as Map)));
  } catch (error, stack) {
    send.send(<Object?>['error', '$error', '$stack']);
  }
}

void planLogMelEntry(List<Object?> args) {
  final send = args[0]! as SendPort;
  try {
    send.send(planLogMelMessage(Map<String, Object?>.from(args[1]! as Map)));
  } catch (error, stack) {
    send.send(<Object?>['error', '$error', '$stack']);
  }
}

void traceAnalysis(String message) {
  if (!audioAnalysisTrace) return;
  debugPrint('Analyse audio: $message');
}

Future<void> _deleteDecoded(String path) async {
  if (!path.contains('podavio-pcm-')) return;
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

/// Cherche les portions posées à la main dans les épisodes du podcast.
///
/// Rien n’est détecté tout seul : seuls les gabarits rattachés à un passage
/// manuel sont cherchés (Chromaprint, vote d’offset, enveloppe, bornes).
/// Sans portion, l’analyse s’arrête à l’empreinte et à l’enveloppe déjà
/// enregistrées. Un second appel ne duplique pas les lignes et ne revient
/// pas sur un avis déjà posé.
Future<void> syncPodcastAnalysis(
  AppDatabase database,
  int podcastId, {
  int? focusEpisodeId,
  Future<Object?> Function(void Function(List<Object?>), Object?)? offUi,
}) async {
  final searched = await database.manualTemplateIds(podcastId);
  if (searched.isEmpty) return;
  final stored = await database.fingerprintedDownloads(podcastId);
  final cohort = [...stored];
  final focusEpisodeIds = {for (final row in stored) row.episode.id};
  final envelopes = await database.fingerprintEnvelopes(podcastId);
  final marks = await database.chapterMarksForEpisodes([
    for (final row in cohort) row.episode.id,
  ]);
  final episodes = <Object?>[];
  final printsById = <int, ({Uint8List bytes, int hopMicros})>{};
  for (final row in cohort) {
    final bytes = row.fingerprint.data;
    if (!isChromaprintPrint(bytes)) continue;
    final hop = row.fingerprint.hopMicros;
    final fromPrint = hop <= 0 ? 0 : bytes.lengthInBytes ~/ 4 * hop ~/ 1000;
    final fromRss = (row.episode.durationSeconds ?? 0) * 1000;
    final durationMs = fromPrint > fromRss ? fromPrint : fromRss;
    final preRoll = approximateInsertedAdMs(
      rssDurationMs: fromRss > 0 ? fromRss : null,
      fileDurationMs: fromPrint > 0 ? fromPrint : fromRss,
    );
    final chapters = marks[row.episode.id] ?? const [];
    final encoded = <Object?>[];
    for (var i = 0; i < chapters.length; i++) {
      final end = i + 1 < chapters.length
          ? chapters[i + 1].startMs
          : durationMs;
      if (end <= chapters[i].startMs) continue;
      encoded.add(<Object?>[chapters[i].startMs, end, chapters[i].title]);
    }
    episodes.add(<Object?>[
      row.episode.id,
      hop,
      durationMs,
      preRoll,
      bytes,
      row.fingerprint.speech,
      envelopes[row.episode.id],
      encoded,
    ]);
    printsById[row.episode.id] = (bytes: bytes, hopMicros: hop);
  }
  if (episodes.isNotEmpty) {
    final templates = <Object?>[];
    final reviews = await database.templateReviews(podcastId);
    final ownTemplates = [
      for (final template in await database.listSegmentTemplates(podcastId))
        if (searched.contains(template.id)) template,
    ];
    final ownTemplateIds = {for (final template in ownTemplates) template.id};
    final stale = [
      for (final template in ownTemplates)
        if (!isChromaprintPrint(template.fingerprint)) template.id,
    ];
    final recut = stale.isEmpty
        ? const <int, Uint8List>{}
        : await _recutTemplates(database, podcastId, stale, printsById);
    for (final template in ownTemplates) {
      final print = isChromaprintPrint(template.fingerprint)
          ? template.fingerprint
          : recut[template.id];
      if (print == null) continue;
      templates.add(<Object?>[
        template.id,
        template.kind.name,
        reviews[template.id],
        template.durationMs,
        print,
        template.confidence,
      ]);
    }
    final message = <String, Object?>{
      'episodes': episodes,
      'templates': templates,
      'focus': focusEpisodeId,
      'discover': false,
    };
    final raw = offUi == null
        ? await _runPlanAnalysis(message)
        : await offUi(planAnalysisEntry, message);
    if (raw is Map) {
      final plan = decodeAnalysisPlan(Map<Object?, Object?>.from(raw));
      await applyAnalysisPlan(
        database,
        podcastId,
        _keepFocusEpisodes(plan, focusEpisodeIds, ownTemplateIds),
        searchedTemplates: searched,
      );
    }
  }
}

/// Gabarits posés par l’ancien détecteur Olaf : la tranche Chromaprint est
/// recoupée dans l’empreinte d’un épisode qui porte déjà le passage, puis
/// réécrite. Le gabarit garde son id, donc ses avis. Sans épisode
/// réempreinté, il attend l’analyse suivante.
Future<Map<int, Uint8List>> _recutTemplates(
  AppDatabase database,
  int podcastId,
  List<int> templateIds,
  Map<int, ({Uint8List bytes, int hopMicros})> printsById,
) async {
  final wanted = templateIds.toSet();
  final recut = <int, Uint8List>{};
  // Un passage créé à la main avant l’empreinte de son épisode a un gabarit
  // vide : ses bornes, posées à la main, passent avant celles détectées.
  for (final segment in [
    ...await database.manualSegmentsForPodcast(podcastId),
    ...await database.fingerprintSegmentsForPodcast(podcastId),
  ]) {
    final id = segment.templateId;
    if (id == null || !wanted.contains(id) || recut.containsKey(id)) continue;
    final print = printsById[segment.episodeId];
    if (print == null || print.hopMicros <= 0) continue;
    final values = decodeFingerprint(print.bytes);
    final from = segment.startMs * 1000 ~/ print.hopMicros;
    final to = math.min(values.length, segment.endMs * 1000 ~/ print.hopMicros);
    if (to - from < 8) continue;
    final bytes = encodeFingerprint(values.sublist(from, to));
    await database.setSegmentTemplateFingerprint(id, bytes);
    recut[id] = bytes;
  }
  return recut;
}

/// Isolate.run ne doit pas fermer sur la base : le contexte capturerait
/// la connexion SQLite, qui ne traverse pas un isolate.
Future<Object?> _runPlanAnalysis(Map<String, Object?> message) {
  return Isolate.run(() => planAnalysisMessage(message));
}

Future<Object?> _runPlanLogMel(Map<String, Object?> message) {
  return Isolate.run(() => planLogMelMessage(message));
}

/// Ne conserve que les passages du podcast en cours.
///
/// Les autres épisodes du même hébergeur servent à la comparaison, pas
/// à écrire leurs lignes ici. Un gabarit d’un autre podcast n’est pas repris.
AnalysisPlan _keepFocusEpisodes(
  AnalysisPlan plan,
  Set<int> episodeIds,
  Set<int> templateIds,
) {
  final patterns = <PlannedPattern>[];
  for (final pattern in plan.patterns) {
    final segments = [
      for (final segment in pattern.segments)
        if (episodeIds.contains(segment.episodeId)) segment,
    ];
    if (segments.isEmpty) continue;
    final templateId =
        pattern.templateId != null && templateIds.contains(pattern.templateId)
        ? pattern.templateId
        : null;
    patterns.add(
      PlannedPattern(
        templateId: templateId,
        kind: pattern.kind,
        confirmed: pattern.confirmed,
        fingerprint: pattern.fingerprint,
        durationMs: pattern.durationMs,
        confidence: pattern.confidence,
        segments: segments,
      ),
    );
  }
  return AnalysisPlan(patterns);
}

/// Écrit [plan] sans doublon. Un passage déjà revu garde son avis et son type.
///
/// [searchedTemplates] : seules les occurrences de ces gabarits sont
/// revues ; les anciens passages détectés restent tels quels en base.
Future<void> applyAnalysisPlan(
  AppDatabase database,
  int podcastId,
  AnalysisPlan plan, {
  Set<int>? searchedTemplates,
}) async {
  final existing = await database.fingerprintSegmentsForPodcast(podcastId);
  final manual = await database.manualSegmentsForPodcast(podcastId);
  final keptForLogMel = {
    for (final template in await database.listSegmentTemplates(podcastId))
      if (template.logMel != null) template.id,
  };
  final touched = <int>{};
  await database.transaction(() async {
    for (final pattern in plan.patterns) {
      if (pattern.segments.isEmpty || pattern.fingerprint.isEmpty) continue;
      final templateId = await _upsertTemplate(database, podcastId, pattern);
      for (final desired in pattern.segments) {
        if (overlapsManual(
          manual,
          desired.episodeId,
          desired.startMs,
          desired.endMs,
        )) {
          continue;
        }
        final prior = _prior(existing, desired, templateId, touched);
        if (prior != null) {
          touched.add(prior.id);
          await database.updateFingerprintSegment(
            id: prior.id,
            startMs: desired.startMs,
            endMs: desired.endMs,
            matches: desired.matches,
            templateId: templateId,
            confidence: Value(desired.confidence),
          );
          continue;
        }
        final id = await database.insertSkipSegment(
          episodeId: desired.episodeId,
          startMs: desired.startMs,
          endMs: desired.endMs,
          kind: desired.kind,
          source: SkipSegmentSource.fingerprint,
          matches: desired.matches,
          confirmed: desired.confirmed,
          confidence: desired.confidence,
          templateId: templateId,
        );
        touched.add(id);
      }
    }
    for (final row in existing) {
      if (touched.contains(row.id) || row.confirmed == true) continue;
      if (searchedTemplates != null &&
          !searchedTemplates.contains(row.templateId)) {
        continue;
      }
      if (row.templateId != null && keptForLogMel.contains(row.templateId)) {
        continue;
      }
      await database.deleteSkipSegment(row.id);
    }
    await _recountTemplates(database, podcastId);
  });
}

/// Vrai si un passage corrigé à la main couvre déjà la moitié de
/// [startMs]–[endMs] : l’analyse ne le double ni ne le déplace.
bool overlapsManual(
  List<SkipSegment> manual,
  int episodeId,
  int startMs,
  int endMs,
) {
  final length = endMs - startMs;
  for (final row in manual) {
    if (row.episodeId != episodeId) continue;
    final overlap = math.min(endMs, row.endMs) - math.max(startMs, row.startMs);
    final shorter = math.min(length, row.endMs - row.startMs);
    if (overlap > 0 && overlap * 2 >= shorter) return true;
  }
  return false;
}

Future<int> _upsertTemplate(
  AppDatabase database,
  int podcastId,
  PlannedPattern pattern,
) async {
  final existingId = pattern.templateId;
  if (existingId != null) return existingId;
  return database.insertSegmentTemplate(
    podcastId: podcastId,
    kind: pattern.kind,
    fingerprint: encodeFingerprint(pattern.fingerprint),
    durationMs: pattern.durationMs,
    occurrences: pattern.occurrences,
    confidence: pattern.confidence,
  );
}

SkipSegment? _prior(
  List<SkipSegment> existing,
  PlannedSegment desired,
  int templateId,
  Set<int> used,
) {
  SkipSegment? best;
  var bestScore = 0;
  for (final row in existing) {
    if (used.contains(row.id) || row.episodeId != desired.episodeId) continue;
    final overlap = _overlap(
      row.startMs,
      row.endMs,
      desired.startMs,
      desired.endMs,
    );
    final near = (row.startMs - desired.startMs).abs() <= 2000;
    if (!overlap && !near) continue;
    var score = overlap ? 2 : 1;
    if (row.templateId == templateId) score += 2;
    if (score > bestScore) {
      best = row;
      bestScore = score;
    }
  }
  return best;
}

bool _overlap(int a0, int a1, int b0, int b1) {
  final start = a0 > b0 ? a0 : b0;
  final end = a1 < b1 ? a1 : b1;
  if (end <= start) return false;
  final shorter = (a1 - a0) < (b1 - b0) ? (a1 - a0) : (b1 - b0);
  if (shorter <= 0) return false;
  return (end - start) * 2 >= shorter;
}

Future<void> _recountTemplates(AppDatabase database, int podcastId) async {
  final templates = await database.listSegmentTemplates(podcastId);
  for (final template in templates) {
    final segments = await database.segmentsForTemplate(template.id);
    if (segments.isEmpty) {
      final hasPrint = template.fingerprint.isNotEmpty;
      final mel = template.logMel;
      final hasMel = mel != null && mel.isNotEmpty;
      if (hasPrint || hasMel) {
        if (template.occurrences != 0) {
          await database.touchSegmentTemplate(template.id, occurrences: 0);
        }
        continue;
      }
      await (database.delete(
        database.segmentTemplates,
      )..where((row) => row.id.equals(template.id))).go();
      continue;
    }
    final episodes = segments.map((row) => row.episodeId).toSet().length;
    if (episodes == template.occurrences) continue;
    await database.touchSegmentTemplate(template.id, occurrences: episodes);
  }
}

/// Gabarits log-mel, jingles courts et virgules de réseau.
///
/// Le PCM a déjà été rééchantillonné pendant l’empreinte.
Future<void> applyLogMelFindings(
  AppDatabase database,
  int podcastId, {
  Future<Object?> Function(void Function(List<Object?>), Object?)? offUi,
}) async {
  final stored = await database.logMelForPodcast(podcastId);
  if (stored.isEmpty) return;
  final ranked = [...stored]
    ..sort((a, b) => b.episodeId.compareTo(a.episodeId));
  final episodeRows = <Object?>[];
  for (final row in ranked.take(logMelCompareEpisodeCap)) {
    final episode = await database.episodeById(row.episodeId);
    if (episode == null) continue;
    episodeRows.add(<Object?>[
      row.episodeId,
      podcastId,
      row.data,
      (episode.durationSeconds ?? 0) * 1000,
      null,
    ]);
  }
  if (episodeRows.isEmpty) return;
  final templates = await database.listSegmentTemplates(podcastId);
  final reviews = await database.templateReviews(podcastId);
  final bundled = await loadBundledNetworkStings();
  final learnedRows = await database.listLearnedNetworkStings();
  final segments = await database.fingerprintSegmentsForPodcast(podcastId);
  final chroma = <Object?>[];
  for (final row in episodeRows) {
    final id = (row as List)[0]! as int;
    final print = await database.fingerprintForEpisode(id);
    if (print == null || !isChromaprintPrint(print.data)) continue;
    final hop = print.hopMicros;
    final keep = hop <= 0
        ? 0
        : math.min(
            print.data.lengthInBytes ~/ 4,
            logMelSearchWindowMs * 1000 ~/ hop + 1,
          );
    chroma.add(<Object?>[
      id,
      Uint8List.sublistView(print.data, 0, keep * 4),
      hop,
    ]);
  }
  final boundaries = [...await database.dynamicAdBoundaries()]
    ..sort((a, b) => b.episodeId.compareTo(a.episodeId));
  final message = <String, Object?>{
    'episodes': episodeRows,
    'templates': [
      for (final template in templates) <Object?>[template.id, template.logMel],
    ],
    'stings': [
      for (final sting in bundled)
        <Object?>[
          sting.name,
          encodeLogMel(sting.clip.frames.cast<List<double>>()),
        ],
      for (final sting in learnedRows)
        <Object?>[sting.name ?? 'Network sting', sting.logMel],
    ],
    'segments': [
      for (final segment in segments)
        <Object?>[
          segment.id,
          segment.episodeId,
          segment.startMs,
          segment.endMs,
          segment.matches,
          segment.templateId,
        ],
    ],
    'boundaries': [
      for (final row in boundaries.take(24))
        <Object?>[row.id, row.podcastId, row.episodeId, row.data, row.endMs],
    ],
    'learned': [
      for (final sting in learnedRows) <Object?>[sting.id, sting.logMel],
    ],
    'chroma': chroma,
  };
  final watch = Stopwatch()..start();
  final raw = offUi == null
      ? await _runPlanLogMel(message)
      : await offUi(planLogMelEntry, message);
  traceAnalysis('log-mel ${watch.elapsedMilliseconds} ms');
  if (raw is! Map) return;
  await database.transaction(() async {
    await _applyLogMelPlan(
      database,
      podcastId,
      Map<Object?, Object?>.from(raw),
      reviews,
      _adConfirmation(reviews, templates),
    );
  });
}

Future<void> _applyLogMelPlan(
  AppDatabase database,
  int podcastId,
  Map<Object?, Object?> plan,
  Map<int, bool?> reviews,
  bool? adReview,
) async {
  final envelopes = await database.fingerprintEnvelopes(podcastId);
  ({int startMs, int endMs}) edges(int episodeId, int startMs, int endMs) {
    final envelope = envelopes[episodeId];
    if (envelope == null || envelope.isEmpty) {
      return (startMs: startMs, endMs: endMs);
    }
    return snapPortionToSilence(envelope, startMs, endMs);
  }

  for (final raw in plan['jingles'] as List? ?? const []) {
    final jingle = Map<Object?, Object?>.from(raw as Map);
    final bytes = _asBytes(jingle['bytes']);
    if (bytes == null || bytes.isEmpty) continue;
    final hits = jingle['hits'] as List? ?? const [];
    final existingId = jingle['templateId'] as int?;
    final templateId =
        existingId ??
        await database.insertSegmentTemplate(
          podcastId: podcastId,
          kind: SkipSegmentKind.jingle,
          logMel: bytes,
          durationMs: jingle['durationMs']! as int,
          occurrences: hits.length,
        );
    if (existingId != null && jingle['fillLogMel'] == true) {
      await database.setTemplateLogMel(existingId, bytes);
    }
    final confirmed = reviews[templateId];
    for (final rawHit in hits) {
      final hit = Map<Object?, Object?>.from(rawHit as Map);
      final snapped = edges(
        hit['episodeId']! as int,
        hit['startMs']! as int,
        hit['endMs']! as int,
      );
      await _upsertLoose(
        database,
        episodeId: hit['episodeId']! as int,
        startMs: snapped.startMs,
        endMs: snapped.endMs,
        kind: SkipSegmentKind.jingle,
        source: SkipSegmentSource.fingerprint,
        matches: hits.length,
        confirmed: confirmed,
        templateId: templateId,
      );
    }
  }

  for (final raw in plan['refinements'] as List? ?? const []) {
    final item = Map<Object?, Object?>.from(raw as Map);
    final templateId = item['templateId'] as int?;
    final episodeId = item['episodeId'] as int?;
    final snapped = episodeId == null
        ? (startMs: item['startMs']! as int, endMs: item['endMs']! as int)
        : edges(episodeId, item['startMs']! as int, item['endMs']! as int);
    await database.updateFingerprintSegment(
      id: item['segmentId']! as int,
      startMs: snapped.startMs,
      endMs: snapped.endMs,
      matches: item['matches']! as int,
      templateId: templateId,
    );
    final bytes = _asBytes(item['templateBytes']);
    if (templateId != null && bytes != null && bytes.isNotEmpty) {
      await database.setTemplateLogMel(templateId, bytes);
    }
  }

  final network = await database.networkSegmentsForPodcast(podcastId);
  final touched = <int>{};
  for (final raw in plan['spans'] as List? ?? const []) {
    final span = Map<Object?, Object?>.from(raw as Map);
    final snapped = edges(
      span['episodeId']! as int,
      span['startMs']! as int,
      span['endMs']! as int,
    );
    final id = await _upsertLoose(
      database,
      episodeId: span['episodeId']! as int,
      startMs: snapped.startMs,
      endMs: snapped.endMs,
      kind: SkipSegmentKind.ad,
      source: SkipSegmentSource.network,
      matches: 1,
      confirmed: adReview,
      templateId: null,
      existing: network,
    );
    if (id != null) touched.add(id);
  }
  for (final row in network) {
    if (touched.contains(row.id) || row.confirmed == true) continue;
    await database.deleteSkipSegment(row.id);
  }

  for (final raw in plan['postAd'] as List? ?? const []) {
    final hit = Map<Object?, Object?>.from(raw as Map);
    final snapped = edges(
      hit['episodeId']! as int,
      hit['startMs']! as int,
      hit['endMs']! as int,
    );
    await _upsertLoose(
      database,
      episodeId: hit['episodeId']! as int,
      startMs: snapped.startMs,
      endMs: snapped.endMs,
      kind: SkipSegmentKind.jingle,
      source: SkipSegmentSource.network,
      matches: (plan['postAd'] as List).length,
      confirmed: null,
      templateId: null,
    );
  }

  for (final raw in plan['learned'] as List? ?? const []) {
    final sting = Map<Object?, Object?>.from(raw as Map);
    final prior = sting['priorId'] as int?;
    if (prior != null) {
      await database.touchLearnedNetworkSting(
        prior,
        episodeCount: sting['episodes']! as int,
        podcastCount: sting['podcasts']! as int,
      );
      continue;
    }
    final bytes = _asBytes(sting['bytes']);
    if (bytes == null || bytes.isEmpty) continue;
    await database.insertLearnedNetworkSting(
      logMel: bytes,
      durationMs: sting['durationMs']! as int,
      episodeCount: sting['episodes']! as int,
      podcastCount: sting['podcasts']! as int,
    );
  }
}

Uint8List? _asBytes(Object? raw) {
  if (raw == null) return null;
  if (raw is Uint8List) return raw;
  if (raw is List) return Uint8List.fromList(raw.cast<int>());
  return null;
}

bool? _adConfirmation(
  Map<int, bool?> reviews,
  List<SegmentTemplate> templates,
) {
  final ads = [
    for (final template in templates)
      if (template.kind == SkipSegmentKind.ad) reviews[template.id],
  ];
  if (ads.isEmpty) return null;
  if (ads.every((review) => review == true)) return true;
  if (ads.every((review) => review == false)) return false;
  return null;
}

Future<int?> _upsertLoose(
  AppDatabase database, {
  required int episodeId,
  required int startMs,
  required int endMs,
  required SkipSegmentKind kind,
  required SkipSegmentSource source,
  required int matches,
  required bool? confirmed,
  required int? templateId,
  List<SkipSegment> existing = const [],
}) async {
  final all = await database.listSkipSegments(episodeId);
  final manual = [
    for (final row in all)
      if (row.source == SkipSegmentSource.manual) row,
  ];
  if (overlapsManual(manual, episodeId, startMs, endMs)) return null;
  final rows = existing.isEmpty
      ? all
      : existing.where((row) => row.episodeId == episodeId);
  SkipSegment? prior;
  for (final row in rows) {
    if (row.source != source) continue;
    final sameTemplate = templateId != null && row.templateId == templateId;
    final near = (row.startMs - startMs).abs() <= stableOffsetSlackMs;
    if (sameTemplate || near) {
      prior = row;
      break;
    }
  }
  if (prior != null) {
    await database.updateFingerprintSegment(
      id: prior.id,
      startMs: startMs,
      endMs: endMs,
      matches: matches,
      templateId: templateId ?? prior.templateId,
    );
    return prior.id;
  }
  return database.insertSkipSegment(
    episodeId: episodeId,
    startMs: startMs,
    endMs: endMs,
    kind: kind,
    source: source,
    matches: matches,
    confirmed: confirmed,
    templateId: templateId,
  );
}
