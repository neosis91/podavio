import 'package:flutter/material.dart';

const podavioBlue = Color(0xFF002395);
const podavioRed = Color(0xFFED2939);

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: podavioBlue,
    brightness: Brightness.light,
  );
  return _theme(scheme);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: podavioBlue,
    brightness: Brightness.dark,
  );
  return _theme(scheme);
}

ThemeData _theme(ColorScheme scheme) {
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
