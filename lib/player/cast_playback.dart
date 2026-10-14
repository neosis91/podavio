import 'dart:async';

import 'package:cast/device.dart';
import 'package:cast/session.dart';
import 'package:cast/session_manager.dart';

/// Position lue sur le récepteur Cast.
class CastPlaybackUpdate {
  const CastPlaybackUpdate({
    required this.position,
    required this.playing,
    this.completed = false,
  });

  final Duration position;
  final bool playing;
  final bool completed;
}

/// Session Chromecast : le téléviseur lit l’URL, l’application envoie play,
/// pause et seek. Récepteur média par défaut (`CC1AD845`).
class CastPlayback {
  static const _mediaReceiver = 'CC1AD845';

  CastSession? _session;
  StreamSubscription<Map<String, dynamic>>? _messages;
  Timer? _poll;
  var _requestId = 1;
  int? _mediaSessionId;
  var _closed = false;
  var _completed = false;

  final _updates = StreamController<CastPlaybackUpdate>.broadcast();

  Stream<CastPlaybackUpdate> get updates => _updates.stream;

  Future<void> open(CastDevice device) async {
    await close();
    _closed = false;
    _completed = false;
    final session = await CastSessionManager().startSession(device);
    _session = session;
    session.sendMessage(CastSession.kNamespaceReceiver, {
      'type': 'LAUNCH',
      'appId': _mediaReceiver,
      'requestId': _requestId++,
    });
    await session.stateStream
        .firstWhere((state) => state == CastSessionState.connected)
        .timeout(const Duration(seconds: 12));
    if (_closed) return;
    _messages = session.messageStream.listen(_onMessage);
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _requestStatus());
  }

  void load({
    required String url,
    required String contentType,
    required String title,
    required String artist,
    String? imageUrl,
    required Duration position,
  }) {
    _completed = false;
    _session?.sendMessage(CastSession.kNamespaceMedia, {
      'type': 'LOAD',
      'requestId': _requestId++,
      'autoplay': true,
      'currentTime': position.inMilliseconds / 1000,
      'media': {
        'contentId': url,
        'contentType': contentType,
        'streamType': 'BUFFERED',
        'metadata': {
          'metadataType': 3,
          'title': title,
          'artist': artist,
          if (imageUrl != null && imageUrl.isNotEmpty)
            'images': [
              {'url': imageUrl},
            ],
        },
      },
    });
  }

  void play() => _command('PLAY');

  void pause() => _command('PAUSE');

  void seek(Duration position) {
    _session?.sendMessage(CastSession.kNamespaceMedia, {
      'type': 'SEEK',
      'requestId': _requestId++,
      'currentTime': position.inMilliseconds / 1000,
      if (_mediaSessionId != null) 'mediaSessionId': _mediaSessionId,
    });
  }

  Future<void> close() async {
    _closed = true;
    _poll?.cancel();
    _poll = null;
    await _messages?.cancel();
    _messages = null;
    final session = _session;
    _session = null;
    _mediaSessionId = null;
    if (session != null) {
      await CastSessionManager().endSession(session.sessionId);
    }
  }

  void _command(String type) {
    _session?.sendMessage(CastSession.kNamespaceMedia, {
      'type': type,
      'requestId': _requestId++,
      if (_mediaSessionId != null) 'mediaSessionId': _mediaSessionId,
    });
  }

  void _requestStatus() {
    if (_closed || _mediaSessionId == null) return;
    _session?.sendMessage(CastSession.kNamespaceMedia, {
      'type': 'GET_STATUS',
      'requestId': _requestId++,
      'mediaSessionId': _mediaSessionId,
    });
  }

  void _onMessage(Map<String, dynamic> payload) {
    if (_closed || payload['type'] != 'MEDIA_STATUS') return;
    final status = payload['status'];
    if (status is! List || status.isEmpty || status.first is! Map) return;
    final item = Map<String, dynamic>.from(status.first as Map);
    final sessionId = item['mediaSessionId'];
    if (sessionId is int) _mediaSessionId = sessionId;
    final seconds = item['currentTime'];
    final position = seconds is num
        ? Duration(milliseconds: (seconds * 1000).round())
        : Duration.zero;
    final playerState = item['playerState'];
    final idleReason = item['idleReason'];
    final completed =
        playerState == 'IDLE' && idleReason == 'FINISHED' && !_completed;
    if (completed) _completed = true;
    if (_updates.isClosed) return;
    _updates.add(
      CastPlaybackUpdate(
        position: position,
        playing: playerState == 'PLAYING' || playerState == 'BUFFERING',
        completed: completed,
      ),
    );
  }
}
