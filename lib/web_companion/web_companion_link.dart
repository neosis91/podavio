import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'web_companion_crypto.dart';
import 'web_companion_snapshot.dart';

class WebCompanionSession {
  const WebCompanionSession({
    required this.relay,
    required this.session,
    required this.pwaPub,
    required this.phonePub,
    required this.key,
    required this.fingerprint,
  });

  final String relay;
  final String session;
  final List<int> pwaPub;
  final List<int> phonePub;
  final List<int> key;
  final String fingerprint;

  Map<String, Object?> toJson() {
    return {
      'relay': relay,
      'session': session,
      'pwaPub': webCompanionB64(pwaPub),
      'phonePub': webCompanionB64(phonePub),
      'key': webCompanionB64(key),
      'fingerprint': fingerprint,
    };
  }

  static WebCompanionSession? decode(String raw) {
    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (parsed is! Map) return null;
    try {
      final relay = parsed['relay'];
      final session = parsed['session'];
      final fingerprint = parsed['fingerprint'];
      if (relay is! String || session is! String || fingerprint is! String) {
        return null;
      }
      return WebCompanionSession(
        relay: relay,
        session: session,
        pwaPub: webCompanionB64Decode(parsed['pwaPub'] as String),
        phonePub: webCompanionB64Decode(parsed['phonePub'] as String),
        key: webCompanionB64Decode(parsed['key'] as String),
        fingerprint: fingerprint,
      );
    } catch (_) {
      return null;
    }
  }
}

class WebCompanionLink {
  WebCompanionLink({
    required this.session,
    required this.onProgress,
    required this.onLibrary,
    required this.onBrowser,
    required this.onUnlink,
  });

  final WebCompanionSession session;
  final void Function(WebProgress progress) onProgress;
  final void Function(WebLibraryAction action) onLibrary;
  final void Function(bool online) onBrowser;
  final void Function() onUnlink;
  final _random = Random.secure();
  var _closed = false;
  var _sendN = 0;
  var _recvN = 0;
  String? _peerConn;
  String _conn = '';
  WebSocket? _socket;
  Future<void>? _running;

  bool get browserOnline => _peerConn != null;

  Future<void> start() {
    _running ??= _loop();
    return _running!;
  }

  Future<void> close() async {
    _closed = true;
    await _socket?.close();
  }

  Future<void> sendSnapshot(Map<String, Object?> snapshot) {
    return _sendPlain(snapshot, 'phone');
  }

  Future<void> sendCommand(Map<String, Object?> command) {
    return _sendPlain(command, 'phone');
  }

  /// Préviens l’autre côté, puis ferme sans rouvrir la session.
  Future<void> unlink() async {
    final socket = _socket;
    if (socket != null) {
      try {
        socket.add(jsonEncode({'type': 'unlink'}));
      } catch (_) {}
    }
    await close();
  }

  Future<void> _loop() async {
    while (!_closed) {
      _conn = webCompanionRandomId(_random);
      _sendN = 0;
      _recvN = 0;
      _peerConn = null;
      try {
        final socket = await WebSocket.connect(session.relay);
        if (_closed) {
          await socket.close();
          return;
        }
        _socket = socket;
        socket.listen(_onFrame, onDone: () {}, onError: (_) {});
        socket.add(
          jsonEncode({
            'type': 'join',
            'session': session.session,
            'role': 'phone',
            'conn': _conn,
          }),
        );
        await socket.done;
      } catch (_) {
        // Nouvelle tentative plus bas.
      }
      _socket = null;
      if (_peerConn != null) onBrowser(false);
      _peerConn = null;
      if (_closed) return;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  void _onFrame(dynamic data) {
    if (data is! String) return;
    Object? parsed;
    try {
      parsed = jsonDecode(data);
    } catch (_) {
      return;
    }
    if (parsed is! Map) return;
    final type = parsed['type'];
    if (type == 'peer' && parsed['role'] == 'browser') {
      final conn = parsed['conn'];
      if (conn is! String) return;
      _peerConn = conn;
      _recvN = 0;
      onBrowser(true);
      unawaited(_announce());
    } else if (type == 'unlink') {
      _peerConn = null;
      _recvN = 0;
      onUnlink();
    } else if (type == 'bye') {
      _peerConn = null;
      _recvN = 0;
      onBrowser(false);
    } else if (type == 'blob') {
      unawaited(_onBlob(parsed));
    }
  }

  Future<void> _announce() async {
    final sealed = await webCompanionSeal(
      key: session.key,
      plain: utf8.encode(
        jsonEncode({
          'v': 1,
          'role': 'phone',
          'pub': webCompanionB64(session.phonePub),
        }),
      ),
      aad: webCompanionAad('phone', _conn, 0),
      random: _random,
    );
    _socket?.add(
      jsonEncode({
        'type': 'hello',
        'pub': webCompanionB64(session.phonePub),
        'iv': webCompanionB64(sealed.iv),
        'ct': webCompanionB64(sealed.ct),
      }),
    );
  }

  Future<void> _sendPlain(Map<String, Object?> payload, String role) async {
    final socket = _socket;
    if (socket == null || _peerConn == null) return;
    _sendN += 1;
    final sealed = await webCompanionSeal(
      key: session.key,
      plain: utf8.encode(jsonEncode(payload)),
      aad: webCompanionAad(role, _conn, _sendN),
      random: _random,
    );
    socket.add(
      jsonEncode({
        'type': 'blob',
        'n': _sendN,
        'iv': webCompanionB64(sealed.iv),
        'ct': webCompanionB64(sealed.ct),
      }),
    );
  }

  Future<void> _onBlob(Map<dynamic, dynamic> message) async {
    final n = message['n'];
    final iv = message['iv'];
    final ct = message['ct'];
    final peer = _peerConn;
    if (n is! int || iv is! String || ct is! String || peer == null) return;
    if (n <= _recvN) return;
    _recvN = n;
    List<int> plain;
    try {
      final opened = await webCompanionOpen(
        key: session.key,
        iv: webCompanionB64Decode(iv),
        ct: webCompanionB64Decode(ct),
        aad: webCompanionAad('browser', peer, n),
      );
      if (opened == null) return;
      plain = opened;
    } catch (_) {
      return;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(plain));
    } catch (_) {
      return;
    }
    final action = WebLibraryAction.parse(decoded);
    if (action != null) {
      onLibrary(action);
      return;
    }
    final progress = WebProgress.parse(decoded);
    if (progress != null) onProgress(progress);
  }
}
