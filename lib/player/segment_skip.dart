import '../data/skip_segments.dart';

/// Passage candidat au saut automatique.
class SkipCandidate {
  const SkipCandidate({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.kind,
    required this.confirmed,
  });

  final int id;
  final int startMs;
  final int endMs;
  final SkipSegmentKind kind;

  /// `null` : pas encore revu. `true` : confirmé. `false` : ignoré.
  final bool? confirmed;

  bool contains(int positionMs) {
    return positionMs >= startMs && positionMs < endMs;
  }
}

/// Saut à effectuer.
class SkipDecision {
  const SkipDecision({
    required this.segmentId,
    required this.seekToMs,
    required this.returnToMs,
  });

  final int segmentId;

  /// Fin du passage (exclusive).
  final int seekToMs;

  /// Position à restaurer si l’auditeur annule.
  final int returnToMs;
}

/// Décide s’il faut sauter un passage.
///
/// Un retour en arrière d’au moins [seekBackSlackMs] dans un segment le
/// marque dans [heldIds] : un seek manuel vers l’arrière ne doit pas
/// relancer le saut. [heldIds] est modifié.
///
/// Si plusieurs passages couvrent la position, on va à la fin la plus
/// lointaine pour ne pas retomber dans le suivant.
SkipDecision? decideSkipSegment({
  required int positionMs,
  int? previousMs,
  required bool playing,
  required bool fromDownload,
  required bool autoSkipAds,
  required Set<SkipSegmentKind> autoSkipKinds,
  required List<SkipCandidate> segments,
  required Set<int> heldIds,
  int seekBackSlackMs = 1500,
}) {
  if (!playing || !fromDownload || !autoSkipAds) return null;
  if (previousMs != null && positionMs + seekBackSlackMs < previousMs) {
    for (final segment in segments) {
      if (segment.contains(positionMs)) heldIds.add(segment.id);
    }
  }
  SkipCandidate? chosen;
  for (final segment in segments) {
    if (segment.confirmed == false) continue;
    if (!autoSkipKinds.contains(segment.kind)) continue;
    if (heldIds.contains(segment.id)) continue;
    if (segment.endMs <= segment.startMs) continue;
    if (!segment.contains(positionMs)) continue;
    if (chosen == null || segment.endMs > chosen.endMs) chosen = segment;
  }
  if (chosen == null) return null;
  return SkipDecision(
    segmentId: chosen.id,
    seekToMs: chosen.endMs,
    returnToMs: positionMs,
  );
}
