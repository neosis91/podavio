import 'package:flutter/widgets.dart';

/// Langues proposées pour l’interface. L’anglais est le repli.
const supportedInterfaceLanguages = <InterfaceLanguage>[
  InterfaceLanguage('en', 'English'),
  InterfaceLanguage('fr', 'Français'),
  InterfaceLanguage('de', 'Deutsch'),
  InterfaceLanguage('es', 'Español'),
  InterfaceLanguage('it', 'Italiano'),
  InterfaceLanguage('pt', 'Português'),
  InterfaceLanguage('nl', 'Nederlands'),
  InterfaceLanguage('zh', '中文'),
  InterfaceLanguage('hi', 'हिन्दी'),
  InterfaceLanguage('id', 'Bahasa Indonesia'),
  InterfaceLanguage('ja', '日本語'),
  InterfaceLanguage('ko', '한국어'),
  InterfaceLanguage('ru', 'Русский'),
  InterfaceLanguage('tr', 'Türkçe'),
  InterfaceLanguage('ar', 'العربية'),
  InterfaceLanguage('pl', 'Polski'),
];

class InterfaceLanguage {
  const InterfaceLanguage(this.code, this.endonym);

  final String code;
  final String endonym;
}

const supportedInterfaceLanguageCodes = <String>[
  'en',
  'fr',
  'de',
  'es',
  'it',
  'pt',
  'nl',
  'zh',
  'hi',
  'id',
  'ja',
  'ko',
  'ru',
  'tr',
  'ar',
  'pl',
];

/// `stored` vide : langue du système si elle est proposée, sinon l’anglais.
Locale resolveInterfaceLocale({String? stored, required Locale system}) {
  final chosen = _supported(stored);
  if (chosen != null) return Locale(chosen);
  final fromSystem = _supported(system.languageCode);
  if (fromSystem != null) return Locale(fromSystem);
  return const Locale('en');
}

String? normalizeInterfaceLanguage(String? stored) => _supported(stored);

String interfaceLanguageEndonym(String code) {
  for (final language in supportedInterfaceLanguages) {
    if (language.code == code) return language.endonym;
  }
  return code;
}

String? _supported(String? raw) {
  final code = raw?.trim().toLowerCase() ?? '';
  if (code.isEmpty) return null;
  if (supportedInterfaceLanguageCodes.contains(code)) return code;
  return null;
}
