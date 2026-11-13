import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/widgets/episode_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bulk sheet shows played actions only when they apply', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final prepared = await tester.runAsync(() async {
      final podcastId = (await database.saveFeed(
        const FeedDraft(
          feedUrl: 'https://example.com/feed.xml',
          title: 'Essai',
          author: 'Auteur',
          description: '',
          episodes: [
            EpisodeDraft(
              guid: 'unread',
              title: 'Non lu',
              description: '',
              audioUrl: 'https://example.com/unread.mp3',
              durationSeconds: 60,
            ),
            EpisodeDraft(
              guid: 'read',
              title: 'Déjà lu',
              description: '',
              audioUrl: 'https://example.com/read.mp3',
              durationSeconds: 60,
            ),
          ],
        ),
      )).podcastId;
      final entries = await database.watchEpisodes(podcastId: podcastId).first;
      final unread = entries.firstWhere((e) => e.episode.guid == 'unread');
      final read = entries.firstWhere((e) => e.episode.guid == 'read');
      await database.setPlayed(read.episode.id, played: true);
      final played = (await database.getEpisode(read.episode.id))!;
      return (entries: entries, unread: unread, played: played);
    });
    final entries = prepared!.entries;
    final unread = prepared.unread;
    final played = prepared.played;

    Future<void> pump(List<EpisodeEntry> selected) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            databaseProvider.overrideWithValue(database),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: EpisodeSelectionAppBar(
                session: EpisodeSelectionSession(
                  selectedCount: selected.length,
                  totalCount: entries.length,
                  selected: selected,
                  onClose: () {},
                  onSelectAll: () {},
                  onDeselectAll: () {},
                  bulkActions: const EpisodeBulkActions(favorite: true),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openSheet() async {
      await tester.tap(find.byTooltip('Actions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await pump([unread, played]);
    await openSheet();
    expect(find.text('Marquer comme lu'), findsOneWidget);
    expect(find.text('Marquer comme non lu'), findsOneWidget);

    await tester.tap(find.text('Marquer comme lu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final nowRead = (await tester.runAsync(
      () => database.getEpisode(unread.episode.id),
    ))!;
    expect(nowRead.episode.played, isTrue);
    final stillRead = (await tester.runAsync(
      () => database.getEpisode(played.episode.id),
    ))!;
    expect(stillRead.episode.played, isTrue);

    await pump([nowRead]);
    await openSheet();
    expect(find.text('Marquer comme lu'), findsNothing);
    expect(find.text('Marquer comme non lu'), findsOneWidget);

    await tester.tap(find.text('Marquer comme non lu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final freshUnread = (await tester.runAsync(
      () => database.getEpisode(nowRead.episode.id),
    ))!;
    expect(freshUnread.episode.played, isFalse);

    await pump([freshUnread]);
    await openSheet();
    expect(find.text('Marquer comme lu'), findsOneWidget);
    expect(find.text('Marquer comme non lu'), findsNothing);
  });
}
