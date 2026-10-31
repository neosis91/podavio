import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:podavio/web_companion/web_companion_crypto.dart';
import 'package:podavio/web_companion/web_companion_snapshot.dart';

void main() {
  test('recent episodes stay capped and an older one in progress is kept', () {
    final episodes = [
      for (var i = 0; i < 40; i++)
        WebCompanionEpisodeRef(
          id: i,
          publishedAt: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
          positionMs: i == 1 ? 1200 : 0,
          played: false,
        ),
    ];
    final picked = capWebCompanionEpisodes(episodes);
    expect(picked.length, 31);
    expect(picked.first.id, 39);
    expect(picked.any((episode) => episode.id == 1), isTrue);
    expect(picked.where((episode) => episode.id == 1).length, 1);
  });

  test('favorites, downloads, playlists and recent plays stay in the snapshot', () {
    final episodes = [
      for (var i = 0; i < 40; i++)
        WebCompanionEpisodeRef(
          id: i,
          publishedAt: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
          positionMs: 0,
          played: true,
          favorite: i == 2,
          downloaded: i == 3,
          pinned: i == 4,
          lastPlayedAt: i == 5 ? DateTime.utc(2026, 3, 1) : null,
        ),
    ];
    final picked = capWebCompanionEpisodes(episodes);
    expect(picked.any((episode) => episode.id == 2), isTrue);
    expect(picked.any((episode) => episode.id == 3), isTrue);
    expect(picked.any((episode) => episode.id == 4), isTrue);
    expect(picked.any((episode) => episode.id == 5), isTrue);
    expect(picked.where((episode) => episode.id == 2).length, 1);
  });

  test('a progress message rejects a negative position', () {
    expect(
      WebProgress.parse({
        'type': 'progress',
        'episodeId': 4,
        'positionMs': -1,
      }),
      isNull,
    );
    final progress = WebProgress.parse({
      'type': 'progress',
      'episodeId': 4,
      'positionMs': 20,
      'ended': true,
    });
    expect(progress?.positionMs, 20);
    expect(progress?.ended, isTrue);
  });

  test('the qr must carry a websocket address and a 32 byte key', () {
    expect(WebCompanionQr.parse('{"relay":"https://x","session":"abcdefgh","pub":"aa"}'), isNull);
    final pub = webCompanionB64(List<int>.filled(32, 7));
    final qr = WebCompanionQr.parse(
      '{"v":1,"relay":"ws://127.0.0.1:8787/ws","session":"abcdefghij","pub":"$pub"}',
    );
    expect(qr?.relay, 'ws://127.0.0.1:8787/ws');
    expect(qr?.pwaPub, List<int>.filled(32, 7));
  });

  test('a sealed message opens only with the same counter', () async {
    final key = List<int>.generate(32, (index) => index);
    final sealed = await webCompanionSeal(
      key: key,
      plain: [1, 2, 3],
      aad: webCompanionAad('browser', 'conn', 1),
      random: _FixedRandom(),
    );
    final opened = await webCompanionOpen(
      key: key,
      iv: sealed.iv,
      ct: sealed.ct,
      aad: webCompanionAad('browser', 'conn', 1),
    );
    expect(opened, [1, 2, 3]);
    final derived = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(List<int>.generate(32, (index) => index)),
      nonce: utf8.encode(webCompanionSalt),
      info: utf8.encode(webCompanionInfo),
    );
    final bytes = await derived.extractBytes();
    expect(
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      '7648968f60036f8e87287f9216f75e40cdbb0a08c557fc08a5df68b581140b41',
    );
    expect(
      await webCompanionOpen(
        key: key,
        iv: sealed.iv,
        ct: sealed.ct,
        aad: webCompanionAad('browser', 'conn', 2),
      ),
      isNull,
    );
  });

  test('x25519 shared secret matches the browser primitive', () async {
    final privateKey = SimpleKeyPairData(
      _hex('90cf533f5c1983509768987b97e56a83fc67544ecd291133504b8e0f91bcde79'),
      publicKey: SimplePublicKey(
        List<int>.filled(32, 1),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );
    final shared = await X25519().sharedSecretKey(
      keyPair: privateKey,
      remotePublicKey: SimplePublicKey(
        _hex('7ca2c72446533e08d6a21dd5609be86806c2cde9a6275623511258bcdd2b9d4a'),
        type: KeyPairType.x25519,
      ),
    );
    final bytes = await shared.extractBytes();
    expect(
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      'fa6e8876bca2ca830fce56dcdd8edabc5f15112a9925d75172b2abae41e36a5b',
    );
  });
}

List<int> _hex(String value) {
  final bytes = <int>[];
  for (var i = 0; i < value.length; i += 2) {
    bytes.add(int.parse(value.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

class _FixedRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 3;
}
