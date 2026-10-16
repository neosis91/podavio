import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/l10n/messages.dart';
import 'package:podavio/together/together_link.dart';
import 'package:podavio/together/together_protocol.dart';

void main() {
  const episode = TogetherEpisode(
    feedUrl: 'https://example.com/feed',
    guid: 'ep-1',
    title: 'Un',
    podcastTitle: 'Essai',
    audioUrl: 'https://example.com/1.mp3',
  );

  TogetherSnapshot snapshot({
    int seq = 1,
    bool playing = true,
    int positionMs = 10000,
    double speed = 1,
    TogetherEpisode? current,
  }) {
    return TogetherSnapshot(
      seq: seq,
      playing: playing,
      positionMs: positionMs,
      speed: speed,
      episode: current ?? episode,
    );
  }

  test('a session stays together when play, position or speed differ', () {
    final remote = snapshot();
    final same = planTogetherAdjustment(local: remote, remote: remote);
    expect(same.isEmpty, isTrue);

    final drifted = planTogetherAdjustment(
      local: snapshot(positionMs: 1000),
      remote: remote,
    );
    expect(drifted.seek, isTrue);
    expect(drifted.load, isFalse);

    final paused = planTogetherAdjustment(
      local: snapshot(playing: false),
      remote: remote,
    );
    expect(paused.playing, isTrue);

    final other = planTogetherAdjustment(
      local: snapshot(
        current: const TogetherEpisode(
          feedUrl: 'https://example.com/feed',
          guid: 'ep-2',
          title: 'Deux',
          podcastTitle: 'Essai',
          audioUrl: 'https://example.com/2.mp3',
        ),
      ),
      remote: remote,
    );
    expect(other.load, isTrue);
    expect(other.seek, isTrue);
    expect(other.playing, isTrue);

    expect(planTogetherAdjustment(local: null, remote: remote).load, isTrue);
  });

  test('only a real jump counts as a shared seek', () {
    expect(
      isTogetherSeek(
        previousMs: 1000,
        nextMs: 1250,
        elapsed: const Duration(milliseconds: 250),
      ),
      isFalse,
    );
    expect(
      isTogetherSeek(
        previousMs: 1000,
        nextMs: 20000,
        elapsed: const Duration(milliseconds: 300),
      ),
      isTrue,
    );
  });

  test('codes stay short and messages round-trip', () {
    final code = newTogetherCode(Random(1));
    expect(code, hasLength(4));
    expect(normalizeTogetherCode(' ab-12 '), 'AB12');

    final state = TogetherStateMessage(snapshot(speed: 1.5));
    final decoded = TogetherMessage.decode(state.encode());
    expect(decoded, isA<TogetherStateMessage>());
    final again = (decoded! as TogetherStateMessage).snapshot;
    expect(again.playing, isTrue);
    expect(again.positionMs, 10000);
    expect(again.speed, 1.5);
    expect(again.episode.guid, 'ep-1');

    final intent = TogetherIntentMessage(
      const TogetherIntent(kind: TogetherIntentKind.pause, positionMs: 40),
    );
    final decodedIntent = TogetherMessage.decode(intent.encode());
    expect(
      (decodedIntent! as TogetherIntentMessage).intent.kind,
      TogetherIntentKind.pause,
    );
    expect(TogetherMessage.decode('nope'), isNull);
  });

  test('listen together strings exist in every language', () {
    const keys = [
      'Listen together',
      'On the same Wi-Fi. Podavio does not use a server.',
      'Start a session',
      'Join',
      'Code',
      'Leave',
      'Share this code with people on the same network.',
      'Play an episode to start a session.',
      'This episode is not in your library.',
      'Waiting for the others.',
      '1 person is listening.',
      '{count} people are listening.',
      'Could not find this session.',
      'The session ended.',
      'Could not start the session.',
      'Your name',
      'Guest',
      'Enter the 4-character code.',
    ];
    for (final entry in interfaceMessages.entries) {
      for (final key in keys) {
        expect(
          entry.value.containsKey(key),
          isTrue,
          reason: '${entry.key} missing "$key"',
        );
      }
    }
  });

  test('a guest receives the host and can pause it', () async {
    final host = await TogetherHostLink.open(
      address: InternetAddress.loopbackIPv4,
    );
    addTearDown(host.close);
    final names = host.peers.first;
    final intents = host.intents.first;
    final guest = await TogetherGuestLink.connect(
      host: '127.0.0.1',
      port: host.port,
      name: 'Ada',
    );
    addTearDown(guest.close);

    expect(await names.timeout(const Duration(seconds: 2)), ['Ada']);

    final states = guest.states.first;
    host.publish(snapshot());
    final received = await states.timeout(const Duration(seconds: 2));
    expect(received.episode.title, 'Un');
    expect(received.positionMs, 10000);

    guest.sendIntent(
      const TogetherIntent(kind: TogetherIntentKind.pause, positionMs: 10000),
    );
    final intent = await intents.timeout(const Duration(seconds: 2));
    expect(intent.kind, TogetherIntentKind.pause);
  });
}
