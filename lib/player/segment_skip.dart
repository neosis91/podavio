import '../data/skip_segments.dart';

/// Passage candidat au saut automatique.
class SkipCandidate {
  const SkipCandidate({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.kind,
    this.networkSting = false,
  });

  final int id;
  final int startMs;
  final int endMs;
  final SkipSegmentKind kind;

  /// Virgule de réseau. Elle se saute avec les pubs, même séparée d’un silence.
  final bool networkSting;

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
    if (!_skipsWithAds(segment, autoSkipKinds)) continue;
    if (heldIds.contains(segment.id)) continue;
    if (segment.endMs <= segment.startMs) continue;
    if (!segment.contains(positionMs)) continue;
    if (chosen == null || segment.endMs > chosen.endMs) chosen = segment;
  }
  if (chosen == null) return null;
  return SkipDecision(
    segmentId: chosen.id,
    seekToMs: _contiguousSkipEnd(chosen, segments, autoSkipKinds),
    returnToMs: positionMs,
  );
}

bool _skipsWithAds(SkipCandidate segment, Set<SkipSegmentKind> kinds) {
  if (kinds.contains(segment.kind)) return true;
  return segment.networkSting && kinds.contains(SkipSegmentKind.ad);
}

/// Jingle ou virgule posée à la main, collée à une pub.
bool _gluedSting(SkipSegmentKind kind) {
  return kind == SkipSegmentKind.jingle || kind == SkipSegmentKind.sting;
}

/// Une pub et la virgule collée juste après forment un seul saut.
/// Les chapitres, eux, restent deux passages.
int _contiguousSkipEnd(
  SkipCandidate chosen,
  List<SkipCandidate> segments,
  Set<SkipSegmentKind> kinds,
) {
  var end = chosen.endMs;
  var glueSting = chosen.kind == SkipSegmentKind.ad;
  for (var guard = 0; guard < 8; guard++) {
    SkipCandidate? next;
    for (final segment in segments) {
      if (segment.endMs <= end) continue;
      if (segment.startMs > end + 500) continue;
      final enabled = kinds.contains(segment.kind);
      final stingAfterAd = glueSting && _gluedSting(segment.kind);
      if (!enabled && !stingAfterAd) continue;
      if (next == null || segment.endMs > next.endMs) next = segment;
    }
    if (next == null) break;
    end = next.endMs;
    if (next.kind == SkipSegmentKind.ad) glueSting = true;
  }
  return end;
}

/// Bouton du grand lecteur : un passage présent, mais pas sauté tout seul.
class SkipOffer {
  const SkipOffer({
    required this.segmentId,
    required this.kind,
    required this.seekToMs,
  });

  final int segmentId;
  final SkipSegmentKind kind;
  final int seekToMs;

  @override
  bool operator ==(Object other) {
    return other is SkipOffer &&
        other.segmentId == segmentId &&
        other.kind == kind &&
        other.seekToMs == seekToMs;
  }

  @override
  int get hashCode => Object.hash(segmentId, kind, seekToMs);
}

/// Passage à proposer quand le saut automatique ne le couvre pas.
///
/// Si un passage couvrant la position est configuré pour le saut
/// automatique, rien n’est proposé : ce saut part tout seul.
SkipOffer? manualSkipOffer({
  required int positionMs,
  required bool autoSkipAds,
  required Set<SkipSegmentKind> autoSkipKinds,
  required List<SkipCandidate> segments,
}) {
  var coveredByAuto = false;
  SkipCandidate? chosen;
  for (final segment in segments) {
    if (segment.endMs <= segment.startMs) continue;
    if (!segment.contains(positionMs)) continue;
    if (autoSkipAds && _skipsWithAds(segment, autoSkipKinds)) {
      coveredByAuto = true;
      continue;
    }
    if (chosen == null || segment.endMs > chosen.endMs) chosen = segment;
  }
  if (coveredByAuto || chosen == null) return null;
  return SkipOffer(
    segmentId: chosen.id,
    kind: chosen.kind,
    seekToMs: chosen.endMs,
  );
}
