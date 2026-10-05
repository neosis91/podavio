import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/core/search.dart';

void main() {
  test('foldForSearch ignore casse et accents', () {
    expect(foldForSearch('Émancipées'), 'emancipees');
    expect(foldForSearch('e'), 'e');
    expect(searchMatch('Émancipées, le podcast', 'e'), isTrue);
    expect(searchMatch('Émancipées, le podcast', 'emanci'), isTrue);
    expect(searchMatch('Émancipées, le podcast', 'EMAN'), isTrue);
    expect(searchMatch('Émancipées, le podcast', 'xyz'), isFalse);
  });
}
