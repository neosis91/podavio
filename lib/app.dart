import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/wallpaper_colors.dart';
import 'settings/settings_controller.dart';
import 'ui/app_router.dart';
import 'ui/widgets/player_keyboard_shortcuts.dart';

class PodavioApp extends ConsumerWidget {
  const PodavioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    final wallpaper = ref.watch(wallpaperPaletteProvider).asData?.value;
    final fromWallpaper =
        defaultTargetPlatform != TargetPlatform.iOS && settings.wallpaperColors
        ? wallpaper
        : null;
    return MaterialApp.router(
      title: 'Podavio',
      theme: fromWallpaper == null
          ? buildLightTheme(settings.accent)
          : themeFromScheme(fromWallpaper.light),
      darkTheme: fromWallpaper == null
          ? buildDarkTheme(settings.accent, pureBlack: settings.pureBlack)
          : themeFromScheme(fromWallpaper.dark, pureBlack: settings.pureBlack),
      themeMode: settings.themeMode,
      routerConfig: router,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => PlayerKeyboardShortcuts(
        child: PlaybackLifecycle(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
