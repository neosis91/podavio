import 'package:flutter/material.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/providers.dart';
import 'player/playback_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.title = 'Podavio';
  JustAudioMediaKit.ensureInitialized();
  await _startMediaSession();
  await initializeDateFormatting('fr');
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const PodavioApp(),
    ),
  );
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
