import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme.dart';
import 'data/providers.dart';
import 'player/playback_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.title = 'Podavio';
  JustAudioMediaKit.ensureInitialized();
  await _startBackgroundPlayback();
  await initializeDateFormatting('fr');
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const PodavioApp(),
    ),
  );
}

Future<void> _startBackgroundPlayback() async {
  if (kIsWeb ||
      !(Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isLinux ||
          Platform.isMacOS)) {
    return;
  }
  try {
    final preferences = await SharedPreferences.getInstance();
    final skipBack = preferences.getInt('skipBack') ?? 10;
    final skipForward = preferences.getInt('skipForward') ?? 30;
    final handler = await AudioService.init(
      builder: PlaybackHandler.new,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'fr.podavio.playback',
        androidNotificationChannelName: 'Podavio',
        androidNotificationChannelDescription: 'Lecture des podcasts',
        androidNotificationIcon: 'drawable/ic_notification',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: podavioBlue,
        fastForwardInterval: Duration(seconds: skipForward),
        rewindInterval: Duration(seconds: skipBack),
      ),
    );
    handler.skipBack = Duration(seconds: skipBack);
    handler.skipForward = Duration(seconds: skipForward);
    playbackHandler = handler;
  } catch (error, stack) {
    debugPrint('Lecture en arrière-plan indisponible: $error\n$stack');
  }
}
