import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/app_release.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/activity_notices.dart';
import 'package:podavio/ui/more_page.dart';
import 'package:podavio/ui/router.dart';
import 'package:podavio/ui/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final newer = AppRelease(
    version: '2026.12.0',
    date: DateTime.utc(2026, 12, 1),
    notes: const ['Une note de publication'],
  );

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  testWidgets(
    'shows the update dialog when a newer release is found at startup',
    (tester) async {
      final database = await _pumpShell(
        tester,
        checker: () async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return AppUpdateNewer(newer);
        },
      );

      expect(find.text('Mise à jour disponible'), findsNothing);

      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump();
      await tester.pump();

      expect(find.text('Mise à jour disponible'), findsOneWidget);
      expect(find.text('La version 2026.12.0 est disponible.'), findsOneWidget);
      expect(find.text('• Une note de publication'), findsOneWidget);
      expect(find.text('Télécharger'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);

      await _close(tester, database);
    },
  );

  testWidgets('shows the update dialog after checking the version', (
    tester,
  ) async {
    AppUpdateLookup lookup = const AppUpdateCurrent();
    final database = await _pumpShell(
      tester,
      location: AppRoutes.about,
      checker: () async => lookup,
    );
    await tester.pump();

    expect(find.text('Mise à jour disponible'), findsNothing);

    lookup = AppUpdateNewer(newer);
    await tester.tap(find.text('Vérifier la mise à jour de l’application'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Mise à jour disponible'), findsOneWidget);
    expect(find.text('La version 2026.12.0 est disponible.'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Mise à jour disponible'), findsNothing);

    await _close(tester, database);
  });

  testWidgets('a current version does not open the update dialog', (
    tester,
  ) async {
    final database = await _pumpShell(
      tester,
      location: AppRoutes.about,
      checker: () async => const AppUpdateCurrent(),
    );
    await tester.pump();

    await tester.tap(find.text('Vérifier la mise à jour de l’application'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Mise à jour disponible'), findsNothing);
    await tester.tap(find.byType(ActivityButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Podavio est à jour'), findsOneWidget);

    await _close(tester, database);
  });
}

Future<AppDatabase> _pumpShell(
  WidgetTester tester, {
  required Future<AppUpdateLookup> Function() checker,
  String location = AppRoutes.home,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final database = AppDatabase(NativeDatabase.memory());
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: location,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: AppRoutes.library,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: AppRoutes.discover,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: AppRoutes.about,
            builder: (context, state) => const AboutPage(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(database),
        appUpdateCheckerProvider.overrideWithValue(checker),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return database;
}

Future<void> _close(WidgetTester tester, AppDatabase database) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  await database.close();
}
