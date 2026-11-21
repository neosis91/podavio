import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'chromaprint.dart';
import 'episode_audio_analyzer.dart';
import 'log_mel.dart';
import 'log_mel_match.dart';
import 'network_stings.dart';
import 'pcm_decoder.dart';
import 'providers.dart';
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

/// File d’analyse. Une empreinte à la fois, pour ne pas figer l’interface.
final audioAnalysisProvider =
    NotifierProvider<AudioAnalysisController, AudioAnalysisProgress>(
      AudioAnalysisController.new,
    );

/// Au démarrage : épisodes déjà téléchargés, encore sans empreinte.
final audioAnalysisBootstrapProvider = Provider<void>((ref) {
  if (ref.watch(databasePhaseProvider) != DatabasePhase.open) return;
  unawaited(ref.read(audioAnalysisProvider.notifier).enqueueMissing());
});

/// À l’ouverture de l’écran de classement, pour ce podcast.
final podcastAnalysisKickProvider = Provider.family<void, int>((
  ref,
  podcastId,
) {
  if (ref.watch(databasePhaseProvider) != DatabasePhase.open) return;
  unawaited(
    ref
        .read(audioAnalysisProvider.notifier)
        .enqueueMissing(podcastId: podcastId),
  );
});

class AudioAnalysisProgress {
  const AudioAnalysisProgress({
    this.runningEpisodeId,
    this.runningPodcastId,
    this.pending = const [],
  });

  final int? runningEpisodeId;
  final int? runningPodcastId;
  final List<({int episodeId, int podcastId})> pending;

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
  _Job({required this.episodeId, required this.podcastId, required this.force});

  final int episodeId;
  final int podcastId;
  final bool force;
  final done = Completer<void>();
}

class AudioAnalysisController extends Notifier<AudioAnalysisProgress> {
  final _wait = <_Job>[];
  Future<void>? _pumpFuture;

  @override
  AudioAnalysisProgress build() => const AudioAnalysisProgress();

  /// [force] recalcule l’empreinte. C’est le cas juste après un téléchargement.
  Future<void> enqueueEpisode(int episodeId, {bool force = false}) async {
    try {
      if (!ref.mounted) return;
      final episode = await ref.read(databaseProvider).episodeById(episodeId);
      if (!ref.mounted || episode == null) return;
      final path = episode.downloadPath?.trim() ?? '';
      if (path.isEmpty) return;
      final queued = _wait.any((job) => job.episodeId == episodeId);
      if (queued || state.runningEpisodeId == episodeId) {
        if (force) {
          _wait.removeWhere((job) => job.episodeId == episodeId);
        } else {
          return;
        }
      }
      final job = _Job(
        episodeId: episode.id,
        podcastId: episode.podcastId,
        force: force,
      );
      _wait.add(job);
      _publish();
      unawaited(_ensurePump());
      await job.done.future;
    } catch (error, stack) {
      debugPrint('Analyse audio: $error\n$stack');
    }
  }

  Future<void> enqueueMissing({int? podcastId}) async {
    try {
      if (!ref.mounted) return;
      final rows = await ref
          .read(databaseProvider)
          .downloadedEpisodesMissingFingerprint(podcastId: podcastId);
      if (!ref.mounted) return;
      for (final row in rows) {
        await enqueueEpisode(row.id);
        if (!ref.mounted) return;
      }
    } catch (error, stack) {
      debugPrint('Analyse audio: $error\n$stack');
    }
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
        if (stored == null ||
            stored.data.isEmpty ||
            stored.speech == null ||
            mel == null) {
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

  void _publish() {
    if (!ref.mounted) return;
    state = AudioAnalysisProgress(
      runningEpisodeId: state.runningEpisodeId,
      runningPodcastId: state.runningPodcastId,
      pending: [
        for (final job in _wait)
          (episodeId: job.episodeId, podcastId: job.podcastId),
      ],
    );
  }

  Future<void> _ensurePump() {
    return _pumpFuture ??= _run();
  }

  Future<void> _run() async {
    try {
      while (_wait.isNotEmpty && ref.mounted) {
        final job = _wait.removeAt(0);
        state = AudioAnalysisProgress(
          runningEpisodeId: job.episodeId,
          runningPodcastId: job.podcastId,
          pending: [
            for (final waiting in _wait)
              (episodeId: waiting.episodeId, podcastId: waiting.podcastId),
          ],
        );
        try {
          await _analyze(job);
        } catch (error, stack) {
          debugPrint('Analyse audio: $error\n$stack');
        } finally {
          if (!job.done.isCompleted) job.done.complete();
        }
      }
    } finally {
      _pumpFuture = null;
      if (ref.mounted) {
        state = AudioAnalysisProgress(
          pending: [
            for (final waiting in _wait)
              (episodeId: waiting.episodeId, podcastId: waiting.podcastId),
          ],
        );
      }
      if (_wait.isNotEmpty && ref.mounted) {
        unawaited(_ensurePump());
      }
    }
  }

  Future<void> _analyze(_Job job) async {
    if (!ref.mounted) return;
    final database = ref.read(databaseProvider);
    final episode = await database.episodeById(job.episodeId);
    if (!ref.mounted || episode == null) return;
    final path = episode.downloadPath?.trim() ?? '';
    if (path.isEmpty) return;
    final existing = job.force
        ? null
        : await database.fingerprintForEpisode(episode.id);
    final mel = job.force ? null : await database.logMelForEpisode(episode.id);
    final needPrint = existing == null || existing.data.isEmpty;
    final needSpeech = existing == null || existing.speech == null;
    if (needPrint || mel == null || needSpeech) {
      final watch = Stopwatch()..start();
      final analyzed = await _analyzeDecoded(
        ref.read(pcmDecoderProvider),
        path,
      );
      if (!ref.mounted) return;
      if (analyzed == null) {
        debugPrint(
          'Analyse audio: pas d’empreinte pour l’épisode ${episode.id}.',
        );
        return;
      }
      debugPrint(
        'Analyse audio: épisode ${episode.id}, '
        '${analyzed.fingerprint.length} valeurs, '
        '${watch.elapsedMilliseconds} ms.',
      );
      if (needPrint || job.force || needSpeech) {
        await database.upsertEpisodeFingerprint(
          episodeId: episode.id,
          data: encodeFingerprint(analyzed.fingerprint),
          hopMicros: chromaprintStoredHopMicros,
          speech: analyzed.speech,
        );
      }
      if (analyzed.logMel != null) {
        await database.upsertEpisodeLogMel(
          episodeId: episode.id,
          data: analyzed.logMel!,
        );
      }
    }
    if (!ref.mounted) return;
    final match = Stopwatch()..start();
    await syncPodcastAnalysis(database, episode.podcastId);
    debugPrint(
      'Analyse audio: podcast ${episode.podcastId}, '
      'rapprochement ${match.elapsedMilliseconds} ms.',
    );
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

Future<({List<int> fingerprint, Uint8List? logMel, Uint8List speech})?>
_analyzeDecoded(PcmDecoder decoder, String path) async {
  final decoded = await decoder.decode(path);
  if (decoded == null) return null;
  try {
    if (decoded.sampleRate != chromaprintSampleRate) {
      debugPrint(
        'Décodage audio: ${decoded.sampleRate} Hz au lieu de $chromaprintSampleRate.',
      );
      return null;
    }
    return await Isolate.run(() => analyzePcmFileSync(decoded.path));
  } finally {
    await _deleteDecoded(decoded.path);
  }
}

Future<void> _deleteDecoded(String path) async {
  if (!path.contains('podavio-pcm-')) return;
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

/// Recharge les empreintes du podcast et réécrit les passages.
///
/// Un second appel avec les mêmes empreintes ne duplique pas les lignes
/// et ne revient pas sur un avis déjà posé.
Future<void> syncPodcastAnalysis(AppDatabase database, int podcastId) async {
  final stored = await database.fingerprintedDownloads(podcastId);
  final episodes = <FingerprintEpisode>[];
  for (final row in stored) {
    final values = decodeFingerprint(row.fingerprint.data);
    if (values.length < 8) continue;
    final fromFingerprint = _indexMs(values.length, row.fingerprint.hopMicros);
    final fromRss = (row.episode.durationSeconds ?? 0) * 1000;
    final durationMs = fromFingerprint > fromRss ? fromFingerprint : fromRss;
    final preRoll = approximateInsertedAdMs(
      rssDurationMs: fromRss > 0 ? fromRss : null,
      fileDurationMs: fromFingerprint,
    );
    episodes.add(
      FingerprintEpisode(
        episodeId: row.episode.id,
        values: values,
        hopMicros: row.fingerprint.hopMicros,
        durationMs: durationMs,
        preRollEndMs: preRoll,
        speech: row.fingerprint.speech,
      ),
    );
  }
  final known = <KnownTemplate>[];
  final reviews = await database.templateReviews(podcastId);
  for (final template in await database.listSegmentTemplates(podcastId)) {
    known.add(
      KnownTemplate(
        id: template.id,
        kind: template.kind,
        fingerprint: decodeFingerprint(template.fingerprint),
        durationMs: template.durationMs,
        confirmed: reviews[template.id],
        confidence: template.confidence,
      ),
    );
  }
  final message = encodeAnalysisInput(episodes: episodes, templates: known);
  final raw = await Isolate.run(() => planAnalysisMessage(message));
  final plan = decodeAnalysisPlan(Map<Object?, Object?>.from(raw));
  await applyAnalysisPlan(database, podcastId, plan);
  await applyLogMelFindings(database, podcastId);
}

int _indexMs(int index, int hopMicros) {
  if (index <= 0 || hopMicros <= 0) return 0;
  return index * hopMicros ~/ 1000;
}

/// Écrit [plan] sans doublon. Un passage déjà revu garde son avis et son type.
Future<void> applyAnalysisPlan(
  AppDatabase database,
  int podcastId,
  AnalysisPlan plan,
) async {
  final existing = await database.fingerprintSegmentsForPodcast(podcastId);
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
      if (row.templateId != null && keptForLogMel.contains(row.templateId)) {
        continue;
      }
      await database.deleteSkipSegment(row.id);
    }
    await _recountTemplates(database, podcastId);
  });
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
Future<void> applyLogMelFindings(AppDatabase database, int podcastId) async {
  final stored = await database.logMelForPodcast(podcastId);
  if (stored.isEmpty) return;
  final episodes = <EpisodeMel>[];
  for (final row in stored) {
    final episode = await database.episodeById(row.episodeId);
    if (episode == null) continue;
    episodes.add(
      EpisodeMel(
        episodeId: row.episodeId,
        podcastId: podcastId,
        clip: _clip(row.data),
        durationMs: (episode.durationSeconds ?? 0) * 1000,
        preRollEndMs: null,
      ),
    );
  }
  if (episodes.isEmpty) return;
  final templates = await database.listSegmentTemplates(podcastId);
  final reviews = await database.templateReviews(podcastId);
  final bundled = await loadBundledNetworkStings();
  final learned = await database.listLearnedNetworkStings();
  final stings = [
    ...bundled,
    for (final sting in learned)
      NamedLogMel(
        name: sting.name ?? 'Network sting',
        clip: _clip(sting.logMel),
      ),
  ];
  final adReview = _adConfirmation(reviews, templates);

  final jingles = discoverShortJingles(episodes);
  for (final jingle in jingles) {
    final bytes = encodeLogMel(jingle.clip.frames.cast<List<double>>());
    final existingId = _knownLogMel(jingle.clip, templates);
    final templateId =
        existingId ??
        await database.insertSegmentTemplate(
          podcastId: podcastId,
          kind: SkipSegmentKind.jingle,
          logMel: bytes,
          durationMs: jingle.clip.durationMs,
          occurrences: jingle.hits.length,
        );
    if (existingId != null &&
        templates.every(
          (template) => template.id != existingId || template.logMel == null,
        )) {
      await database.setTemplateLogMel(existingId, bytes);
    }
    final confirmed = reviews[templateId];
    for (final hit in jingle.hits) {
      await _upsertLoose(
        database,
        episodeId: hit.episodeId,
        startMs: hit.startMs,
        endMs: hit.endMs,
        kind: SkipSegmentKind.jingle,
        source: SkipSegmentSource.fingerprint,
        matches: jingle.hits.length,
        confirmed: confirmed,
        templateId: templateId,
      );
    }
  }

  final fingerprintSegments = await database.fingerprintSegmentsForPodcast(
    podcastId,
  );
  for (final segment in fingerprintSegments) {
    if (segment.endMs - segment.startMs < jingleMinDurationMs) continue;
    if (segment.startMs > logMelSearchWindowMs) continue;
    final episode = episodes
        .where((item) => item.episodeId == segment.episodeId)
        .firstOrNull;
    if (episode == null) continue;
    final refined = refineLogMelBoundary(
      episode: episode.clip,
      roughStartMs: segment.startMs,
      roughEndMs: segment.endMs,
    );
    if (refined == null) continue;
    await database.updateFingerprintSegment(
      id: segment.id,
      startMs: refined.startMs,
      endMs: refined.endMs,
      matches: segment.matches,
      templateId: segment.templateId,
    );
    final templateId = segment.templateId;
    if (templateId == null) continue;
    final template = templates
        .where((item) => item.id == templateId)
        .firstOrNull;
    if (template != null && template.logMel == null) {
      final slice = sliceLogMel(episode.clip, refined.startMs, refined.endMs);
      if (slice.frames.length >= 8) {
        await database.setTemplateLogMel(
          templateId,
          encodeLogMel(slice.frames.cast<List<double>>()),
        );
      }
    }
  }

  final network = await database.networkSegmentsForPodcast(podcastId);
  final touched = <int>{};
  for (final episode in episodes) {
    for (final span in stingDelimitedSpans(episode: episode, stings: stings)) {
      final id = await _upsertLoose(
        database,
        episodeId: span.episodeId,
        startMs: span.startMs,
        endMs: span.endMs,
        kind: SkipSegmentKind.ad,
        source: SkipSegmentSource.network,
        matches: 1,
        confirmed: adReview,
        templateId: null,
        existing: network,
      );
      if (id != null) touched.add(id);
    }
  }
  for (final row in network) {
    if (touched.contains(row.id) || row.confirmed == true) continue;
    await database.deleteSkipSegment(row.id);
  }

  await _refreshLearnedStings(database);
}

Future<void> _refreshLearnedStings(AppDatabase database) async {
  final rows = await database.dynamicAdBoundaries();
  final slices = <EpisodeMelBoundary>[];
  for (final row in rows) {
    final clip = sliceLogMel(_clip(row.data), row.endMs - 1300, row.endMs);
    if (clip.frames.length < 8) continue;
    slices.add(
      EpisodeMelBoundary(
        podcastId: row.podcastId,
        episodeId: row.episodeId,
        clip: clip,
      ),
    );
  }
  final learned = learnNetworkStings(slices);
  final existing = await database.listLearnedNetworkStings();
  for (final sting in learned) {
    LearnedNetworkSting? prior;
    for (final row in existing) {
      final score = searchLogMel(
        sting.clip,
        _clip(row.logMel),
        threshold: networkStingLearnThreshold,
      );
      if (score.isNotEmpty) {
        prior = row;
        break;
      }
    }
    if (prior != null) {
      await database.touchLearnedNetworkSting(
        prior.id,
        episodeCount: sting.episodes,
        podcastCount: sting.podcasts,
      );
      continue;
    }
    await database.insertLearnedNetworkSting(
      logMel: encodeLogMel(sting.clip.frames.cast<List<double>>()),
      durationMs: sting.clip.durationMs,
      episodeCount: sting.episodes,
      podcastCount: sting.podcasts,
    );
  }
}

LogMelClip _clip(Uint8List data) {
  return LogMelClip([
    for (final frame in decodeLogMel(data)) Float64List.fromList(frame),
  ]);
}

int? _knownLogMel(LogMelClip clip, List<SegmentTemplate> templates) {
  for (final template in templates) {
    final bytes = template.logMel;
    if (bytes == null || bytes.isEmpty) continue;
    final known = _clip(bytes);
    if (searchLogMel(clip, known, threshold: 0.95).isNotEmpty ||
        searchLogMel(known, clip, threshold: 0.95).isNotEmpty) {
      return template.id;
    }
  }
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
  final rows = existing.isEmpty
      ? await database.listSkipSegments(episodeId)
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
