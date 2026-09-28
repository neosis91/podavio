import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:podavio/core/format.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  test('formatClock renders hours, minutes and seconds', () {
    expect(formatClock(const Duration(seconds: 65)), '1:05');
    expect(
      formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(formatClock(const Duration(seconds: -4)), '0:00');
  });

  test('plainText strips markup', () {
    expect(plainText('<p>Bonjour&nbsp;<b>monde</b></p>'), 'Bonjour monde');
  });

  test('plainText keeps line breaks', () {
    expect(
      plainText('<p>Premier paragraphe.</p><p>Deuxième<br>ligne</p>'),
      'Premier paragraphe.\n\nDeuxième\nligne',
    );
    expect(
      plainText('<p>Phrase\ncoupée dans le flux.</p>'),
      'Phrase coupée dans le flux.',
    );
    expect(plainText('Une ligne\n\nUne autre'), 'Une ligne\n\nUne autre');
    expect(plainText('<ul><li>Un</li><li>Deux</li></ul>'), '• Un\n• Deux');
  });

  test('audioExtension prefers the mime type', () {
    expect(audioExtension('audio/mpeg', 'https://cdn.example/a'), '.mp3');
    expect(audioExtension(null, 'https://cdn.example/a.m4a'), '.m4a');
    expect(audioExtension(null, 'https://cdn.example/a'), '.mp3');
  });

  test('formatDate uses relative labels', () {
    final now = DateTime.now();
    expect(formatDate(now), "Aujourd'hui");
    expect(formatDate(now.subtract(const Duration(days: 1))), 'Hier');
  });
}
