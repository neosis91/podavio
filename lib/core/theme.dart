import 'package:flutter/material.dart';

const podavioBlue = Color(0xFF002395);
const podavioRed = Color(0xFFED2939);

enum AppAccent {
  blue('blue', 'Bleu', podavioBlue),
  green('green', 'Vert', Color(0xFF2E7D32)),
  purple('purple', 'Violet', Color(0xFF6A1B9A)),
  red('red', 'Rouge', Color(0xFFC62828)),
  orange('orange', 'Orange', Color(0xFFEF6C00)),
  teal('teal', 'Turquoise', Color(0xFF00838F)),
  pink('pink', 'Rose', Color(0xFFC2185B)),
  sky('sky', 'Bleu ciel', Color(0xFF0288D1)),
  indigo('indigo', 'Indigo', Color(0xFF3949AB)),
  cyan('cyan', 'Cyan', Color(0xFF00ACC1)),
  amber('amber', 'Ambre', Color(0xFFFF8F00)),
  yellow('yellow', 'Jaune', Color(0xFFF9A825)),
  lime('lime', 'Lime', Color(0xFF7CB342)),
  brown('brown', 'Brun', Color(0xFF6D4C41)),
  slate('slate', 'Ardoise', Color(0xFF546E7A)),
  wine('wine', 'Bordeaux', Color(0xFF880E4F));

  const AppAccent(this.id, this.label, this.seed);

  final String id;
  final String label;
  final Color seed;

  static AppAccent byId(String? id) {
    for (final accent in values) {
      if (accent.id == id) return accent;
    }
    return blue;
  }
}

ThemeData buildLightTheme(AppAccent accent) {
  return _theme(
    ColorScheme.fromSeed(seedColor: accent.seed, brightness: Brightness.light),
  );
}

ThemeData buildDarkTheme(AppAccent accent) {
  return _theme(
    ColorScheme.fromSeed(seedColor: accent.seed, brightness: Brightness.dark),
  );
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
