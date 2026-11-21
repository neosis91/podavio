import 'dart:math' as math;
import 'dart:typed_data';

import 'chromaprint.dart';

/// Pas de l’enveloppe d’énergie gardée avec l’empreinte.
const envelopeHopMs = 20;

/// Déplacement maximum du recalage autour de la frontière Chromaprint.
const boundaryRefineSlackMs = 1500;

const envelopeHopSamples = chromaprintSampleRate * envelopeHopMs ~/ 1000;

/// Énergie RMS quantifiée, un octet toutes les [envelopeHopMs].
///
/// Sert à recaler le début et la fin d’un passage déjà trouvé, sans
/// garder le PCM. Une heure tient en 180 ko.
class EnergyEnvelopeBuilder {
  EnergyEnvelopeBuilder() : _out = BytesBuilder(copy: false);

  final BytesBuilder _out;
  var _sum = 0.0;
  var _count = 0;

  int get retainedBytes => _out.length + 16;

  void add(Int16List samples) {
    for (var i = 0; i < samples.length; i++) {
      final value = samples[i].toDouble();
      _sum += value * value;
      _count++;
      if (_count == envelopeHopSamples) _emit();
    }
  }

  void _emit() {
    final rms = math.sqrt(_sum / envelopeHopSamples) / 32768.0;
    _out.addByte((rms * 255).round().clamp(0, 255));
    _sum = 0;
    _count = 0;
  }

  Uint8List finish() => _out.takeBytes();
}

/// Décalage à ajouter au début et à la fin grossiers, en millisecondes.
class EnvelopeShift {
  const EnvelopeShift({required this.startMs, required this.endMs});

  final int startMs;
  final int endMs;
}

/// Pose les frontières sur la transition de similarité des enveloppes.
///
/// Les deux passages sont déjà alignés par Chromaprint. On cherche, dans
/// ±[boundaryRefineSlackMs], l’endroit où les enveloppes commencent et
/// cessent de se correspondre. `null` si le contraste est trop faible :
/// on garde alors la frontière grossière.
EnvelopeShift? envelopeEdgeShift({
  required Uint8List anchor,
  required Uint8List other,
  required int anchorStartMs,
  required int anchorEndMs,
  required int otherStartMs,
  required int otherEndMs,
  int slackMs = boundaryRefineSlackMs,
}) {
  if (anchor.isEmpty || other.isEmpty) return null;
  final span = anchorEndMs - anchorStartMs;
  if (span < envelopeHopMs * 8) return null;
  final deltaMs = anchorStartMs - otherStartMs;

  double sim(int anchorMs) {
    final ia = anchorMs ~/ envelopeHopMs;
    final ib = (anchorMs - deltaMs) ~/ envelopeHopMs;
    if (ia < 0 || ib < 0 || ia >= anchor.length || ib >= other.length) {
      return 0;
    }
    return 1 - (anchor[ia] - other[ib]).abs() / 255.0;
  }

  final inner = <double>[];
  final innerFrom = anchorStartMs + span ~/ 5;
  final innerTo = anchorEndMs - span ~/ 5;
  for (var t = innerFrom; t < innerTo; t += envelopeHopMs) {
    inner.add(sim(t));
  }
  final outer = <double>[];
  final outerStop = anchorStartMs - 200;
  for (var t = anchorStartMs - slackMs; t < outerStop; t += envelopeHopMs) {
    outer.add(sim(t));
  }
  if (inner.length < 4 || outer.length < 4) return null;
  final innerMed = _median(inner);
  final outerMed = _median(outer);
  if (innerMed - outerMed < 0.12) return null;
  final gate = (innerMed + outerMed) / 2;
  const holdNeed = 150 ~/ envelopeHopMs;

  int? rising;
  var hold = 0;
  final riseStop = math.min(anchorStartMs + slackMs, anchorEndMs);
  for (var t = anchorStartMs - slackMs; t < riseStop; t += envelopeHopMs) {
    if (sim(t) >= gate) {
      hold++;
      if (hold >= holdNeed) {
        rising = t - (holdNeed - 1) * envelopeHopMs;
        break;
      }
    } else {
      hold = 0;
    }
  }

  int? falling;
  hold = 0;
  final fallStart = anchorEndMs + slackMs;
  final fallStop = math.max(anchorEndMs - slackMs, anchorStartMs);
  for (var t = fallStart; t > fallStop; t -= envelopeHopMs) {
    if (sim(t) >= gate) {
      hold++;
      if (hold >= holdNeed) {
        falling = t + holdNeed * envelopeHopMs;
        break;
      }
    } else {
      hold = 0;
    }
  }
  if (rising == null || falling == null || falling - rising < span ~/ 2) {
    return null;
  }
  final startShift = rising - anchorStartMs;
  final endShift = falling - anchorEndMs;
  if (startShift.abs() > slackMs || endShift.abs() > slackMs) return null;
  return EnvelopeShift(startMs: startShift, endMs: endShift);
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}
