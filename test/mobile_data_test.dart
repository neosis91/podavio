import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/activity_messages.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/online_status.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/episodes_page.dart';
import 'package:podavio/ui/root_navigator.dart';
import 'package:podavio/ui/widgets/mobile_data_prompt.dart';
import 'package:podavio/ui/widgets/episode_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('wifi or ethernet is not mobile data, even with a vpn', () {
    expect(
      connectionUsesMobileData(wifi: true, ethernet: false, mobile: false),
      isFalse,
    );
    expect(
      connectionUsesMobileData(wifi: true, ethernet: false, mobile: true),
      isFalse,
    );
    expect(
      connectionUsesMobileData(wifi: false, ethernet: true, mobile: true),
      isFalse,
    );
    expect(
      connectionUsesMobileData(wifi: false, ethernet: false, mobile: false),
      isFalse,
    );
  });

  test('cellular and satellite block an unconfirmed download', () {
    expect(
      connectionUsesMobileData(wifi: false, ethernet: false, mobile: true),
      isTrue,
    );
    expect(
      mobileDataBlocksDownload(allowMobileData: false, mobileDataActive: true),
      isTrue,
    );
    expect(
      mobileDataBlocksDownload(allowMobileData: true, mobileDataActive: true),
      isFalse,
    );
    expect(
      mobileDataBlocksDownload(allowMobileData: false, mobileDataActive: false),
      isFalse,
    );
  });

  testWidgets('a manual download on mobile data asks before it starts', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final saved = await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/show.xml',
        title: 'Essai',
        author: 'Auteur',
        description: '',
        episodes: [
          EpisodeDraft(
            guid: 'ep-1',
            title: 'Un',
            description: '',
            audioUrl: 'https://example.com/1.mp3',
          ),
        ],
      ),
    );
    final stored = await database.episodesForPodcast(saved.podcastId);
    final entry = await database.getEpisode(stored.single.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
          mobileDataProbeProvider.overrideWithValue(() async => true),
        ],
        child: MaterialApp(home: Scaffold(body: _Download(entry!))),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Ce téléchargement utilisera les données mobiles.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Utiliser le Wi-Fi et le réseau mobile pour les prochains téléchargements',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Épisode téléchargé'), findsNothing);
    expect(preferences.getBool('allowMobileData'), isNot(true));

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Télécharger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(preferences.getBool('allowMobileData'), isTrue);
  });

  testWidgets('a refresh on mobile data asks before it starts', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
          mobileDataProbeProvider.overrideWithValue(() async => true),
          onlineStatusProvider.overrideWith(_Online.new),
        ],
        child: const MaterialApp(home: Scaffold(body: _Refresh())),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Cette actualisation utilisera les données mobiles.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Utiliser le Wi-Fi et le réseau mobile pour les prochaines actualisations',
      ),
      findsOneWidget,
    );
    expect(find.text('Actualiser'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(preferences.getBool('allowMobileRefresh'), isNot(true));

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Actualiser'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(preferences.getBool('allowMobileRefresh'), isTrue);
  });

  testWidgets('a recent refresh does not ask to use mobile data', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'lastFeedRefreshAtMs': DateTime.now().millisecondsSinceEpoch,
      'refreshIntervalMinutes': 15,
    });
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
          mobileDataProbeProvider.overrideWithValue(() async => true),
          onlineStatusProvider.overrideWith(_Online.new),
        ],
        child: const MaterialApp(home: Scaffold(body: _Refresh())),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Cette actualisation utilisera les données mobiles.'),
      findsNothing,
    );
    expect(preferences.getBool('allowMobileRefresh'), isNot(true));
    final messages = ProviderScope.containerOf(tester.element(find.text('go')))
        .read(activityMessagesProvider);
    expect(messages.single.text, contains('Actualisation récente'));
  });

  testWidgets('the stream prompt opens from the focused screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('page'))),
    );
    expect(rootNavigatorKey.currentContext, isNull);

    final result = confirmMobileDataFromRoot(
      message: 'This stream will use mobile data.',
      actionLabel: 'Play',
      rememberLabel: 'Use Wi-Fi and mobile data for future streaming',
    );
    await tester.pump();

    expect(
      find.text('Cette lecture utilisera les données mobiles.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(await result, (accepted: false, allowFuture: false));
  });
}

class _Online extends OnlineStatusNotifier {
  @override
  bool? build() => true;
}

class _Refresh extends ConsumerWidget {
  const _Refresh();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => refreshSubscriptions(context, ref),
      child: const Text('go'),
    );
  }
}

class _Download extends ConsumerWidget {
  const _Download(this.entry);

  final EpisodeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () =>
          runEpisodeAction(context, ref, entry, EpisodeMenuAction.download),
      child: const Text('go'),
    );
  }
}
