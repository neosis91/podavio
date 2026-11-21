import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/audio_analysis.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/podcast/skip_classification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the page explains the two-episode minimum and offers analysis', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    final podcastId = (await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/feed.xml',
        title: 'Essai',
        author: 'Auteur',
        description: 'Description',
        episodes: [
          EpisodeDraft(
            guid: 'a',
            title: 'Un',
            description: 'Notes',
            audioUrl: 'https://example.com/a.mp3',
          ),
        ],
      ),
    )).podcastId;

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
          podcastAnalysisKickProvider.overrideWith((ref, id) {}),
        ],
        child: MaterialApp(home: SkipClassificationPage(podcastId: podcastId)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    if (!texts.contains('Analyser les épisodes téléchargés')) {
      throw StateError('bouton manquant: $texts');
    }
    if (!texts.contains(
      'Il faut au moins deux épisodes téléchargés du même podcast pour repérer les pubs et les jingles répétés.',
    )) {
      throw StateError('explication manquante');
    }
    if (!texts.contains(
      'Un titre de chapitre qui ressemble à une pub est quand même proposé.',
    )) {
      throw StateError('chapitres manquants');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
