import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/http_auth.dart';

void main() {
  test('basicAuthorization encode user:password', () {
    final header = basicAuthorization('alice', 'secret');
    expect(header, 'Basic ${base64Encode(utf8.encode('alice:secret'))}');
  });

  test('basicAuthorization is absent when both values are empty', () {
    expect(basicAuthorization(null, null), isNull);
    expect(basicAuthorization('  ', ''), isNull);
  });

  test('podcastRequestHeaders adds Authorization only when needed', () {
    expect(
      podcastRequestHeaders(userAgent: 'Podavio'),
      {'User-Agent': 'Podavio'},
    );
    expect(
      podcastRequestHeaders(
        userAgent: 'Podavio',
        username: 'alice',
        password: 'secret',
      )['Authorization'],
      isNotNull,
    );
  });
}
