import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/audio_analysis.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/data/skip_segments.dart';
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

  testWidgets('low-confidence intra-episode candidates stay behind show more', (
    tester,
  ) async {
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
            title: 'Episode pub',
            description: 'Notes',
            audioUrl: 'https://example.com/a.mp3',
          ),
        ],
      ),
    )).podcastId;
    final episodeId = (await database.episodesForPodcast(podcastId)).single.id;
    await database.insertSkipSegment(
      episodeId: episodeId,
      startMs: 40000,
      endMs: 69000,
      kind: SkipSegmentKind.ad,
      source: SkipSegmentSource.fingerprint,
      matches: 3,
      confidence: 90,
    );
    final templateId = await database.insertSegmentTemplate(
      podcastId: podcastId,
      kind: SkipSegmentKind.other,
      label: 'Refrain',
      durationMs: 18000,
      occurrences: 1,
      confidence: 20,
    );
    await database.insertSkipSegment(
      episodeId: episodeId,
      startMs: 10000,
      endMs: 28000,
      kind: SkipSegmentKind.other,
      source: SkipSegmentSource.fingerprint,
      matches: 1,
      confirmed: false,
      confidence: 20,
      templateId: templateId,
    );

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

    expect(find.text('Episode pub'), findsOneWidget);
    expect(find.text('Refrain'), findsNothing);
    expect(find.text('Afficher les passages incertains (1)'), findsOneWidget);

    await tester.tap(find.text('Afficher les passages incertains (1)'));
    await tester.pump();

    expect(find.text('Refrain'), findsOneWidget);
    expect(find.text('Masquer les passages incertains'), findsOneWidget);
    expect(find.text('Episode pub'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('the analysis line names the episode and the current step', (
    tester,
  ) async {
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
            title: 'Un',
            description: 'Notes',
            audioUrl: 'https://example.com/a.mp3',
          ),
        ],
      ),
    )).podcastId;
    final episodeId = (await database.episodesForPodcast(podcastId)).single.id;
    final progress = AudioAnalysisProgress(
      runningEpisodeId: episodeId,
      runningPodcastId: podcastId,
      runningDurationSeconds: 600,
      runningSince: DateTime.now().subtract(const Duration(seconds: 5)),
      step: AnalysisStep.decoding,
      stepAt: DateTime.now(),
      pending: [
        (episodeId: episodeId + 1, podcastId: podcastId, durationSeconds: 600),
      ],
    );

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
          audioAnalysisProvider.overrideWith(() => _FixedAnalysis(progress)),
        ],
        child: MaterialApp(home: SkipClassificationPage(podcastId: podcastId)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Analyse en cours (2 restants)'), findsOneWidget);
    expect(find.text('Décodage de l’audio de Un'), findsOneWidget);
    expect(find.text('Environ 3 min'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _FixedAnalysis extends AudioAnalysisController {
  _FixedAnalysis(this.progress);

  final AudioAnalysisProgress progress;

  @override
  AudioAnalysisProgress build() => progress;
}
