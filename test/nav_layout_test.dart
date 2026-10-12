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

  testWidgets('phone and desktop keep the SimpMusic destinations', (
    tester,
  ) async {
    final database = await _pumpShell(tester, const Size(400, 700));

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Abonnements'), findsOneWidget);
    expect(find.text('Bibliothèque'), findsOneWidget);
    expect(find.text('Explorer'), findsNothing);
    expect(find.byTooltip('Explorer'), findsOneWidget);
    expect(find.text('Plus'), findsNothing);
    expect(find.text('Épisodes'), findsNothing);

    await _close(tester, database);

    final wide = await _pumpShell(tester, const Size(800, 720));
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Abonnements'), findsOneWidget);
    expect(find.text('Bibliothèque'), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Préférences'), findsNothing);
    await _close(tester, wide);
  });

  testWidgets('appearance no longer reorders the navigation', (tester) async {
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

    expect(find.text('Thème'), findsNothing);
    expect(find.text('Apparence'), findsOneWidget);
    expect(find.text('Ordre des pages'), findsNothing);
    expect(find.text('Préférences du volet'), findsNothing);

    await _close(tester, database);
  });
}

Future<AppDatabase> _pumpShell(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
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
          GoRoute(
            path: AppRoutes.library,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: AppRoutes.discover,
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
