import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cover_tone.dart';

/// Couleur de page tirée de la moyenne de la pochette (comme le lecteur).
/// Noir tant que l’image n’est pas lue.
final podcastCoverColorProvider = FutureProvider.autoDispose
    .family<Color, String>((ref, token) async {
      final split = token.split('\n');
      final path = split.first;
      final url = split.length > 1 ? split[1] : '';
      final average = await loadCoverAverageColor(
        path: path.isEmpty ? null : path,
        url: url.isEmpty ? null : url,
      );
      if (average == null) return Colors.black;
      return immersiveBackground(average);
    });

String coverColorToken({String? path, String? url}) {
  return '${path?.trim() ?? ''}\n${url?.trim() ?? ''}';
}

/// Teinte de la pochette, un peu tirée vers le noir pour le texte blanc.
Color immersiveBackground(Color base) {
  final hsl = HSLColor.fromColor(base);
  final vivid = hsl
      .withSaturation((hsl.saturation * 1.07).clamp(0.0, 1.0))
      .withLightness(hsl.lightness.clamp(0.0, 0.58))
      .toColor();
  final luminance = vivid.computeLuminance();
  final darken = 0.26 + 0.38 * luminance;
  return Color.lerp(vivid, Colors.black, darken)!;
}
