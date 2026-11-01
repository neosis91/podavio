import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the browser marks are the real svg logos', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    const names = [
      'browsers/chrome',
      'browsers/chromium',
      'browsers/firefox',
      'browsers/safari',
      'browsers/edge',
      'browsers/opera',
      'browsers/brave',
      'browsers/samsung',
      'browsers/vivaldi',
      'os/linux',
      'os/windows',
      'os/apple',
      'os/android',
      'os/chromeos',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          children: [
            for (final name in names)
              SvgPicture.asset('assets/brand/$name.svg', width: 48, height: 48),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsNWidgets(names.length));
  });
}
