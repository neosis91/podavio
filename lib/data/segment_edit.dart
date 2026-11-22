import 'dart:math' as math;
import 'dart:typed_data';

import 'app_database.dart';
import 'envelope.dart';
import 'skip_segments.dart';

/// Pas des boutons ±0,5 s de l’éditeur de bornes.
const boundaryStepMs = 500;

/// Passage le plus court qu’on accepte à l’enregistrement.
const minEditedSegmentMs = 1000;

/// Écoute autour d’une coupe : de 2 s avant à 2 s après.
const cutPreviewMs = 2000;

/// Bornes ramenées dans l’épisode, avec au moins [minEditedSegmentMs].
({int startMs, int endMs}) clampBounds(
  int startMs,
  int endMs, {
  required int durationMs,
}) {
  final limit = math.max(durationMs, minEditedSegmentMs);
  final start = math.min(math.max(0, startMs), limit - minEditedSegmentMs);
  final end = math.min(math.max(endMs, start + minEditedSegmentMs), limit);
  return (startMs: start, endMs: end);
}

/// Valeurs Chromaprint de l’épisode entre [startMs] et [endMs], ou `null`
/// si l’empreinte manque ou couvre moins de 8 points (~1 s).
Uint8List? sliceChromaprint(
  Uint8List episodePrint,
  int hopMicros, {
  required int startMs,
  required int endMs,
}) {
  if (!isChromaprintPrint(episodePrint) || hopMicros <= 0) return null;
  final values = decodeFingerprint(episodePrint);
  final from = (startMs * 1000 / hopMicros).floor().clamp(0, values.length);
  final to = (endMs * 1000 / hopMicros).ceil().clamp(from, values.length);
  if (to - from < 8) return null;
  return encodeFingerprint(values.sublist(from, to));
}

/// Ce qu’il faut pour éditer un passage : l’épisode, sa durée, et
/// l’enveloppe RMS 20 ms calculée à l’analyse (pour la forme d’onde).
class SegmentEditTarget {
  const SegmentEditTarget({
    required this.segment,
    required this.entry,
    required this.durationMs,
    this.envelope,
  });

  final SkipSegment segment;
  final EpisodeEntry entry;
  final int durationMs;

  /// Une valeur par 20 ms, 0–255. `null` si l’épisode n’a pas été analysé.
  final Uint8List? envelope;
}

Future<SegmentEditTarget?> loadSegmentEdit(
  AppDatabase database,
  int segmentId,
) async {
  final segment = await database.skipSegmentById(segmentId);
  if (segment == null) return null;
  final entry = await database.getEpisode(segment.episodeId);
  if (entry == null) return null;
  final envelope = await database.envelopeForEpisode(segment.episodeId);
  final fromEnvelope = envelope == null ? 0 : envelope.length * envelopeHopMs;
  final declared = (entry.episode.durationSeconds ?? 0) * 1000;
  return SegmentEditTarget(
    segment: segment,
    entry: entry,
    durationMs: math.max(math.max(declared, fromEnvelope), segment.endMs),
    envelope: envelope,
  );
}

/// Enregistre des bornes corrigées à la main :
/// 1. retaille l’empreinte Chromaprint de référence (le gabarit du passage,
///    créé au besoin) dans l’empreinte stockée de l’épisode ;
/// 2. passe le passage en `manual` et confirmé, qu’une analyse ne réécrit
///    plus ;
/// 3. garde bornes détectées et corrigées comme vérité terrain locale.
Future<void> saveSegmentBounds(
  AppDatabase database, {
  required int segmentId,
  required int startMs,
  required int endMs,
}) async {
  final segment = await database.skipSegmentById(segmentId);
  if (segment == null) return;
  final entry = await database.getEpisode(segment.episodeId);
  if (entry == null) return;
  final print = await database.fingerprintForEpisode(segment.episodeId);
  final slice = print == null
      ? null
      : sliceChromaprint(
          print.data,
          print.hopMicros,
          startMs: startMs,
          endMs: endMs,
        );
  await database.transaction(() async {
    var templateId = segment.templateId;
    if (slice != null) {
      if (templateId != null) {
        await database.setSegmentTemplateFingerprint(
          templateId,
          slice,
          durationMs: endMs - startMs,
        );
      } else {
        templateId = await database.insertSegmentTemplate(
          podcastId: entry.episode.podcastId,
          kind: segment.kind,
          fingerprint: slice,
          durationMs: endMs - startMs,
          occurrences: 1,
        );
      }
    }
    await database.setManualSegmentBounds(
      segmentId,
      startMs: startMs,
      endMs: endMs,
      templateId: templateId,
    );
    await database.insertSegmentAnnotation(
      segmentId: segmentId,
      episodeId: segment.episodeId,
      kind: segment.kind,
      detectedSource: segment.source,
      detectedStartMs: segment.startMs,
      detectedEndMs: segment.endMs,
      correctedStartMs: startMs,
      correctedEndMs: endMs,
    );
  });
}

/// Une colonne de forme d’onde : crête et moyenne RMS, 0–1 en échelle dB
/// (−48 dB à 0 dB), pour qu’un passage calme reste visible.
typedef WaveColumn = ({double peak, double rms});

/// Réduit l’enveloppe 20 ms entre [startMs] et [endMs] à [columns]
/// colonnes. Hors de l’enveloppe, la colonne vaut zéro.
List<WaveColumn> waveformColumns(
  Uint8List envelope, {
  required int startMs,
  required int endMs,
  required int columns,
}) {
  if (columns <= 0 || endMs <= startMs) return const [];
  final span = (endMs - startMs) / columns;
  final out = <WaveColumn>[];
  for (var c = 0; c < columns; c++) {
    final from = ((startMs + c * span) / envelopeHopMs).floor();
    final to = math.max(
      from + 1,
      ((startMs + (c + 1) * span) / envelopeHopMs).ceil(),
    );
    var peak = 0;
    var sum = 0.0;
    var count = 0;
    for (var i = math.max(0, from); i < math.min(to, envelope.length); i++) {
      final value = envelope[i];
      if (value > peak) peak = value;
      sum += value * value;
      count++;
    }
    if (count == 0) {
      out.add((peak: 0.0, rms: 0.0));
      continue;
    }
    out.add((peak: _toDb(peak.toDouble()), rms: _toDb(math.sqrt(sum / count))));
  }
  return out;
}

double _toDb(double byte) {
  if (byte <= 0) return 0;
  final db = 20 * math.log(byte / 255) / math.ln10;
  return ((db + 48) / 48).clamp(0.0, 1.0);
}
