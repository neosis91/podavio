import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import 'wallpaper_loader.dart';

class WallpaperPalette {
  const WallpaperPalette({required this.light, required this.dark});

  final ColorScheme light;
  final ColorScheme dark;
}

final wallpaperPaletteProvider = FutureProvider<WallpaperPalette?>((ref) async {
  if (!ref.watch(
    settingsProvider.select((settings) => settings.wallpaperColors),
  )) {
    return null;
  }
  return loadWallpaperPalette();
});

class _Desktop {
  String? activityId;
  int? screen;
  String? plugin;
  String? image;
}

/// Picks the desktop wallpaper from a Plasma `appletsrc` file.
String? kdeWallpaperFromConfig(String config) {
  final desktops = <String, _Desktop>{};
  String? section;
  String? currentId;
  for (final raw in config.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('[') && line.endsWith(']')) {
      section = line;
      final match = RegExp(r'^\[Containments\]\[(\d+)\]$').firstMatch(line);
      if (match != null) {
        currentId = match.group(1);
        desktops.putIfAbsent(currentId!, () => _Desktop());
      }
      continue;
    }
    if (section == null || currentId == null || !line.contains('=')) continue;
    final desktop = desktops[currentId];
    if (desktop == null) continue;
    final value = line.substring(line.indexOf('=') + 1).trim();
    if (section == '[Containments][$currentId]') {
      if (line.startsWith('activityId=')) desktop.activityId = value;
      if (line.startsWith('lastScreen=')) desktop.screen = int.tryParse(value);
      if (line.startsWith('plugin=')) desktop.plugin = value;
    } else if (section.contains('[Wallpaper]') && line.startsWith('Image=')) {
      desktop.image = filePathFromImageValue(value);
    }
  }

  final candidates = desktops.values.where((desktop) {
    final image = desktop.image;
    return image != null && image.isNotEmpty;
  });
  if (candidates.isEmpty) return null;
  final ranked = candidates.toList()
    ..sort((a, b) => _score(b).compareTo(_score(a)));
  return ranked.first.image;
}

int _score(_Desktop desktop) {
  var score = 0;
  if ((desktop.activityId ?? '').isNotEmpty) score += 4;
  if (desktop.plugin == 'org.kde.plasma.folder') score += 2;
  if (desktop.screen == 0) score += 1;
  return score;
}

String? filePathFromImageValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('file:')) {
    return Uri.tryParse(trimmed)?.toFilePath();
  }
  if (trimmed.startsWith('/')) return trimmed;
  return null;
}

String? gnomeUriToPath(String value) {
  var trimmed = value.trim();
  if (trimmed.length >= 2 &&
      ((trimmed.startsWith("'") && trimmed.endsWith("'")) ||
          (trimmed.startsWith('"') && trimmed.endsWith('"')))) {
    trimmed = trimmed.substring(1, trimmed.length - 1);
  }
  return filePathFromImageValue(trimmed);
}
