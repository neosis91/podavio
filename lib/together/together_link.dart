import 'dart:async';
import 'dart:io';

import 'together_protocol.dart';

/// Session ouverte sur cet appareil. Les invités s’y connectent en WebSocket.
class TogetherHostLink {
  TogetherHostLink._(this._server);

  final HttpServer _server;
  final _sockets = <WebSocket>[];
  final _names = <WebSocket, String>{};
  final _peers = StreamController<List<String>>.broadcast();
  final _intents = StreamController<TogetherIntent>.broadcast();
  TogetherSnapshot? _last;
  var _closed = false;
  var roomName = '';

  int get port => _server.port;

  List<String> get peerNames => List.unmodifiable(_names.values);

  Stream<List<String>> get peers => _peers.stream;

  Stream<TogetherIntent> get intents => _intents.stream;

  static Future<TogetherHostLink> open({InternetAddress? address}) async {
    final server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, 0);
    final link = TogetherHostLink._(server);
    server.listen(link._onRequest);
    return link;
  }

  void publish(TogetherSnapshot snapshot) {
    _last = snapshot;
    _sendAll(TogetherStateMessage(snapshot).encode());
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final socket in List<WebSocket>.of(_sockets)) {
      await socket.close();
    }
    await _server.close(force: true);
    await _peers.close();
    await _intents.close();
  }

  Future<void> _onRequest(HttpRequest request) async {
    if (_closed || !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    socket.listen(
      (data) => _onData(socket, data),
      onDone: () => _drop(socket),
      onError: (_) => _drop(socket),
    );
  }

  void _onData(WebSocket socket, Object? data) {
    final message = TogetherMessage.decode(data);
    if (message is TogetherHello) {
      _names[socket] = message.name;
      _emitPeers();
      final last = _last;
      if (last != null) socket.add(TogetherStateMessage(last).encode());
    } else if (message is TogetherIntentMessage && !_intents.isClosed) {
      _intents.add(message.intent);
    }
  }

  void _drop(WebSocket socket) {
    _sockets.remove(socket);
    if (_names.remove(socket) != null) _emitPeers();
  }

  void _emitPeers() {
    if (!_peers.isClosed) _peers.add(peerNames);
    _sendAll(TogetherRoomMessage(roomName, _names.length + 1).encode());
  }

  void _sendAll(String data) {
    for (final socket in _sockets) {
      socket.add(data);
    }
  }
}

/// Connexion d’un invité vers la session de quelqu’un d’autre.
class TogetherGuestLink {
  TogetherGuestLink._(this._socket);

  final WebSocket _socket;
  final _states = StreamController<TogetherSnapshot>.broadcast();
  final _room = StreamController<TogetherRoomMessage>.broadcast();
  TogetherRoomMessage? latestRoom;
  var _closed = false;

  Stream<TogetherSnapshot> get states => _states.stream;

  Stream<TogetherRoomMessage> get room => _room.stream;

  static Future<TogetherGuestLink> connect({
    required String host,
    required int port,
    required String name,
  }) async {
    final socket = await WebSocket.connect('ws://$host:$port')
        .timeout(const Duration(seconds: 5));
    final link = TogetherGuestLink._(socket);
    socket.listen(link._onData, onDone: link._end, onError: (_) => link._end());
    socket.add(TogetherHello(name).encode());
    return link;
  }

  void sendIntent(TogetherIntent intent) {
    if (_closed) return;
    _socket.add(TogetherIntentMessage(intent).encode());
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _socket.close();
    await _states.close();
    await _room.close();
  }

  void _onData(Object? data) {
    final message = TogetherMessage.decode(data);
    if (message is TogetherStateMessage && !_states.isClosed) {
      _states.add(message.snapshot);
    } else if (message is TogetherRoomMessage) {
      latestRoom = message;
      if (!_room.isClosed) _room.add(message);
    }
  }

  void _end() {
    _closed = true;
    if (!_states.isClosed) _states.close();
    if (!_room.isClosed) _room.close();
  }
}
