import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:podavio/data/app_database.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/router.dart';
import 'package:podavio/ui/settings_page.dart';
import 'package:podavio/ui/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a desktop window shows every menu entry', (tester) async {
    final database = await _pumpShell(tester, const Size(1280, 720));

    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('Favoris'), findsOneWidget);
    expect(find.text('Téléchargements'), findsOneWidget);
    expect(find.text('Préférences'), findsOneWidget);
    expect(find.text('Plus'), findsNothing);

    await _close(tester, database);
  });

  testWidgets('the panel follows the saved page order', (tester) async {
    final database = await _pumpShell(
      tester,
      const Size(400, 700),
      stored: {
        'navOrder': [
          AppRoutes.downloads,
          AppRoutes.history,
          AppRoutes.favorites,
          AppRoutes.preferences,
          AppRoutes.home,
          AppRoutes.episodes,
          AppRoutes.queue,
          AppRoutes.podcasts,
          AppRoutes.discover,
        ],
      },
    );

    expect(find.text('Téléchargements'), findsOneWidget);
    expect(find.text('Préférences'), findsOneWidget);
    expect(find.text('Accueil'), findsNothing);
    expect(find.text('Plus'), findsOneWidget);

    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);

    await _close(tester, database);
  });

  testWidgets('a narrow window keeps the overflow in Plus', (tester) async {
    final database = await _pumpShell(tester, const Size(400, 700));

    expect(find.text('Abonnements'), findsOneWidget);
    expect(find.text('Explorer'), findsNothing);
    expect(find.text('Plus'), findsOneWidget);

    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();

    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('Téléchargements'), findsOneWidget);
    expect(find.text('Préférences'), findsOneWidget);

    await _close(tester, database);
  });

  testWidgets('the panel order dialog lists every page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
        ],
        child: const MaterialApp(home: AppearancePage()),
      ),
    );
    await tester.pump();

    expect(find.text('Thème'), findsOneWidget);
    expect(find.text('Préférences du volet'), findsOneWidget);

    await tester.tap(find.text('Ordre des pages'));
    await tester.pumpAndSettle();

    expect(find.text('Ordre des pages'), findsWidgets);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Épisodes'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);

    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    await _close(tester, database);
  });
}

Future<AppDatabase> _pumpShell(
  WidgetTester tester,
  Size size, {
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final preferences = await SharedPreferences.getInstance();
  final database = AppDatabase(NativeDatabase.memory());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const SizedBox.shrink(),
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
