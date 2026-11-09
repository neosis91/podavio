import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/ui/podcast/podcast_album_header.dart';

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

  test('la rampe de la jaquette s’adoucit vers le bas', () {
    const color = Color(0xFF224466);
    final gradient = artworkScrim(color);
    expect(gradient.colors.first, color.withValues(alpha: 0));
    expect(gradient.colors.last, color);
    // t = 6/24 = 0,25 → t² (3 − 2t) = 0,15625, sous la rampe droite.
    expect(gradient.colors[6].a, closeTo(0.15625, 0.002));
    expect(gradient.colors[12].a, closeTo(0.5, 0.002));
  });
}
