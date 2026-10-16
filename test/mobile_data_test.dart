import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/online_status.dart';
import 'package:podavio/data/providers.dart';
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
    await tester.tap(find.text('Annuler'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Épisode téléchargé'), findsNothing);
  });
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
