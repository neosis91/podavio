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

/// Longueur proposée d’un passage créé depuis la position de lecture.
const createdSegmentDefaultMs = 30000;

/// Ce qu’il faut pour éditer un passage : l’épisode, sa durée, et
/// l’enveloppe RMS 20 ms calculée à l’analyse (pour la forme d’onde).
class SegmentEditTarget {
  const SegmentEditTarget({
    required this.segment,
    required this.entry,
    required this.durationMs,
    this.envelope,
  });

  /// `null` pour un passage pas encore créé.
  final SkipSegment? segment;
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
  return _loadTarget(database, segment.episodeId, segment);
}

/// Cible d’un passage à créer dans [episodeId].
Future<SegmentEditTarget?> loadSegmentCreate(
  AppDatabase database,
  int episodeId,
) {
  return _loadTarget(database, episodeId, null);
}

Future<SegmentEditTarget?> _loadTarget(
  AppDatabase database,
  int episodeId,
  SkipSegment? segment,
) async {
  final entry = await database.getEpisode(episodeId);
  if (entry == null) return null;
  final envelope = await database.envelopeForEpisode(episodeId);
  final fromEnvelope = envelope == null ? 0 : envelope.length * envelopeHopMs;
  final declared = (entry.episode.durationSeconds ?? 0) * 1000;
  return SegmentEditTarget(
    segment: segment,
    entry: entry,
    durationMs: math.max(math.max(declared, fromEnvelope), segment?.endMs ?? 0),
    envelope: envelope,
  );
}

/// Bornes de départ d’un passage créé à [positionMs] : de là, sur
/// [createdSegmentDefaultMs], dans l’épisode.
({int startMs, int endMs}) initialCreatedBounds(
  int positionMs, {
  required int durationMs,
}) {
  return clampBounds(
    positionMs,
    positionMs + createdSegmentDefaultMs,
    durationMs: durationMs,
  );
}

/// Passage posé à la main qui recouvre [startMs]–[endMs], même en partie.
/// Deux passages manuels ne se chevauchent pas : on corrige l’existant.
SkipSegment? manualOverlap(
  List<SkipSegment> rows,
  int startMs,
  int endMs, {
  int? exceptId,
}) {
  for (final row in rows) {
    if (!sourceIsProtected(row.source) || row.id == exceptId) continue;
    if (math.min(endMs, row.endMs) > math.max(startMs, row.startMs)) {
      return row;
    }
  }
  return null;
}

/// Passages détectés (empreinte, virgule) que le passage posé à la main
/// remplace : ceux qu’il couvre au moins pour moitié du plus court, la règle
/// qui empêche ensuite l’analyse de les recréer. Les chapitres du flux
/// restent ; un chevauchement plus faible aussi, le saut enchaîne les deux.
List<SkipSegment> replacedByManual(
  List<SkipSegment> rows,
  int startMs,
  int endMs,
) {
  final length = endMs - startMs;
  return [
    for (final row in rows)
      if (row.source == SkipSegmentSource.fingerprint ||
          row.source == SkipSegmentSource.network)
        if (_halfCovered(row, startMs, endMs, length)) row,
  ];
}

bool _halfCovered(SkipSegment row, int startMs, int endMs, int length) {
  final overlap = math.min(endMs, row.endMs) - math.max(startMs, row.startMs);
  final shorter = math.min(length, row.endMs - row.startMs);
  return overlap > 0 && overlap * 2 >= shorter;
}

/// Issue de [createManualSegment] : l’id créé, ou le passage manuel qui
/// occupe déjà la place.
typedef CreatedSegment = ({int? segmentId, SkipSegment? overlap});

/// Crée un passage à la main dans [episodeId] :
/// 1. empreinte Chromaprint de référence coupée dans celle de l’épisode,
///    en nouveau gabarit (nommé [label]) que l’analyse cherche dans les
///    autres épisodes ; sans empreinte encore, le gabarit attend l’analyse ;
/// 2. passage `manual`, qu’une analyse ne réécrit pas ; les
///    passages détectés qu’il recouvre sont retirés ;
/// 3. vérité terrain sans bornes détectées.
Future<CreatedSegment> createManualSegment(
  AppDatabase database, {
  required int episodeId,
  required int startMs,
  required int endMs,
  required SkipSegmentKind kind,
  String? label,
}) async {
  final entry = await database.getEpisode(episodeId);
  if (entry == null) return (segmentId: null, overlap: null);
  final print = await database.fingerprintForEpisode(episodeId);
  final slice = print == null
      ? null
      : sliceChromaprint(
          print.data,
          print.hopMicros,
          startMs: startMs,
          endMs: endMs,
        );
  final name = label?.trim() ?? '';
  return database.transaction(() async {
    final rows = await database.listSkipSegments(episodeId);
    final overlap = manualOverlap(rows, startMs, endMs);
    if (overlap != null) return (segmentId: null, overlap: overlap);
    for (final row in replacedByManual(rows, startMs, endMs)) {
      await database.deleteSkipSegment(row.id);
    }
    final templateId = await database.insertSegmentTemplate(
      podcastId: entry.episode.podcastId,
      kind: kind,
      label: name.isEmpty ? null : name,
      fingerprint: slice,
      durationMs: endMs - startMs,
      occurrences: 1,
    );
    final segmentId = await database.insertSkipSegment(
      episodeId: episodeId,
      startMs: startMs,
      endMs: endMs,
      kind: kind,
      source: SkipSegmentSource.manual,
      templateId: templateId,
    );
    await database.insertSegmentAnnotation(
      segmentId: segmentId,
      episodeId: episodeId,
      kind: kind,
      correctedStartMs: startMs,
      correctedEndMs: endMs,
    );
    return (segmentId: segmentId, overlap: null);
  });
}

/// Supprime un passage posé à la main. S’il a été créé à la main, son
/// gabarit part avec lui, et les passages retrouvés grâce à lui dans les
/// autres épisodes aussi, sauf si un autre passage manuel s’y rattache.
/// La vérité terrain reste.
Future<void> deleteManualSegment(AppDatabase database, int segmentId) async {
  final segment = await database.skipSegmentById(segmentId);
  if (segment == null) return;
  final created = await database.isCreatedSegment(segmentId);
  await database.transaction(() async {
    await database.dismissSkipSegment(segmentId);
    final templateId = segment.templateId;
    if (!created || templateId == null) return;
    final left = await database.segmentsForTemplate(templateId);
    if (left.any((row) => sourceIsProtected(row.source))) return;
    await database.deleteSegmentTemplate(templateId);
  });
}

/// Enregistre des bornes corrigées à la main :
/// 1. retaille l’empreinte Chromaprint de référence (le gabarit du passage,
///    créé au besoin) dans l’empreinte stockée de l’épisode ;
/// 2. passe le passage en `manual`, qu’une analyse ne réécrit plus ;
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
