import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/l10n/interface_locale.dart';

void main() {
  test('resolveInterfaceLocale follows a stored language', () {
    expect(
      resolveInterfaceLocale(stored: 'de', system: const Locale('fr')),
      const Locale('de'),
    );
  });

  test(
    'resolveInterfaceLocale uses the system language when nothing is stored',
    () {
      expect(
        resolveInterfaceLocale(stored: null, system: const Locale('nl', 'BE')),
        const Locale('nl'),
      );
      expect(
        resolveInterfaceLocale(stored: '', system: const Locale('es')),
        const Locale('es'),
      );
    },
  );

  test('resolveInterfaceLocale falls back to English', () {
    expect(
      resolveInterfaceLocale(stored: null, system: const Locale('sv')),
      const Locale('en'),
    );
    expect(
      resolveInterfaceLocale(stored: 'sv', system: const Locale('fi')),
      const Locale('en'),
    );
  });

  test('resolveInterfaceLocale follows a newly supported system language', () {
    expect(
      resolveInterfaceLocale(stored: null, system: const Locale('ja')),
      const Locale('ja'),
    );
    expect(
      resolveInterfaceLocale(stored: 'zh', system: const Locale('fr')),
      const Locale('zh'),
    );
  });

  test('normalizeInterfaceLanguage drops unknown codes', () {
    expect(normalizeInterfaceLanguage('FR'), 'fr');
    expect(normalizeInterfaceLanguage('pt-BR'), isNull);
    expect(normalizeInterfaceLanguage(null), isNull);
  });
}
