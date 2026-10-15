import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/ui/widgets/startup_splash.dart';

void main() {
  testWidgets('le logo du démarrage s’efface ensuite', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: StartupSplash(child: Text('accueil'))),
    );

    expect(find.byKey(const Key('startup-splash')), findsOneWidget);
    expect(find.text('accueil'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('startup-splash')), findsNothing);
    expect(find.text('accueil'), findsOneWidget);
  });
}
