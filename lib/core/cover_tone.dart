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

/// Moyenne des pixels de la pochette (hors blancs / gris très clairs).
Future<Color?> loadCoverAverageColor({
  String? path,
  String? url,
  Map<String, String>? headers,
}) async {
  final local = path?.trim();
  final remote = url?.trim();
  final file = await _coverFile(
    local: local != null && local.isNotEmpty ? local : null,
    remote: remote != null && remote.isNotEmpty ? remote : null,
    headers: headers,
  );
  if (file == null) return null;
  try {
    return await _averageColor(file);
  } catch (_) {
    return null;
  }
}

Future<CoverTone?> loadCoverTone({
  String? path,
  String? url,
  Map<String, String>? headers,
}) async {
  final local = path?.trim();
  final remote = url?.trim();
  final hasLocal = local != null && local.isNotEmpty;
  final hasRemote = remote != null && remote.isNotEmpty;
  if (!hasLocal && !hasRemote) return null;

  final key = '${local ?? ''}\n${remote ?? ''}';
  final cached = _memory[key];
  if (cached != null) return cached;

  final average = await loadCoverAverageColor(
    path: local,
    url: remote,
    headers: headers,
  );
  if (average == null) return null;

  final tone = CoverTone(coverBackground(average));
  _memory[key] = tone;
  if (_memory.length > 32) {
    _memory.remove(_memory.keys.first);
  }
  return tone;
}

Future<Color> _averageColor(File file) async {
  final bytes = await file.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 24);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) return const Color(0xFF2E895D);
  final pixels = data.buffer.asUint8List();
  var red = 0;
  var green = 0;
  var blue = 0;
  var count = 0;
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i + 3] < 128) continue;
    final sample = Color.fromARGB(255, pixels[i], pixels[i + 1], pixels[i + 2]);
    if (!coverSampleCounts(sample)) continue;
    red += pixels[i];
    green += pixels[i + 1];
    blue += pixels[i + 2];
    count++;
  }
  if (count == 0) return const Color(0xFF2E895D);
  return Color.fromARGB(255, red ~/ count, green ~/ count, blue ~/ count);
}

Future<File?> _coverFile({
  required String? local,
  required String? remote,
  required Map<String, String>? headers,
}) async {
  if (local != null) {
    final file = File(local);
    if (file.existsSync()) return file;
  }
  if (remote == null) return null;
  try {
    return await CoverCache.manager.getSingleFile(
      remote,
      headers: headers ?? const {},
    );
  } catch (_) {
    return null;
  }
}
