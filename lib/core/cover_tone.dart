import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'cover_cache.dart';
import 'theme.dart';

/// Couleur de la pochette, utilisée telle quelle comme fond du lecteur.
class CoverTone {
  const CoverTone(this.background);

  final Color background;
}

/// La teinte de l’image, gardée vive, sans partir dans le blanc ni le noir.
Color coverBackground(Color seed) {
  final hsl = HSLColor.fromColor(seed);
  final saturation = hsl.saturation < 0.08
      ? hsl.saturation
      : hsl.saturation.clamp(0.0, 0.82);
  return hsl
      .withSaturation(saturation)
      .withLightness(hsl.lightness.clamp(0.46, 0.62))
      .toColor();
}

/// Le blanc et les gris très clairs ne comptent pas dans la couleur de fond.
bool coverSampleCounts(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.lightness < 0.88 || hsl.saturation >= 0.15;
}

/// Encre lisible sur [background] : sombre sur un fond clair, claire sinon.
Color coverInk(Color background) {
  return background.computeLuminance() > 0.4
      ? const Color(0xFF1A1A1A)
      : Colors.white;
}

/// Carte du mini-lecteur : le texte et les icônes restent blancs.
ThemeData miniPlayerTheme(Color background) {
  final theme = playbackTheme(background);
  const ink = Colors.white;
  return theme.copyWith(
    colorScheme: theme.colorScheme.copyWith(
      onSurface: ink,
      onSurfaceVariant: ink.withValues(alpha: 0.78),
    ),
    iconTheme: const IconThemeData(color: ink),
    textTheme: theme.textTheme.apply(bodyColor: ink, displayColor: ink),
  );
}

/// La couleur de la pochette s’éteint à la moitié, le reste est noir.
LinearGradient coverPlayerGradient(Color background) {
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, Colors.black, Colors.black],
    stops: const [0, 0.5, 1],
  );
}

/// Texte, icônes et boutons contrastés sur le fond de la pochette.
ThemeData playbackTheme(Color background) {
  // Le bas de l’écran est noir : le texte et les commandes restent clairs.
  const ink = Colors.white;
  const onButton = Color(0xFF1A1A1A);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: background,
        brightness: Brightness.dark,
      ).copyWith(
        surface: background,
        surfaceDim: background,
        surfaceBright: background,
        surfaceContainerLowest: background,
        surfaceContainerLow: background,
        surfaceContainer: background,
        surfaceContainerHigh: background,
        surfaceContainerHighest: background,
        onSurface: ink,
        onSurfaceVariant: ink.withValues(alpha: 0.74),
        primary: ink,
        onPrimary: onButton,
        primaryContainer: ink.withValues(alpha: 0.16),
        onPrimaryContainer: ink,
        secondary: ink,
        onSecondary: onButton,
        secondaryContainer: ink.withValues(alpha: 0.18),
        onSecondaryContainer: ink,
        outline: ink.withValues(alpha: 0.38),
      );
  final theme = themeFromScheme(scheme);
  return theme.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    iconTheme: const IconThemeData(color: ink),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: ink),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF121212),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF121212)),
    appBarTheme: theme.appBarTheme.copyWith(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}

final _memory = <String, CoverTone>{};

/// Teinte la plus présente de la pochette, hors blanc, noir et gris.
///
/// Les pixels d’une même teinte sont regroupés. Une teinte qui couvre moins
/// de 10 % de l’image est ignorée dès qu’une autre est assez présente. Le
/// groupe retenu est le plus fourni et le plus saturé, pour qu’un mélange
/// vert et rouge ne vire pas au gris.
Future<Color?> loadCoverDominantColor({
  String? path,
  String? url,
  Map<String, String>? headers,
  bool allowDownload = true,
}) async {
  final local = path?.trim();
  final remote = url?.trim();
  final file = await _coverFile(
    local: local != null && local.isNotEmpty ? local : null,
    remote: remote != null && remote.isNotEmpty ? remote : null,
    headers: headers,
    allowDownload: allowDownload,
  );
  if (file == null) return null;
  try {
    return await _dominantColor(file);
  } catch (_) {
    return null;
  }
}

Future<CoverTone?> loadCoverTone({
  String? path,
  String? url,
  Map<String, String>? headers,
  bool allowDownload = true,
}) async {
  final local = path?.trim();
  final remote = url?.trim();
  final hasLocal = local != null && local.isNotEmpty;
  final hasRemote = remote != null && remote.isNotEmpty;
  if (!hasLocal && !hasRemote) return null;

  final key = '${local ?? ''}\n${remote ?? ''}';
  final cached = _memory[key];
  if (cached != null) return cached;

  final dominant = await loadCoverDominantColor(
    path: local,
    url: remote,
    headers: headers,
    allowDownload: allowDownload,
  );
  if (dominant == null) return null;

  final tone = CoverTone(coverBackground(dominant));
  _memory[key] = tone;
  if (_memory.length > 32) {
    _memory.remove(_memory.keys.first);
  }
  return tone;
}

Future<Color> _dominantColor(File file) async {
  final bytes = await file.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 32);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) return const Color(0xFF2E895D);
  final pixels = data.buffer.asUint8List();
  const buckets = 18;
  final count = List<int>.filled(buckets, 0);
  final red = List<int>.filled(buckets, 0);
  final green = List<int>.filled(buckets, 0);
  final blue = List<int>.filled(buckets, 0);
  final saturation = List<double>.filled(buckets, 0);
  var neutralRed = 0;
  var neutralGreen = 0;
  var neutralBlue = 0;
  var neutralCount = 0;
  var opaque = 0;
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i + 3] < 128) continue;
    opaque++;
    final sample = Color.fromARGB(255, pixels[i], pixels[i + 1], pixels[i + 2]);
    final hsl = HSLColor.fromColor(sample);
    if (hsl.lightness < 0.07 || hsl.lightness > 0.93) continue;
    if (hsl.saturation < 0.15) {
      neutralRed += pixels[i];
      neutralGreen += pixels[i + 1];
      neutralBlue += pixels[i + 2];
      neutralCount++;
      continue;
    }
    final index = ((hsl.hue + 10) % 360 / (360 / buckets))
        .floor()
        .clamp(0, buckets - 1);
    count[index]++;
    red[index] += pixels[i];
    green[index] += pixels[i + 1];
    blue[index] += pixels[i + 2];
    saturation[index] += hsl.saturation;
  }
  final minSamples = opaque * 0.10;
  var best = -1;
  var bestScore = 0.0;
  var fallback = -1;
  var fallbackScore = 0.0;
  for (var i = 0; i < buckets; i++) {
    final samples = count[i];
    if (samples == 0) continue;
    final score = samples * (0.35 + saturation[i] / samples);
    if (score > fallbackScore) {
      fallbackScore = score;
      fallback = i;
    }
    if (!_hueQualifies(count, i, minSamples)) continue;
    if (score > bestScore) {
      bestScore = score;
      best = i;
    }
  }
  final chosen = best >= 0 ? best : fallback;
  if (chosen >= 0) {
    final samples = count[chosen];
    return Color.fromARGB(
      255,
      red[chosen] ~/ samples,
      green[chosen] ~/ samples,
      blue[chosen] ~/ samples,
    );
  }
  if (neutralCount == 0) return const Color(0xFF2E895D);
  return Color.fromARGB(
    255,
    neutralRed ~/ neutralCount,
    neutralGreen ~/ neutralCount,
    neutralBlue ~/ neutralCount,
  );
}

/// Vrai si cette teinte couvre au moins [minSamples] pixels.
///
/// Une teinte à cheval sur deux groupes est comptée avec ses voisines, mais
/// seulement pour le groupe le plus fourni. Un petit rouge à côté d’un grand
/// vert ne passe pas le seuil grâce au vert.
bool _hueQualifies(List<int> count, int index, double minSamples) {
  final samples = count[index];
  if (samples >= minSamples) return true;
  final last = count.length - 1;
  final previous = index == 0 ? count[last] : count[index - 1];
  final next = index == last ? count[0] : count[index + 1];
  if (samples < previous || samples < next) return false;
  return samples + previous + next >= minSamples;
}

Future<File?> _coverFile({
  required String? local,
  required String? remote,
  required Map<String, String>? headers,
  bool allowDownload = true,
}) async {
  if (local != null) {
    final file = File(local);
    if (file.existsSync()) return file;
  }
  if (remote == null) return null;
  if (!allowDownload) {
    try {
      final cached = await CoverCache.manager.getFileFromCache(remote);
      return cached?.file;
    } catch (_) {
      return null;
    }
  }
  try {
    return await CoverCache.manager.getSingleFile(
      remote,
      headers: headers ?? const {},
    );
  } catch (_) {
    return null;
  }
}
