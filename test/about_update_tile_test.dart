import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:podavio/data/app_release.dart';
import 'package:podavio/data/providers.dart';
import 'package:podavio/ui/more_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the last application update check under the row', (
    tester,
  ) async {
    await initializeDateFormatting('fr');
    Intl.defaultLocale = 'fr';
    final checkedAt = DateTime(2026, 10, 15, 17, 39);
    SharedPreferences.setMockInitialValues({
      appUpdateCheckedAtKey: checkedAt.millisecondsSinceEpoch,
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: AboutPage()),
      ),
    );
    await tester.pump();

    expect(
      find.text('Vérifier la mise à jour de l’application'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Lecteur de podcasts pour Android, iOS, Windows, macOS et Linux.',
      ),
      findsNothing,
    );
    final when = DateFormat.yMMMd().add_Hm().format(checkedAt);
    expect(find.text('Dernière vérification : $when'), findsOneWidget);
  });

  testWidgets('says when the application update was never checked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: AboutPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Aucune vérification'), findsOneWidget);
  });
}
