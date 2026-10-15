import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'l10n/interface_locale.dart';
import 'data/providers.dart';
import 'player/playback_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureMpvCacheDir();
  JustAudioMediaKit.title = 'Podavio';
  JustAudioMediaKit.ensureInitialized();
  await _startMediaSession();
  for (final code in supportedInterfaceLanguageCodes) {
    await initializeDateFormatting(code);
  }
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const PodavioApp(),
    ),
  );
}

/// media_kit active `cache-on-disk` ; sans répertoire mpv, lavf échoue sur Linux.
Future<void> _ensureMpvCacheDir() async {
  if (kIsWeb || !Platform.isLinux) return;
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) return;
  final xdg = Platform.environment['XDG_CACHE_HOME'];
  final cacheHome = (xdg != null && xdg.isNotEmpty)
      ? xdg
      : p.join(home, '.cache');
  try {
    await Directory(p.join(cacheHome, 'mpv')).create(recursive: true);
  } catch (error) {
    debugPrint('Cache MPV indisponible: $error');
  }
}

Future<void> _startMediaSession() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final handler = PlaybackHandler(FlutterMediaSession());
    handler.skipBack = Duration(seconds: preferences.getInt('skipBack') ?? 10);
    handler.skipForward = Duration(
      seconds: preferences.getInt('skipForward') ?? 30,
    );
    await handler.prepare();
    playbackHandler = handler;
  } catch (error, stack) {
    debugPrint('Contrôles média indisponibles: $error\n$stack');
  }
}
