import 'package:flutter_test/flutter_test.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:podavio/data/discover_languages.dart';

void main() {
  test('defaults to all languages and summarizes the selection', () {
    expect(normalizeDiscoverLanguages(null), const [discoverLanguagesAll]);
    expect(normalizeDiscoverLanguages(['inconnu']), const [
      discoverLanguagesAll,
    ]);
    expect(discoverLanguagesSummary(['fr']), 'Français');
    expect(discoverLanguagesSummary(['fr', 'en']), 'Français, Anglais');
    expect(discoverLanguagesSummary(['fr', 'en', 'de']), '3 langues');
    expect(
      discoverLanguagesSummary(const [discoverLanguagesAll]),
      'Toutes les langues',
    );
  });

  test('drops a missing language and applies the prefix rule', () {
    expect(discoverLanguageMatches(null, ['fr']), isFalse);
    expect(discoverLanguageMatches('', ['fr']), isFalse);
    expect(discoverLanguageMatches('de', ['fr']), isFalse);
    expect(discoverLanguageMatches('de-de', ['fr']), isFalse);
    expect(discoverLanguageMatches('fr-ca', ['fr']), isTrue);
    expect(discoverLanguageMatches('en-us', ['fr']), isFalse);
    expect(discoverLanguageMatches('en', ['en-gb']), isFalse);
    expect(discoverLanguageMatches('en-gb', ['en-gb']), isTrue);
    expect(discoverLanguageMatches('en-us', ['en']), isTrue);
    expect(discoverLanguageMatches('EN_US', ['en']), isTrue);
    expect(discoverLanguageMatches('id', ['in']), isTrue);
    expect(discoverLanguageMatches('iw', ['he']), isTrue);
    expect(discoverLanguageMatches('nb', ['no']), isTrue);
    expect(discoverLanguageMatches('nn', ['nb']), isFalse);
    expect(discoverLanguageMatches('de', const [discoverLanguagesAll]), isTrue);
    expect(
      rssChannelLanguage('''
<rss><channel>
  <language>de</language>
  <item><language>fr</language></item>
</channel></rss>
'''),
      'de',
    );
    expect(
      rssChannelLanguage('<rss><channel><item></item></channel></rss>'),
      isNull,
    );
  });

  test('reads channel categories and ignores episode categories', () {
    expect(
      rssChannelCategories('''
<rss><channel>
  <itunes:category text="Society &amp; Culture">
    <itunes:category text="Documentary"/>
  </itunes:category>
  <podcast:category text="History"/>
  <item><itunes:category text="Music"/></item>
</channel></rss>
'''),
      ['Society & Culture', 'Documentary', 'History'],
    );
    expect(
      rssChannelCategories('<rss><channel><item></item></channel></rss>'),
      isEmpty,
    );
  });

  test('groups regional variants under the base language', () {
    final english = discoverLanguageGroups.firstWhere(
      (group) => group.language.code == 'en',
    );
    expect(english.variants.map((variant) => variant.code), contains('en-gb'));
    expect(
      discoverLanguageGroups.any((group) => group.language.code == 'en-gb'),
      isFalse,
    );
    final french = discoverLanguageGroups.firstWhere(
      (group) => group.language.code == 'fr',
    );
    expect(french.variants.map((variant) => variant.code), contains('fr-ca'));
    expect(discoverLanguageLabel('fr-ca'), 'Français (Canada)');
  });

  test('flags when Apple would open more than 8 stores', () {
    expect(appleStoresExceedLimit(['fr', 'en']), isFalse);
    expect(
      appleStoresExceedLimit(['fr', 'en', 'de', 'es', 'it', 'pt', 'nl', 'pl']),
      isFalse,
    );
    expect(
      appleStoresExceedLimit([
        'fr',
        'en',
        'de',
        'es',
        'it',
        'pt',
        'nl',
        'pl',
        'ja',
      ]),
      isTrue,
    );
    expect(appleStoresExceedLimit(const [discoverLanguagesAll]), isFalse);
    expect(normalizeDiscoverLanguagesPicked(null), ['fr']);
    expect(normalizeDiscoverLanguagesPicked(['en', 'de']), ['en', 'de']);
    expect(normalizeDiscoverLanguagesPicked(const [discoverLanguagesAll]), [
      'fr',
    ]);
  });

  test('maps a language to an Apple store', () {
    expect(appleCountryFor('fr'), Country.france);
    expect(appleCountryFor('en'), Country.unitedStates);
    expect(appleCountryFor('en-gb'), Country.unitedKingdom);
    expect(appleCountryFor('pt-br'), Country.brazil);
    expect(appleCountryFor('in'), Country.indonesia);
    expect(appleCountryFor('ar'), Country.saudiArabia);
    expect(appleCountryFor('ar-eg'), Country.egypt);
    expect(appleCountryFor('ar-ae'), Country.unitedArabEmirates);
    expect(appleCountryFor('hi'), Country.india);
    expect(appleCountryFor('he'), Country.israel);
    expect(appleCountryFor('vi'), Country.vietNam);
    expect(appleCountryFor('zh'), Country.china);
    expect(appleCountryFor('eu'), isNull);
    expect(appleCountryFor('haw'), isNull);
    expect(appleSearchStores(['fr', 'en', 'en-gb']), [
      Country.france,
      Country.unitedStates,
      Country.unitedKingdom,
    ]);
    expect(appleSearchStores(const [discoverLanguagesAll]), [Country.none]);
    expect(appleChartStores(const [discoverLanguagesAll]), [
      Country.unitedStates,
    ]);
    expect(
      appleSearchStores(['fr', 'en', 'de', 'es', 'it', 'pt', 'nl', 'pl', 'ja']),
      hasLength(discoverAppleStoreLimit),
    );
  });

  test('expands Podcast Index codes without crossing languages', () {
    final english = podcastIndexLanguageQuery(['en']);
    expect(english, contains('en'));
    expect(english, contains('en-gb'));
    expect(english, isNot(contains('fr')));
    expect(podcastIndexLanguageQuery(['en-gb']), ['en-gb']);
    final arabic = podcastIndexLanguageQuery(['ar']);
    expect(arabic, contains('ar'));
    expect(arabic, contains('ar-sa'));
    expect(arabic, contains('ar-eg'));
    expect(arabic, isNot(contains('fr')));
    expect(podcastIndexLanguageQuery(['in']), contains('id'));
    expect(podcastIndexLanguageQuery(['no']), containsAll(['no', 'nb', 'nn']));
    expect(
      discoverLanguageCatalog.map((language) => language.code),
      containsAll(['hi', 'th', 'sw', 'zh']),
    );
    expect(podcastIndexLanguageQuery(const [discoverLanguagesAll]), isEmpty);
  });
}
