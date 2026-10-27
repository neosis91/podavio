import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'web_companion_link.dart';

class WebCompanionStore {
  WebCompanionStore({FlutterSecureStorage? secure})
    : _secure = secure ?? const FlutterSecureStorage();

  static const _key = 'podavio_web_session';
  final FlutterSecureStorage _secure;

  Future<WebCompanionSession?> read() async {
    try {
      final raw = await _secure.read(key: _key);
      if (raw != null) return WebCompanionSession.decode(raw);
    } catch (_) {
      // Bureau sans trousseau : repli fichier plus bas.
    }
    return _readFile();
  }

  Future<void> write(WebCompanionSession session) async {
    final raw = jsonEncode(session.toJson());
    try {
      await _secure.write(key: _key, value: raw);
      await _deleteFile();
      return;
    } catch (_) {
      await _writeFile(raw);
    }
  }

  Future<void> clear() async {
    try {
      await _secure.delete(key: _key);
    } catch (_) {}
    await _deleteFile();
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/podavio-web-session.json');
  }

  Future<WebCompanionSession?> _readFile() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return null;
      return WebCompanionSession.decode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeFile(String raw) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(raw, flush: true);
  }

  Future<void> _deleteFile() async {
    try {
      final file = await _file();
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }
}
