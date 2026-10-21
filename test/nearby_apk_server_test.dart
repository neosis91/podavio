import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/nearby/nearby_apk_server.dart';

Future<String> _rawGet(int port, String path) async {
  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    port,
  );
  socket.write(
    'GET $path HTTP/1.1\r\n'
    'Host: 127.0.0.1\r\n'
    'Connection: close\r\n'
    '\r\n',
  );
  await socket.flush();
  final response = await utf8.decoder.bind(socket).join();
  await socket.close();
  return response;
}

void main() {
  test('serves landing page and apk', () async {
    final apk = File(
      '${Directory.systemTemp.path}/podavio-nearby-test.apk',
    );
    await apk.writeAsBytes([0x50, 0x4b, 0x03, 0x04]);
    addTearDown(() async {
      if (await apk.exists()) await apk.delete();
    });

    final server = await NearbyApkServer.start(
      apkFile: apk,
      versionLabel: '2026.10.19',
      logoDataUri:
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    addTearDown(server.close);

    final landing = await _rawGet(server.port, '/');
    expect(landing, startsWith('HTTP/1.1 200'));
    expect(landing, contains('Install Podavio'));
    expect(landing, contains('/podavio.apk'));
    expect(landing, contains('2026.10.19'));

    final apkResponse = await _rawGet(server.port, '/podavio.apk');
    expect(apkResponse, startsWith('HTTP/1.1 200'));
    expect(apkResponse, contains('application/vnd.android.package-archive'));
    expect(apkResponse, contains(String.fromCharCodes([0x50, 0x4b, 0x03, 0x04])));
  });
}
