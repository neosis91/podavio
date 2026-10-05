import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/player/android_auto_bridge.dart';

void main() {
  test('Android Auto browse root ids are stable', () {
    expect(AndroidAutoBridge.rootId, 'root');
    expect(AndroidAutoBridge.queueId, 'queue');
    expect(AndroidAutoBridge.unreadId, 'unread');
    expect(AndroidAutoBridge.downloadsId, 'downloads');
  });
}
