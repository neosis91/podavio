import 'dart:math' as math;
import 'dart:typed_data';

import 'chromaprint.dart';

/// Pas de l’enveloppe d’énergie gardée avec l’empreinte.
const envelopeHopMs = 20;

/// Déplacement maximum du recalage autour de la frontière Chromaprint.
const boundaryRefineSlackMs = 1500;

/// Une pub peut s’arrêter ~3 s trop tôt, sur un creux, alors que le
/// son continue jusqu’au vrai silence. On ne va pas plus loin que ça.
const adEndExtendMs = 4000;

/// En dessous, l’octet d’enveloppe est du silence (~−36 dB).
/// Un creux à −28 dB reste au-dessus et ne coupe pas la pub.
const envelopeSilenceLevel = 4;

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

/// Pousse [endMs] jusqu’au prochain silence tenu, sans dépasser
/// [maxExtendMs].
///
/// Un creux bref au point d’arrêt grossier est ignoré : il faut avoir
/// réentendu du son, puis 200 ms de silence. Si le point d’arrêt est
/// déjà dans un silence qui dure, on ne bouge pas. Sans silence dans
/// la fenêtre, la fin reste celle de l’empreinte.
int extendEndToSilence(
  Uint8List envelope,
  int endMs, {
  int maxExtendMs = adEndExtendMs,
}) {
  if (envelope.isEmpty || endMs < 0) return endMs;
  final lastMs = envelope.length * envelopeHopMs;
  final stop = endMs + maxExtendMs < lastMs ? endMs + maxExtendMs : lastMs;
  var quietFor = 0;
  var quietStart = endMs;
  var heard = false;
  for (var t = endMs; t < stop; t += envelopeHopMs) {
    final index = t ~/ envelopeHopMs;
    if (index < 0 || index >= envelope.length) break;
    if (envelope[index] > envelopeSilenceLevel) {
      heard = true;
      quietFor = 0;
      continue;
    }
    if (quietFor == 0) quietStart = t;
    quietFor += envelopeHopMs;
    if (!heard && quietFor > 400) return endMs;
    if (heard && quietFor >= 200) return quietStart;
  }
  return endMs;
}

/// Ramène [startMs] au silence tenu d’avant, sans reculer de plus de
/// [maxExtendMs].
///
/// Même règle que [extendEndToSilence] : un creux bref est ignoré, et
/// un début déjà posé dans un silence qui dure ne bouge pas.
int extendStartToSilence(
  Uint8List envelope,
  int startMs, {
  int maxExtendMs = adEndExtendMs,
}) {
  if (envelope.isEmpty || startMs <= 0) return startMs;
  final earliest = startMs - maxExtendMs > 0 ? startMs - maxExtendMs : 0;
  var quietFor = 0;
  var quietEnd = startMs;
  var heard = false;
  for (var t = startMs - envelopeHopMs; t >= earliest; t -= envelopeHopMs) {
    final index = t ~/ envelopeHopMs;
    if (index < 0 || index >= envelope.length) break;
    if (envelope[index] > envelopeSilenceLevel) {
      heard = true;
      quietFor = 0;
      continue;
    }
    if (quietFor == 0) quietEnd = t + envelopeHopMs;
    quietFor += envelopeHopMs;
    if (!heard && quietFor > 400) return startMs;
    if (heard && quietFor >= 200) return quietEnd < 0 ? 0 : quietEnd;
  }
  return startMs;
}

/// Pose le début et la fin d’une portion sur un vrai silence.
///
/// On ne fait que sortir : un bord déjà dans un silence reste en place,
/// et une fin déjà au bout du fichier n’est pas ramenée en arrière.
({int startMs, int endMs}) snapPortionToSilence(
  Uint8List envelope,
  int startMs,
  int endMs, {
  int durationMs = 0,
}) {
  if (envelope.isEmpty || endMs <= startMs) {
    return (startMs: startMs, endMs: endMs);
  }
  var start = extendStartToSilence(envelope, startMs);
  var end = endMs;
  final lastMs = envelope.length * envelopeHopMs;
  final atFileEnd =
      (durationMs > 0 && durationMs - endMs <= 500) ||
      (lastMs - endMs <= 500 && endMs <= lastMs);
  if (!atFileEnd) {
    end = extendEndToSilence(envelope, endMs);
    if (durationMs > 0 && end > durationMs) end = durationMs;
  }
  if (start < 0) start = 0;
  if (start >= end) return (startMs: startMs, endMs: endMs);
  return (startMs: start, endMs: end);
}
