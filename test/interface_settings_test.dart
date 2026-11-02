import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/catalog_categories.dart';
import 'package:podavio/data/discover_providers.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/l10n/messages.dart';
import 'package:podavio/settings/settings_controller.dart';
import 'package:podavio/ui/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('interface settings start from the current behavior', () {
    expect(HomeShelves.fromIds(null).visible, HomeShelves.known);
    expect(HomeShelves.fromIds(null).toIds(), HomeShelves.known);
    expect(HomeShelves.defaults.visible, HomeShelves.known);
  });

  test('unknown shelf ids are ignored and missing ones stay visible', () {
    final stored = HomeShelves.fromIds(const [
      'downloads',
      '-continue',
      'preferred',
      'nope',
      '-bogus',
      'fresh',
      '-fresh',
    ]);
    expect(stored.visible, [
      'downloads',
      'preferred',
      'fresh',
      'favorites',
      'recent',
      'random',
    ]);
    expect(stored.toIds(), isNot(contains('nope')));
    expect(stored.toIds(), isNot(contains('-bogus')));
    expect(stored.toIds(), contains('-continue'));

    final hidden = stored.copyWith(
      order: const [
        'random',
        'downloads',
        'preferred',
        'fresh',
        'favorites',
        'recent',
        'continue',
      ],
      enabled: {...stored.enabled}..remove('downloads'),
    );
    expect(hidden.visible, [
      'random',
      'preferred',
      'fresh',
      'favorites',
      'recent',
    ]);
    expect(hidden.toIds().first, 'random');
    expect(hidden.toIds(), contains('-downloads'));
    expect(hidden.toIds(), contains('-continue'));
  });

  test('history keeps historical subjects and a category can be chosen', () {
    expect(fyydHistoryCategoriesStay(const [129]), isTrue);
    expect(fyydHistoryCategoriesStay(const [129, 119, 181]), isTrue);
    expect(fyydHistoryCategoriesStay(const [129, 100, 203]), isTrue);
    expect(fyydHistoryCategoriesStay(const [171, 177, 181, 182, 129]), isFalse);
    expect(fyydHistoryCategoriesStay(const [129, 137, 141]), isFalse);
    expect(fyydHistoryCategoriesStay(const [129, 185, 183]), isFalse);
    expect(fyydHistoryCategoriesStay(const []), isTrue);

    expect(podcastIndexHistoryCategoriesStay(const ['History']), isTrue);
    expect(
      podcastIndexHistoryCategoriesStay(const ['History', 'Education']),
      isTrue,
    );
    expect(
      podcastIndexHistoryCategoriesStay(const [
        'History',
        'Society',
        'Culture',
        'Documentary',
      ]),
      isTrue,
    );
    expect(
      podcastIndexHistoryCategoriesStay(const ['History', 'Kids', 'Stories']),
      isFalse,
    );
    expect(
      podcastIndexHistoryCategoriesStay(const ['Music', 'History']),
      isFalse,
    );
    expect(
      podcastIndexHistoryCategoriesStay(const [
        'Arts',
        'Books',
        'History',
        'Leisure',
      ]),
      isFalse,
    );
    expect(podcastIndexHistoryCategoriesStay(const []), isTrue);

    expect(enabledSubjects('history', null).map((member) => member.genre), [
      'History',
    ]);
    expect(
      enabledSubjects('history', const [
        'Music History',
        'History',
        'nope',
      ]).map((member) => member.genre),
      ['History', 'Music History'],
    );
    expect(
      enabledSubjects('history', const ['nope']).map((member) => member.genre),
      ['History'],
    );
    final genres = [for (final member in allCatalogMembers) member.genre];
    expect(genres.toSet(), hasLength(genres.length));
  });

  test('a subscription matches only the subjects kept in its category', () {
    expect(
      podcastGenresMatchCategory(const ['News', 'Politics'], 'news', null),
      isTrue,
    );
    expect(
      podcastGenresMatchCategory(const ['Tech News'], 'news', null),
      isFalse,
    );
    expect(
      podcastGenresMatchCategory(const ['Tech News'], 'technology', null),
      isTrue,
    );
    expect(
      podcastGenresMatchCategory(const ['News'], 'news', const ['Politics']),
      isFalse,
    );
    expect(
      podcastGenresMatchCategory(
        const ['Politics'],
        'news',
        const ['Politics'],
      ),
      isTrue,
    );
    expect(
      podcastGenresMatchCategory(const ['Society & Culture'], 'society', null),
      isTrue,
    );
  });

  test('interface setting strings exist in every language', () {
    const keys = [
      'Cover tint',
      'The player and the top of the home follow the cover',
      'Shelves',
      'Order and hide the home shelves',
      'Continue listening',
      "What's new",
      'Random',
      'Preferred subscriptions',
      'Recent downloads',
      'Every shelf is hidden',
      'Show them again in Interface.',
      'All',
      'Comedy',
      'News',
      'Society & Culture',
      'True Crime',
      'Education',
      'Technology',
      'Business',
      'Health & Fitness',
      'History',
      'Science',
      'Sports',
      'Music',
      'TV & Film',
      'Arts',
      'Kids & Family',
      'Leisure',
      'Food',
      'Games',
      'Nature',
      'Places & Travel',
      'Religion & Spirituality',
      'Fiction',
      'Government',
      'Categories',
      'Choose the categories on the home screen',
      'Until you choose, the home follows the most played categories this month.',
      'Subjects',
      'Choose the subjects in this category',
      'Podcasts to discover',
      'Nothing new in this category',
      'You already follow the podcasts found here.',
      'Retry',
      'The search failed.',
    ];
    expect(interfaceMessages, hasLength(15));
    final genres = [
      for (final category in catalogCategories) ...[
        category.genre,
        for (final sub in category.subcategories) sub.genre,
      ],
    ];
    for (final entry in interfaceMessages.entries) {
      for (final key in [...keys, ...genres]) {
        expect(
          entry.value.containsKey(key),
          isTrue,
          reason: '${entry.key} missing "$key"',
        );
      }
    }
  });

  test(
    'unknown interface values fall back without dropping a real choice',
    () async {
      SharedPreferences.setMockInitialValues({
        'tintFromCover': false,
        'homeShelves': ['random', '-fresh', 'nope'],
      });
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      expect(settings.tintFromCover, isFalse);
      expect(settings.homeShelves.visible.first, 'random');
      expect(settings.homeShelves.visible, isNot(contains('fresh')));
      expect(settings.homeShelves.visible, contains('downloads'));

      final notifier = container.read(settingsProvider.notifier);
      await notifier.setTintFromCover(true);
      expect(container.read(settingsProvider).tintFromCover, isTrue);
      expect(preferences.getBool('tintFromCover'), isTrue);

      final shelves = HomeShelves.fromIds(const [
        '-recent',
        'downloads',
        'continue',
      ]);
      await notifier.setHomeShelves(shelves);
      expect(preferences.getStringList('homeShelves'), shelves.toIds());
      expect(
        container.read(settingsProvider).homeShelves.visible,
        shelves.visible,
      );
    },
  );

  test('home categories start with the ones most people keep', () {
    final categories = HomeCategories.fromIds(null);
    expect(categories.visible, [
      'comedy',
      'news',
      'society',
      'trueCrime',
      'education',
      'technology',
      'business',
      'health',
      'history',
    ]);
    expect(categories.order, HomeCategories.known);
    expect(HomeCategories.known, [
      for (final category in catalogCategories) category.id,
    ]);
    expect(categories.isOn('history'), isTrue);
    expect(categories.isOn('fiction'), isFalse);
    expect(categories.toIds(), contains('-fiction'));
    expect(catalogCategoryById('comedy')?.genre, 'Comedy');
    expect(catalogCategoryById('comedy')?.fyydId, 115);
    expect(catalogCategoryById('society')?.genre, 'Society & Culture');
    expect(
      HomeCategories.fromIds(const ['relax', '-sleep']).visible,
      categories.visible,
    );
    expect(HomeCategories.recognizes(null), isFalse);
    expect(HomeCategories.recognizes(const ['relax']), isFalse);
    expect(HomeCategories.recognizes(const ['comedy']), isTrue);
  });

  test('the month’s most played categories fill the home chips', () {
    final ranked = HomeCategories.fromPlayRanks(const [
      'sports',
      'music',
      'news',
      'comedy',
      'society',
      'tvFilm',
      'arts',
      'kids',
      'science',
    ]);
    expect(ranked.visible, [
      'sports',
      'music',
      'news',
      'comedy',
      'society',
      'tvFilm',
      'arts',
      'kids',
      'history',
    ]);
    expect(ranked.isOn('science'), isFalse);

    final withHistory = HomeCategories.fromPlayRanks(const [
      'news',
      'history',
      'comedy',
      'society',
      'education',
      'business',
      'health',
      'science',
    ]);
    expect(withHistory.visible, [
      'news',
      'history',
      'comedy',
      'society',
      'education',
      'business',
      'health',
      'science',
    ]);

    expect(
      rankPlayedCategories(const [
        'news',
        'news',
        'comedy',
        'society',
        'news',
        'comedy',
        'nope',
      ]),
      ['news', 'comedy', 'society'],
    );
    expect(
      catalogIdsFromAppleChart({
        'feed': {
          'entry': [
            {
              'category': {
                'attributes': {'im:id': '1531'},
              },
            },
            {
              'category': {
                'attributes': {'im:id': '1487'},
              },
            },
          ],
        },
      }),
      ['technology', 'history'],
    );
    expect(catalogIdFromGenreName('Music History'), 'music');
    expect(catalogIdFromGenreName('History'), 'history');

    final now = DateTime(2026, 10, 16, 12);
    final stored = writeMonthlyCategoryRanks(
      languages: const ['fr'],
      ranks: const ['news', 'comedy'],
      now: now,
    );
    expect(
      readMonthlyCategoryRanks(
        stored: stored,
        storedAtMillis: now.millisecondsSinceEpoch,
        languages: const ['fr'],
        now: now.add(const Duration(days: 6)),
      ),
      ['news', 'comedy'],
    );
    expect(
      readMonthlyCategoryRanks(
        stored: stored,
        storedAtMillis: now.millisecondsSinceEpoch,
        languages: const ['fr'],
        now: DateTime(2026, 11, 1),
      ),
      isNull,
    );
  });

  test('unknown category ids are ignored and missing ones stay visible', () {
    final stored = HomeCategories.fromIds(const [
      'technology',
      '-news',
      'nope',
      '-bogus',
      '-comedy',
    ]);
    expect(stored.visible.first, 'technology');
    expect(stored.visible, isNot(contains('news')));
    expect(stored.visible, isNot(contains('comedy')));
    expect(stored.toIds(), isNot(contains('nope')));
    expect(stored.toIds(), contains('-news'));
    expect(stored.visible, contains('education'));

    final hidden = stored.copyWith(
      enabled: {...stored.enabled}..remove('technology'),
    );
    expect(hidden.visible, isNot(contains('technology')));
    expect(hidden.toIds().first, '-technology');
  });

  test('missing interface preferences keep today’s behavior', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    final settings = container.read(settingsProvider);
    expect(settings.tintFromCover, isTrue);
    expect(settings.homeShelves.visible, HomeShelves.known);
    expect(
      settings.homeCategories.visible,
      HomeCategories.fromIds(null).visible,
    );
    expect(settings.homeCategoriesChosen, isFalse);
  });

  testWidgets('interface page stores tint and shelf order', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: AppearancePage()),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppearancePage)),
    );
    expect(container.read(settingsProvider).tintFromCover, isTrue);
    expect(find.text('Teinte de la pochette'), findsOneWidget);

    await tester.ensureVisible(find.text('Teinte de la pochette'));
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Teinte de la pochette'),
    );
    await tester.pump();
    expect(container.read(settingsProvider).tintFromCover, isFalse);
    expect(preferences.getBool('tintFromCover'), isFalse);

    await tester.ensureVisible(find.widgetWithText(ListTile, 'Étagères'));
    await tester.tap(find.widgetWithText(ListTile, 'Étagères'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Continuer d’écouter'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Les nouveautés'));
    await tester.pump();
    expect(
      container.read(settingsProvider).homeShelves.visible,
      isNot(contains('fresh')),
    );
    expect(preferences.getStringList('homeShelves'), contains('-fresh'));
    expect(container.read(settingsProvider).homeShelves.visible, [
      'continue',
      'favorites',
      'recent',
      'random',
      'preferred',
      'downloads',
    ]);
  });

  testWidgets('interface page stores the home categories', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          monthlyCategoryRanksProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: AppearancePage()),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppearancePage)),
    );
    expect(container.read(settingsProvider).homeCategoriesChosen, isFalse);
    expect(find.text('Catégories'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ListTile, 'Catégories'));
    await tester.tap(find.widgetWithText(ListTile, 'Catégories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Humour'), findsOneWidget);
    expect(find.text('Histoire'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Humour'));
    await tester.pump();
    expect(
      container.read(settingsProvider).homeCategories.visible,
      isNot(contains('comedy')),
    );
    expect(preferences.getStringList('homeCategories'), contains('-comedy'));
    expect(container.read(settingsProvider).homeCategories.visible, [
      'news',
      'society',
      'trueCrime',
      'education',
      'technology',
      'business',
      'health',
      'history',
    ]);
    expect(container.read(settingsProvider).homeCategoriesChosen, isTrue);
  });
}
