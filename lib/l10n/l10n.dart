import 'package:flutter/widgets.dart';

import 'messages.dart';

/// Porte la langue d’interface choisie. Sans ce widget, les textes restent
/// en français (les tests n’en ont pas besoin).
class InterfaceLocale extends InheritedWidget {
  const InterfaceLocale({
    super.key,
    required this.locale,
    required super.child,
  });

  final Locale locale;

  static Locale? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<InterfaceLocale>()
        ?.locale;
  }

  @override
  bool updateShouldNotify(InterfaceLocale oldWidget) {
    return oldWidget.locale != locale;
  }
}

extension InterfaceL10n on BuildContext {
  /// [key] est le texte anglais. `{nom}` est remplacé par [params].
  /// Sans [InterfaceLocale], le français reste affiché.
  String tr(String key, [Map<String, String>? params]) {
    final code = InterfaceLocale.maybeOf(this)?.languageCode ?? 'fr';
    var text = key;
    if (code != 'en') {
      text = interfaceMessages[code]?[key] ?? key;
    }
    if (params != null) {
      for (final entry in params.entries) {
        text = text.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return text;
  }
}
