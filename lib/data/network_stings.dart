import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'log_mel.dart';
import 'log_mel_match.dart';
import 'segment_match.dart';

/// Gabarits livrés dans `assets/stings`. Un fichier manquant est ignoré :
/// la virgule Acast n’est pas dans le dépôt, elle s’apprend sur l’appareil.
Future<List<NamedLogMel>> loadBundledNetworkStings() async {
  try {
    final raw = await rootBundle.loadString('assets/stings/manifest.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['stings'] is! List) return const [];
    final stings = <NamedLogMel>[];
    for (final item in decoded['stings'] as List) {
      if (item is! Map) continue;
      final name = item['name'];
      final file = item['file'];
      if (name is! String || file is! String || file.isEmpty) continue;
      try {
        final data = await rootBundle.load('assets/stings/$file');
        final frames = decodeLogMel(data.buffer.asUint8List());
        stings.add(
          NamedLogMel(
            name: name,
            clip: LogMelClip([
              for (final frame in frames) Float64List.fromList(frame),
            ]),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return stings;
  } catch (_) {
    return const [];
  }
}
