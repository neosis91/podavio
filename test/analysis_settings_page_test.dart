import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/analysis_overview.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/data/skip_segments.dart';
import 'package:podavio/ui/settings/analysis_settings_page.dart';
import 'package:podavio/ui/widgets/cover.dart';
import 'package:podavio/ui/settings/analysis_status_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('zero downloads stay hidden and one download is listed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final hidden = await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://example.com/empty.xml',
        title: 'Suivi sans fichier',
        author: 'Auteur',
        description: 'Description',
        episodes: [
          EpisodeDraft(
            guid: 'empty',
            title: 'Pas téléchargé',
            description: 'Notes',
            audioUrl: 'https://example.com/empty.mp3',
          ),
        ],
      ),
    );
    expect(hidden.podcastId, isPositive);

    final shownId = (await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://feeds.audiomeans.fr/show.xml',
        title: 'Un téléchargement',
        author: 'Auteur',
        description: 'Description',
        imageUrl: null,
        episodes: [
          EpisodeDraft(
            guid: 'one',
            title: 'Épisode',
            description: 'Notes',
            audioUrl: 'https://audio.audiomeans.fr/one.mp3',
          ),
        ],
      ),
    )).podcastId;
    final episode = (await database.episodesForPodcast(shownId)).single;
    await database.setDownloadPath(episode.id, '/tmp/one.mp3');
    final templateId = await database.insertSegmentTemplate(
      podcastId: shownId,
      kind: SkipSegmentKind.ad,
      durationMs: 15000,
      occurrences: 1,
    );
    await database.insertSkipSegment(
      episodeId: episode.id,
      startMs: 1000,
      endMs: 16000,
      kind: SkipSegmentKind.ad,
      source: SkipSegmentSource.manual,
      templateId: templateId,
    );
    await database.insertSegmentTemplate(
      podcastId: shownId,
      kind: SkipSegmentKind.ad,
      durationMs: 15000,
      occurrences: 3,
    );

    final secondId = (await database.saveFeed(
      const FeedDraft(
        feedUrl: 'https://feeds.audiomeans.fr/other.xml',
        title: 'Même hébergeur',
        author: 'Auteur',
        description: 'Description',
        episodes: [
          EpisodeDraft(
            guid: 'two',
            title: 'Autre',
            description: 'Notes',
            audioUrl: 'https://podcasts.audiomeans.fr/two.mp3',
          ),
        ],
      ),
    )).podcastId;
    final second = (await database.episodesForPodcast(secondId)).single;
    await database.setDownloadPath(second.id, '/tmp/two.mp3');
    await database.upsertEpisodeFingerprint(
      episodeId: second.id,
      data: Uint8List(0),
      hopMicros: 0,
    );
    await database.markFingerprintDone(second.id);

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
        child: const MaterialApp(home: AnalysisSettingsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(texts, contains('Gestion des analyses'));
    expect(texts, contains('Un téléchargement'));
    expect(texts, contains('Même hébergeur'));
    expect(texts.any((text) => text.contains('Suivi sans fichier')), isFalse);
    expect(texts.where((text) => text == 'Audiomeans'), hasLength(1));
    expect(texts.any((text) => text.contains('En attente')), isFalse);
    expect(texts.any((text) => text.contains('Analysé')), isFalse);
    expect(texts.any((text) => text.contains('Publicité')), isTrue);
    expect(texts.any((text) => text.contains('À la main')), isFalse);
    expect(find.text('1'), findsOneWidget);
    expect(texts.any((text) => text.contains('Rien n’est détecté')), isTrue);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    final covers = tester.widgetList<ListTile>(find.byType(ListTile)).where(
      (tile) => tile.leading is PodcastCover,
    );
    expect(covers, isNotEmpty);
    expect(
      covers.every(
        (tile) => tile.titleAlignment == ListTileTitleAlignment.center,
      ),
      isTrue,
    );
    final marks = tester
        .widgetList<AnalysisStatusMark>(find.byType(AnalysisStatusMark))
        .map((mark) => mark.status)
        .toList();
    expect(marks, contains(AnalysisOverviewStatus.pending));
    expect(marks, contains(AnalysisOverviewStatus.analysed));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
