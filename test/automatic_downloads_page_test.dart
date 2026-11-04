import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/models.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/automatic_downloads_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('subscribed podcasts get a check and a per-podcast limit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());

    final included = await _podcast(
      database,
      'https://example.com/a.xml',
      'Alpha',
    );
    final other = await _podcast(
      database,
      'https://example.com/b.xml',
      'Bravo',
      publishedAt: DateTime.utc(2026, 6, 1),
    );
    await _podcast(
      database,
      'https://example.com/c.xml',
      'Cache',
      subscribed: false,
    );

    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
        ],
        child: const MaterialApp(home: AutomaticDownloadsPage()),
      ),
    );
    await _frames(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Bravo')).dy),
    );
    expect(find.text('Cache'), findsNothing);
    expect(find.text('Limite : 1 épisode'), findsNWidgets(2));
    expect(find.byIcon(Icons.downloading), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(await _flag(database, included), isFalse);
    expect((await database.getPodcast(included))!.autoDownloadLimit, 1);

    Finder alphaMenu() {
      final alpha = find.ancestor(
        of: find.text('Alpha'),
        matching: find.byType(InkWell),
      );
      return find.descendant(of: alpha, matching: find.byType(IconButton));
    }

    await tester.tap(alphaMenu());
    await _frames(tester);
    expect(find.text('Téléchargement automatique'), findsNWidgets(2));
    expect(
      find.text(
        'Quand c’est activé, les épisodes non lus ou en cours les plus récents restent sur l’appareil, jusqu’à cette limite. Les épisodes déjà écoutés ne sont pas téléchargés.',
      ),
      findsOneWidget,
    );
    expect(find.text('Limite de téléchargement'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.tap(find.byType(Switch));
    await _frames(tester);
    expect(await _flag(database, included), isTrue);
    expect(await _flag(database, other), isFalse);
    expect(find.byIcon(Icons.downloading), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await _frames(tester);

    await tester.binding.setSurfaceSize(const Size(400, 520));
    await tester.pump();
    await tester.tap(find.text('Alpha'));
    await _frames(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('Limite de téléchargement'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('5 épisodes'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('5 épisodes'));
    await _frames(tester);
    expect((await database.getPodcast(included))!.autoDownloadLimit, 5);
    expect(find.text('Limite : 5 épisodes'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    await tester.pump();

    await tester.longPress(find.text('Alpha'));
    await _frames(tester);
    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.tap(find.text('Bravo'));
    await _frames(tester);
    await tester.tap(find.byTooltip('Actions'));
    await _frames(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Limite de téléchargement'), findsOneWidget);
    await tester.tap(find.text('Illimité'));
    await _frames(tester);

    expect((await database.getPodcast(included))!.autoDownloadLimit, isNull);
    expect((await database.getPodcast(other))!.autoDownloadLimit, isNull);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byTooltip('Actions'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await database.close();
  });
}

Future<int> _podcast(
  AppDatabase database,
  String url,
  String title, {
  bool subscribed = true,
  DateTime? publishedAt,
}) async {
  final saved = await database.saveFeed(
    FeedDraft(
      feedUrl: url,
      title: title,
      author: 'Auteur',
      description: 'Description',
      episodes: [
        EpisodeDraft(
          guid: '$title-1',
          title: 'Épisode',
          description: 'Notes',
          audioUrl: '$url/1.mp3',
          publishedAt: publishedAt,
        ),
      ],
    ),
    subscribed: subscribed,
  );
  return saved.podcastId;
}

Future<bool> _flag(AppDatabase database, int id) async {
  final podcast = await database.getPodcast(id);
  return podcast!.autoDownload;
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
