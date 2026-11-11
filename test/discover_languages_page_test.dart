import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/discover_languages_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search highlights a language like the subscriptions page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: DiscoverLanguagesPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Toutes les langues'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.byIcon(Icons.search), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'alban');
    await tester.pump();

    expect(find.text('Albanais'), findsOneWidget);
    expect(find.text('Allemand'), findsNothing);

    final marks = <TextSpan>[];
    void collect(InlineSpan span) {
      if (span is TextSpan) {
        if (span.style?.backgroundColor != null) marks.add(span);
        for (final child in span.children ?? const <InlineSpan>[]) {
          collect(child);
        }
      }
    }

    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      collect(rich.text);
    }
    expect(marks.map((span) => span.text), ['Alban']);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Allemand'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}
