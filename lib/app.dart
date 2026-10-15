import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'core/theme.dart';
import 'core/wallpaper_colors.dart';
import 'l10n/interface_locale.dart';
import 'l10n/l10n.dart';
import 'settings/settings_controller.dart';
import 'ui/app_router.dart';
import 'ui/widgets/player_keyboard_shortcuts.dart';
import 'ui/widgets/startup_splash.dart';

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
    final locale = resolveInterfaceLocale(
      stored: settings.interfaceLanguage,
      system: View.of(context).platformDispatcher.locale,
    );
    Intl.defaultLocale = locale.languageCode;
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
      locale: locale,
      supportedLocales: [
        for (final language in supportedInterfaceLanguages)
          Locale(language.code),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => InterfaceLocale(
        locale: locale,
        child: PlayerKeyboardShortcuts(
          child: PlaybackLifecycle(
            child: StartupSplash(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}
