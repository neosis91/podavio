import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'settings/settings_controller.dart';
import 'ui/app_router.dart';

class PodavioApp extends ConsumerWidget {
  const PodavioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Podavio',
      theme: buildLightTheme(settings.accent),
      darkTheme: buildDarkTheme(settings.accent),
      themeMode: settings.themeMode,
      routerConfig: router,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          PlaybackLifecycle(child: child ?? const SizedBox.shrink()),
    );
  }
}
