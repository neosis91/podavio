import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/audio_analysis.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/data/segment_edit.dart';
import 'package:podavio/data/skip_segments.dart';
import 'package:podavio/ui/podcast/skip_classification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the page explains that only hand-made passages are searched', (
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
    if (!texts.any((text) => text.startsWith('Aucune portion créée'))) {
      throw StateError('explication manquante');
    }
    if (texts.any((text) => text.contains('titre de chapitre'))) {
      throw StateError('les chapitres ne sont plus proposés');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('old detected passages are hidden, hand-made ones are listed', (
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
    final detected = await database.insertSegmentTemplate(
      podcastId: podcastId,
      kind: SkipSegmentKind.other,
      label: 'Refrain',
      durationMs: 18000,
    );
    await database.insertSkipSegment(
      episodeId: episodeId,
      startMs: 10000,
      endMs: 28000,
      kind: SkipSegmentKind.other,
      source: SkipSegmentSource.fingerprint,
      templateId: detected,
    );
    await createManualSegment(
      database,
      episodeId: episodeId,
      startMs: 100000,
      endMs: 115000,
      kind: SkipSegmentKind.intro,
      label: 'Générique',
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

    expect(find.text('Générique'), findsOneWidget);
    expect(find.text('Refrain'), findsNothing);
    expect(find.text('Episode pub'), findsNothing);
    expect(await database.listSkipSegments(episodeId), hasLength(3));

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
