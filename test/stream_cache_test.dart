import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/player/stream_cache.dart';

void main() {
  test('reconnaît seulement la fermeture courte du proxy', () {
    final abort = HttpException(
      'Content size below specified contentLength.',
      uri: Uri.parse('/id/0e659abe-19aa-4fd7-a4cb-4c70525538bb'),
    );
    expect(isCacheProxyAbort(abort), isTrue);
    expect(
      isCacheProxyAbort(HttpException('coupé', uri: Uri.parse('/id/abc'))),
      isFalse,
    );
    expect(isCacheProxyAbort(const HttpException('autre')), isFalse);
    expect(
      isCacheProxyAbort(HttpException('x', uri: Uri.parse('/feed'))),
      isFalse,
    );
    expect(isCacheProxyAbort(StateError('x')), isFalse);
  });

  test('capte une coupure asynchrone du proxy', () async {
    final aborts = <HttpException>[];
    final zone = createCacheProxyZone(onAbort: (e, _) => aborts.add(e));
    zone.run(() {
      scheduleMicrotask(() {
        throw HttpException(
          'Content size below specified contentLength.',
          uri: Uri.parse('/id/abc'),
        );
      });
    });
    await Future<void>.delayed(Duration.zero);
    expect(aborts, hasLength(1));
    expect(aborts.single.uri?.path, '/id/abc');
  });

  test('transmet une autre erreur du proxy à la zone parente', () async {
    final forwarded = <Object>[];
    final aborts = <HttpException>[];
    await runZonedGuarded(() async {
      final zone = createCacheProxyZone(onAbort: (e, _) => aborts.add(e));
      zone.run(() {
        scheduleMicrotask(() {
          throw HttpException('coupé', uri: Uri.parse('/id/abc'));
        });
      });
      await Future<void>.delayed(Duration.zero);
    }, (error, _) => forwarded.add(error));
    await Future<void>.delayed(Duration.zero);
    expect(aborts, isEmpty);
    expect(forwarded.single, isA<HttpException>());
  });

  test('transmet les autres erreurs à la zone parente', () async {
    final forwarded = <Object>[];
    final aborts = <HttpException>[];
    await runZonedGuarded(() async {
      final zone = createCacheProxyZone(onAbort: (e, _) => aborts.add(e));
      zone.run(() {
        scheduleMicrotask(() => throw StateError('inattendu'));
      });
      await Future<void>.delayed(Duration.zero);
    }, (error, _) => forwarded.add(error));
    await Future<void>.delayed(Duration.zero);
    expect(aborts, isEmpty);
    expect(forwarded.single, isA<StateError>());
  });
}
