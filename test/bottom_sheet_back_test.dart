import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:podavio/ui/widgets/app_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the back button closes the foreground sheet and keeps the page',
    (tester) async {
      final harness = await _Harness.open(tester);
      addTearDown(harness.close);
      await harness.openSheet(tester);

      final back = tester.element(find.byType(BackButton));
      Navigator.of(back).maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Feuille'), findsNothing);
      expect(find.text('Page détail'), findsOneWidget);
    },
  );

  testWidgets('context.pop closes the foreground sheet and keeps the page', (
    tester,
  ) async {
    final harness = await _Harness.open(tester);
    addTearDown(harness.close);
    await harness.openSheet(tester);

    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Retour'))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Feuille'), findsNothing);
    expect(find.text('Page détail'), findsOneWidget);
  });

  testWidgets(
    'the system back closes the foreground sheet and keeps the page',
    (tester) async {
      final harness = await _Harness.open(tester);
      addTearDown(harness.close);
      await harness.openSheet(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Feuille'), findsNothing);
      expect(find.text('Page détail'), findsOneWidget);
    },
  );

  testWidgets('back closes only the top sheet', (tester) async {
    final harness = await _Harness.open(tester);
    addTearDown(harness.close);
    await harness.openSheet(tester);
    await tester.tap(find.text('Ouvrir encore'));
    await tester.pumpAndSettle();
    expect(find.text('Feuille du dessus'), findsOneWidget);

    final back = tester.element(find.byType(BackButton));
    Navigator.of(back).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Feuille du dessus'), findsNothing);
    expect(find.text('Feuille'), findsOneWidget);
    expect(find.text('Page détail'), findsOneWidget);
  });

  testWidgets('back does not close a sheet covered by a dialog', (
    tester,
  ) async {
    final harness = await _Harness.open(tester);
    addTearDown(harness.close);
    await harness.openSheet(tester);
    showDialog<void>(
      context: harness.router.routerDelegate.navigatorKey.currentContext!,
      builder: (context) => const AlertDialog(title: Text('Dialogue')),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Dialogue'), findsNothing);
    expect(find.text('Feuille'), findsOneWidget);
  });

  testWidgets('popForegroundBottomSheet ignores a route that is not a sheet', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: navigator,
          onGenerateRoute: (settings) =>
              MaterialPageRoute<void>(builder: (context) => const Text('Page')),
        ),
      ),
    );

    expect(popForegroundBottomSheet(navigator.currentState!), isFalse);
    expect(find.text('Page'), findsOneWidget);

    showDialog<void>(
      context: navigator.currentContext!,
      builder: (context) => const AlertDialog(title: Text('Dialogue')),
    );
    await tester.pumpAndSettle();

    expect(popForegroundBottomSheet(navigator.currentState!), isFalse);
    expect(find.text('Dialogue'), findsOneWidget);
    expect(
      foregroundRoute(navigator.currentState!),
      isNot(isA<ModalBottomSheetRoute<dynamic>>()),
    );
  });
}

class _Harness {
  _Harness(this.router);

  final GoRouter router;

  static Future<_Harness> open(WidgetTester tester) async {
    final router = GoRouter(
      observers: [sheetBackObserver],
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => child,
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => context.push('/detail'),
                    child: const Text('Aller au détail'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/detail',
              builder: (context, state) => Scaffold(
                appBar: AppBar(title: const Text('Détail')),
                body: Builder(
                  builder: (context) => Column(
                    children: [
                      const Text('Page détail'),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Retour'),
                      ),
                      TextButton(
                        onPressed: () => showAppModalBottomSheet<void>(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Feuille'),
                              TextButton(
                                onPressed: () => showAppModalBottomSheet<void>(
                                  context: context,
                                  builder: (context) =>
                                      const Text('Feuille du dessus'),
                                ),
                                child: const Text('Ouvrir encore'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('Ouvrir'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aller au détail'));
    await tester.pumpAndSettle();
    return _Harness(router);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Feuille'), findsOneWidget);
  }

  Future<void> close() async {
    router.dispose();
  }
}
