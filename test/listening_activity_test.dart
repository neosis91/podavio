import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/core/theme.dart';
import 'package:podavio/data/listening_activity.dart';
import 'package:podavio/ui/stats_activity_tab.dart';

void main() {
  final tuesday = DateTime(2026, 11, 3);
  final monday = DateTime(2026, 11, 2);

  ListeningActivity sample() {
    return buildListeningActivity([
      ListenSample(
        at: monday.add(const Duration(hours: 8)),
        seconds: 60,
        categories: const ['Comédie'],
      ),
      ListenSample(
        at: tuesday.add(const Duration(hours: 9)),
        seconds: 360,
        categories: const ['Comédie', 'Society'],
      ),
    ], now: tuesday.add(const Duration(hours: 18)));
  }

  test('a week in progress keeps future days out of the calmest list', () {
    final activity = sample();

    expect(activity.totalSeconds, 420);
    expect(activity.dailyStreak, 2);
    expect(activity.weeklyStreak, 1);
    expect(activity.weekExtremes.busiest, [1]);
    expect(activity.weekExtremes.calmest, [0]);
    expect(activity.weekDayIsFuture(2), isTrue);
    expect(activity.yearExtremes.busiest, [10]);
    expect(activity.yearExtremes.calmest, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    expect(activity.yearExtremes.calmest, isNot(contains(11)));
    expect(activity.semesterStartMonth, 7);
    expect(activity.semesterEndMonth, 12);
    expect(activity.semesterSeconds, 420);
    expect(activity.categories.single.name, 'Comédie');
    expect(activity.weekdayExtremes.busiest, [1]);
    expect(activity.weekdayExtremes.calmest, [0, 2, 3, 4, 5, 6]);
  });

  test('yesterday still counts, the day before does not', () {
    final today = DateTime(2026, 11, 5);
    final activity = buildListeningActivity([
      ListenSample(at: DateTime(2026, 11, 4, 12), seconds: 30),
      ListenSample(at: DateTime(2026, 11, 2, 12), seconds: 30),
    ], now: today);

    expect(activity.dailyStreak, 1);
    expect(activity.weeklyStreak, 1);
  });

  test('a missed week ends the weekly streak', () {
    final activity = buildListeningActivity([
      ListenSample(at: DateTime(2026, 10, 20, 12), seconds: 30),
    ], now: DateTime(2026, 11, 3));

    expect(activity.dailyStreak, 0);
    expect(activity.weeklyStreak, 0);
  });

  test('the first half of the year is its own heatmap', () {
    final activity = buildListeningActivity([
      ListenSample(at: DateTime(2026, 3, 4, 12), seconds: 90),
    ], now: DateTime(2026, 3, 4));

    expect(activity.semesterStartMonth, 1);
    expect(activity.semesterEndMonth, 6);
    expect(activity.semesterSeconds, 90);
    expect(
      activity.semesterWeeks.any(
        (week) => week.days.any((day) => day?.day == DateTime(2026, 3, 4)),
      ),
      isTrue,
    );
    expect(
      activity.semesterWeeks.any(
        (week) => week.days.any((day) => day?.day.month == 7),
      ),
      isFalse,
    );
  });

  testWidgets('the activity tab follows the listening summary', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(AppAccent.podavio),
        home: Scaffold(body: ActivityTab(activity: sample())),
      ),
    );

    expect(find.text('7 minutes'), findsWidgets);
    expect(find.text('Commencez votre aventure !'), findsNothing);
    expect(find.text('2 jours'), findsOneWidget);
    expect(find.text('1 semaine'), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.text('mardi'), findsOneWidget);
    expect(find.text('lundi'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Cette année'), 200);
    expect(find.text('novembre'), findsOneWidget);
    expect(find.textContaining('janvier, février'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Catégories les plus populaires'),
      200,
    );
    expect(find.textContaining('juil.-déc.'), findsOneWidget);
    expect(find.text('Comédie'), findsOneWidget);
    expect(find.text('Mardi'), findsOneWidget);
    expect(
      find.text('Lundi, Mercredi, Jeudi, Vendredi, Samedi, Dimanche'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(find.text('Temps total d’écoute'), 200);
    await tester.tap(find.text('Temps total d’écoute'));
    await tester.pumpAndSettle();
    expect(find.text('Novembre 2026'), findsOneWidget);
  });

  testWidgets('an empty activity invites the first streak', (tester) async {
    final activity = buildListeningActivity(
      const [],
      now: DateTime(2026, 11, 3),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(AppAccent.podavio),
        home: Scaffold(body: ActivityTab(activity: activity)),
      ),
    );

    expect(find.text('Commencez votre aventure !'), findsOneWidget);
    expect(find.text('0 jour'), findsOneWidget);
    expect(find.text('0 semaine'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });
}
