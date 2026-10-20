import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cover_cache.dart';

/// Couleur de page tirée de la pochette. Noir tant que l’image n’est pas lue.
final podcastCoverColorProvider = FutureProvider.autoDispose
    .family<Color, String>((ref, token) async {
      final split = token.split('\n');
      final path = split.first;
      final url = split.length > 1 ? split[1] : '';
      final ImageProvider provider;
      if (path.isNotEmpty) {
        provider = FileImage(File(path));
      } else if (url.isNotEmpty) {
        provider = CachedNetworkImageProvider(
          url,
          cacheKey: url,
          cacheManager: CoverCache.manager,
        );
      } else {
        return Colors.black;
      }
      try {
        final scheme = await ColorScheme.fromImageProvider(
          provider: provider,
          brightness: Brightness.dark,
        );
        return immersiveBackground(scheme.primary);
      } catch (_) {
        return Colors.black;
      }
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

/// Fondu du bas de la pochette vers [color], sans bande grise.
LinearGradient artworkScrim(Color color) {
  const steps = 24;
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      for (var i = 0; i <= steps; i++)
        Color.lerp(color.withValues(alpha: 0), color, _smoothStep(i / steps))!,
    ],
    stops: [for (var i = 0; i <= steps; i++) i / steps],
  );
}

double _smoothStep(double t) => t * t * (3 - 2 * t);
