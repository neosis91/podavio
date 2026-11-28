import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/podcast/episode_analysis_page.dart';
import 'package:podavio/ui/settings/analysis_status_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an episode unfolds into the analysis steps', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final podcastId = (await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: 'Description',
        episodes: [
          EpisodeDraft(
            guid: 'a',
            title: 'Episode long',
            description: 'Notes',
            audioUrl: 'https://example.com/a.mp3',
          ),
        ],
      ),
    )).podcastId;
    final episodeId = (await database.episodesForPodcast(podcastId)).single.id;
    await database.setDownloadPath(episodeId, '/tmp/episode.mp3');

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
        ],
        child: MaterialApp(home: EpisodeAnalysisPage(podcastId: podcastId)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Episode long'), findsOneWidget);
    expect(find.text('Décodage de l’audio'), findsNothing);

    await tester.tap(find.text('Episode long'));
    await tester.pumpAndSettle();

    expect(find.text('Préparation de l’épisode'), findsOneWidget);
    expect(find.text('Décodage de l’audio'), findsOneWidget);
    expect(find.text('Enregistrement de l’empreinte'), findsOneWidget);
    expect(find.text('Comparaison des épisodes'), findsOneWidget);
    expect(find.byType(AnalysisStatusMark), findsWidgets);
  });
}
