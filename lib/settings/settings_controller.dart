import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.speed,
    required this.skipBackSeconds,
    required this.skipForwardSeconds,
  });

  final ThemeMode themeMode;
  final double speed;
  final int skipBackSeconds;
  final int skipForwardSeconds;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? speed,
    int? skipBackSeconds,
    int? skipForwardSeconds,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      speed: speed ?? this.speed,
      skipBackSeconds: skipBackSeconds ?? this.skipBackSeconds,
      skipForwardSeconds: skipForwardSeconds ?? this.skipForwardSeconds,
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    final themeName = preferences.getString('theme') ?? ThemeMode.system.name;
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[themeName] ?? ThemeMode.system,
      speed: preferences.getDouble('speed') ?? 1,
      skipBackSeconds: preferences.getInt('skipBack') ?? 10,
      skipForwardSeconds: preferences.getInt('skipForward') ?? 30,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString('theme', mode.name);
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(speed: speed);
    await ref.read(sharedPreferencesProvider).setDouble('speed', speed);
  }

  Future<void> setSkipBack(int seconds) async {
    state = state.copyWith(skipBackSeconds: seconds);
    await ref.read(sharedPreferencesProvider).setInt('skipBack', seconds);
  }

  Future<void> setSkipForward(int seconds) async {
    state = state.copyWith(skipForwardSeconds: seconds);
    await ref.read(sharedPreferencesProvider).setInt('skipForward', seconds);
  }
}
