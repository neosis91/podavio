import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/build_info.dart';

/// Serveur HTTP local qui sert une page Podavio et l’APK.
class NearbyApkServer {
  NearbyApkServer._({
    required this.server,
    required this.apkFile,
    required this.versionLabel,
    required this.logoDataUri,
  });

  final HttpServer server;
  final File apkFile;
  final String versionLabel;
  final String logoDataUri;

  int get port => server.port;

  static Future<NearbyApkServer> start({
    required File apkFile,
    required String versionLabel,
    String? logoDataUri,
  }) async {
    final logoUri = logoDataUri ?? await _logoDataUri();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final host = NearbyApkServer._(
      server: server,
      apkFile: apkFile,
      versionLabel: versionLabel,
      logoDataUri: logoUri,
    );
    server.listen(host._onRequest);
    return host;
  }

  Future<void> close() async {
    await server.close(force: true);
  }

  Future<void> _onRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (request.method != 'GET' && request.method != 'HEAD') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        return;
      }
      if (path == '/' || path.isEmpty) {
        await _serveLanding(request);
        return;
      }
      if (path == '/podavio.apk') {
        await _serveApk(request);
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveLanding(HttpRequest request) async {
    final html = _landingHtml(
      versionLabel: versionLabel,
      logoDataUri: logoDataUri,
    );
    final bytes = utf8.encode(html);
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.html;
    request.response.headers.contentLength = bytes.length;
    if (request.method == 'GET') {
      request.response.add(bytes);
    }
    await request.response.close();
  }

  Future<void> _serveApk(HttpRequest request) async {
    final length = await apkFile.length();
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType(
      'application',
      'vnd.android.package-archive',
    );
    request.response.headers.set(
      'Content-Disposition',
      'attachment; filename="podavio.apk"',
    );
    request.response.headers.contentLength = length;
    if (request.method == 'GET') {
      await request.response.addStream(apkFile.openRead());
    }
    await request.response.close();
  }
}

/// Adresses IPv4 LAN utilisables pour le QR (hors loopback).
Future<List<InternetAddress>> lanIpv4Addresses() async {
  final result = <InternetAddress>[];
  for (final iface in await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: false,
  )) {
    for (final addr in iface.addresses) {
      if (addr.isLoopback) continue;
      result.add(addr);
    }
  }
  result.sort((a, b) {
    final ap = _preferLan(a.address);
    final bp = _preferLan(b.address);
    if (ap != bp) return ap ? -1 : 1;
    return a.address.compareTo(b.address);
  });
  return result;
}

bool _preferLan(String address) {
  return address.startsWith('192.168.') ||
      address.startsWith('10.') ||
      _isRfc1918_172(address);
}

bool _isRfc1918_172(String address) {
  if (!address.startsWith('172.')) return false;
  final parts = address.split('.');
  if (parts.length < 2) return false;
  final second = int.tryParse(parts[1]) ?? -1;
  return second >= 16 && second <= 31;
}

Future<String> _logoDataUri() async {
  final bytes = await rootBundle.load('assets/brand/logo.png');
  final b64 = base64Encode(bytes.buffer.asUint8List());
  return 'data:image/png;base64,$b64';
}

String _esc(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _landingHtml({
  required String versionLabel,
  required String logoDataUri,
}) {
  final buildHint = BuildInfo.version.isNotEmpty
      ? BuildInfo.version
      : (versionLabel.isEmpty ? 'Podavio' : versionLabel);
  final safeBuild = _esc(buildHint);
  return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Podavio · Download</title>
<style>
  :root {
    --green: #2e895d;
    --green-deep: #1f6b48;
    --mint: #b0dac9;
    --mint-light: #d0ebdf;
    --mint-center: #e8f6ef;
    --ink: #1a2e24;
    --muted: #4a6b5c;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html {
    min-height: 100%;
    background:
      radial-gradient(ellipse 90% 70% at 50% 28%, var(--mint-center) 0%, transparent 55%),
      radial-gradient(ellipse 120% 90% at 50% 100%, var(--mint) 0%, var(--mint-light) 45%, #9fd0bb 100%);
    background-color: var(--mint-light);
  }
  body {
    font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
    color: var(--ink);
    padding: 36px 20px 56px;
    text-align: center;
  }
  .logo {
    display: block;
    width: min(260px, 72vw);
    height: auto;
    margin: 0 auto 20px;
  }
  h1 {
    color: var(--green-deep);
    font-weight: 600;
    font-size: 1.45rem;
    margin-bottom: 8px;
  }
  .meta {
    color: var(--muted);
    font-size: 0.95rem;
    margin-bottom: 28px;
  }
  .download {
    display: inline-block;
    background: var(--green);
    color: #fff;
    font-weight: 600;
    font-size: 1.05rem;
    text-decoration: none;
    padding: 14px 28px;
    border-radius: 999px;
    box-shadow: 0 6px 18px rgba(46, 137, 93, 0.28);
  }
  .download:active { background: var(--green-deep); }
  .hint {
    margin-top: 22px;
    color: var(--muted);
    font-size: 0.88rem;
    line-height: 1.45;
    max-width: 28rem;
    margin-left: auto;
    margin-right: auto;
  }
  footer {
    margin-top: 40px;
    color: var(--muted);
    font-size: 0.85rem;
  }
  footer a {
    color: var(--green-deep);
    font-weight: 600;
    text-decoration: none;
  }
</style>
</head>
<body>
  <img class="logo" src="$logoDataUri" alt="Podavio">
  <h1>Install Podavio</h1>
  <p class="meta">Version $safeBuild · shared nearby</p>
  <a class="download" href="/podavio.apk">Download Podavio</a>
  <p class="hint">After download, open the file and allow installing from this browser if Android asks.</p>
  <footer>${DateTime.now().year} – <a href="https://podavio.com">podavio.com</a></footer>
</body>
</html>
''';
}
