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

  test('showNotesSpans keeps anchor links', () {
    final spans = showNotesSpans(
      '<p>Voir <a href="https://example.com/a">le site</a> ici.</p>',
    );
    expect(spans, hasLength(3));
    expect(spans[0].text, 'Voir ');
    expect(spans[0].url, isNull);
    expect(spans[1].text, 'le site');
    expect(spans[1].url, 'https://example.com/a');
    expect(spans[2].text, ' ici.');
  });

  test('showNotesSpans detects bare urls', () {
    final spans = showNotesSpans('Écoute sur https://example.com/x.');
    expect(spans, hasLength(3));
    expect(spans[0].text, 'Écoute sur ');
    expect(spans[1].url, 'https://example.com/x');
    expect(spans[1].text, 'https://example.com/x');
    expect(spans[2].text, '.');
  });

  test('showNotesSpans ignores non-http anchors', () {
    final spans = showNotesSpans('<a href="javascript:alert(1)">x</a>');
    expect(spans, hasLength(1));
    expect(spans.single.text, 'x');
    expect(spans.single.url, isNull);
  });


  test('audioExtension prefers the mime type', () {
    expect(audioExtension('audio/mpeg', 'https://cdn.example/a'), '.mp3');
    expect(audioExtension(null, 'https://cdn.example/a.m4a'), '.m4a');
    expect(audioExtension(null, 'https://cdn.example/a'), '.mp3');
  });

  test('downloadFileName uses podcast and episode titles', () {
    expect(
      downloadFileName(
        podcastTitle: 'Nota Bene',
        episodeTitle: 'Les pyramides',
        extension: '.mp3',
      ),
      '[Nota Bene] Les pyramides.mp3',
    );
    expect(
      downloadFileName(
        podcastTitle: 'A/B:C',
        episodeTitle: 'Épisode "1"',
        extension: '.m4a',
      ),
      '[A B C] Épisode 1.m4a',
    );
  });

  test('formatDate uses relative labels', () {
    final now = DateTime.now();
    expect(formatDate(now), "Aujourd'hui");
    expect(formatDate(now.subtract(const Duration(days: 1))), 'Hier');
  });

  test('formatListeningTime formats hours and minutes', () {
    expect(formatListeningTime(0), '0 min');
    expect(formatListeningTime(90), '1 min');
    expect(formatListeningTime(3600), '1 h');
    expect(formatListeningTime(3660), '1 h 1 min');
  });

  test('formatBytes formats storage sizes', () {
    expect(formatBytes(0), '0 Mo');
    expect(formatBytes(512), '0.5 Ko');
    expect(formatBytes(5 * 1024 * 1024), '5.0 Mo');
    expect(formatBytes(1536 * 1024 * 1024), '1.50 Go');
  });

  test('formatReleaseCadence estimates publication rhythm', () {
    expect(formatReleaseCadence(null), 'Indéterminé');
    expect(formatReleaseCadence(const Duration(hours: 20)), 'Quotidien');
    expect(formatReleaseCadence(const Duration(days: 7)), 'Hebdomadaire');
    expect(formatReleaseCadence(const Duration(days: 30)), 'Mensuel');
  });

  test('formatRelativeFuture describes upcoming dates', () {
    final now = DateTime.now();
    expect(formatRelativeFuture(null), 'Indéterminée');
    expect(formatRelativeFuture(now), "Aujourd'hui");
    expect(
      formatRelativeFuture(now.add(const Duration(days: 1))),
      'Demain',
    );
    expect(
      formatRelativeFuture(now.add(const Duration(days: 5))),
      'Dans 5 jours',
    );
  });
}
