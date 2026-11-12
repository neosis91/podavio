import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/player/playback_source.dart';

void main() {
  test('a podcast queue runs from the oldest episode to the newest', () {
    final source = PlaybackSource.podcast(7);
    expect(source.query.podcastId, 7);
    expect(source.query.oldestFirst, isTrue);
    expect(source.query.paginated, isFalse);
  });
}
