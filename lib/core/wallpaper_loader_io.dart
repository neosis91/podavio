import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'wallpaper_colors.dart';

Future<WallpaperPalette?> loadWallpaperPalette() async {
  if (Platform.isAndroid) {
    final core = await DynamicColorPlugin.getCorePalette();
    if (core != null) {
      final seed = Color(core.primary.get(40));
      return WallpaperPalette(
        light: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        dark: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      );
    }
  }

  final path = await _wallpaperFile();
  if (path != null) {
    final provider = FileImage(File(path));
    try {
      final light = await ColorScheme.fromImageProvider(
        provider: provider,
        brightness: Brightness.light,
      );
      final dark = await ColorScheme.fromImageProvider(
        provider: provider,
        brightness: Brightness.dark,
      );
      return WallpaperPalette(light: light, dark: dark);
    } catch (_) {
      return null;
    }
  }

  final accent = await DynamicColorPlugin.getAccentColor();
  if (accent == null) return null;
  return WallpaperPalette(
    light: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ),
    dark: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
  );
}

Future<String?> _wallpaperFile() async {
  if (Platform.isLinux) {
    final kde = await _kdeWallpaper();
    if (kde != null) return kde;
    return _gnomeWallpaper();
  }
  if (Platform.isWindows) return _windowsWallpaper();
  if (Platform.isMacOS) return _macWallpaper();
  return null;
}

Future<String?> _kdeWallpaper() async {
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) return null;
  final file = File(
    p.join(home, '.config', 'plasma-org.kde.plasma.desktop-appletsrc'),
  );
  if (!file.existsSync()) return null;
  final path = kdeWallpaperFromConfig(await file.readAsString());
  if (path == null || !File(path).existsSync()) return null;
  return path;
}

Future<String?> _gnomeWallpaper() async {
  try {
    final result = await Process.run('gsettings', [
      'get',
      'org.gnome.desktop.background',
      'picture-uri',
    ]);
    if (result.exitCode != 0) return null;
    final path = gnomeUriToPath('${result.stdout}');
    if (path == null || !File(path).existsSync()) return null;
    return path;
  } catch (_) {
    return null;
  }
}

String? _windowsWallpaper() {
  final appData = Platform.environment['APPDATA'];
  if (appData == null || appData.isEmpty) return null;
  final path = p.join(
    appData,
    'Microsoft',
    'Windows',
    'Themes',
    'TranscodedWallpaper',
  );
  if (!File(path).existsSync()) return null;
  return path;
}

Future<String?> _macWallpaper() async {
  try {
    final result = await Process.run('osascript', [
      '-e',
      'tell application "System Events" to get picture of current desktop',
    ]).timeout(const Duration(seconds: 2));
    if (result.exitCode != 0) return null;
    final path = '${result.stdout}'.trim();
    if (path.isEmpty || !File(path).existsSync()) return null;
    return path;
  } catch (_) {
    return null;
  }
}
