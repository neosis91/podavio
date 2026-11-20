import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/podcast/podcast_album_header.dart';
import 'package:podavio/ui/widgets/cover.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('la description se replie sur trois lignes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PodcastDescription(
            html: List.filled(
              30,
              'Une phrase assez longue pour déborder.',
            ).join(' '),
          ),
        ),
      ),
    );

    expect(find.text('Plus'), findsOneWidget);
    expect(find.text('Moins'), findsNothing);

    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();

    expect(find.text('Moins'), findsOneWidget);
    expect(find.text('Plus'), findsNothing);
  });

  testWidgets('une description courte ne propose pas Plus', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PodcastDescription(html: 'Une phrase courte.')),
      ),
    );

    expect(find.text('Une phrase courte.'), findsOneWidget);
    expect(find.text('Plus'), findsNothing);
  });

  testWidgets('la rangée d’actions reste aux proportions de l’album', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PodcastActionRow(
                showPause: false,
                onPlay: () {},
                reversed: true,
                onReverse: () {},
                subscribed: true,
                automaticDownload: true,
                onSubscribe: () {},
                onAutomaticDownload: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Lecture'), findsOneWidget);
    expect(find.byIcon(Icons.swap_vert), findsOneWidget);
    expect(find.byIcon(Icons.downloading), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.downloading)).color,
      const Color(0xff4CAF50),
    );
  });

  testWidgets('les boutons de la jaquette passent sous la barre d’état', (
    tester,
  ) async {
    final ratio = tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(top: 47 * ratio);
    tester.view.viewPadding = FakeViewPadding(top: 47 * ratio);
    addTearDown(tester.view.reset);

    late double consumed;
    late double inset;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(),
          body: Builder(
            builder: (context) {
              consumed = MediaQuery.viewPaddingOf(context).top;
              inset = statusBarInset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(consumed, 0);
    expect(inset, 47);
  });

  testWidgets('le titre du podcast est sous la pochette', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          podcastEpisodeCountProvider.overrideWith(
            (ref, id) => Stream.value(3),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 240,
                child: PodcastAlbumHeader(
                  podcast: Podcast(
                    id: 1,
                    feedUrl: 'https://example.com/feed.xml',
                    title: 'Sous la pochette',
                    titleFold: '',
                    author: 'Auteur',
                    description: '',
                    subscribedAt: DateTime(2025, 1, 1),
                    preferred: false,
                    autoDownload: false,
                    keepUpdated: true,
                    episodeNotification: false,
                    subscribed: true,
                    skipIntroSeconds: 0,
                    skipOutroSeconds: 0,
                    personsJson: '[]',
                    fundingJson: '[]',
                    autoSkipAds: false,
                    autoSkipKinds: '[]',
                  ),
                  showPause: false,
                  onPlay: () {},
                  onBack: () {},
                  onMore: () {},
                  onReverse: () {},
                  reversed: false,
                  onAutomaticDownload: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cover = tester.getRect(find.byType(PodcastCover));
    final title = tester.getRect(find.text('Sous la pochette'));
    expect(title.top, greaterThanOrEqualTo(cover.bottom));
    expect(find.text('3 épisodes'), findsOneWidget);
  });
}
