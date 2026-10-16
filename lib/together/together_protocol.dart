import 'dart:convert';
import 'dart:math';

/// Au-delà de cet écart, un invité se cale sur la position partagée.
const togetherSnapMs = 2000;

const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Code court, sans caractères ambigus.
String newTogetherCode(Random random) {
  return String.fromCharCodes(
    List.generate(
      4,
      (_) => _codeAlphabet.codeUnitAt(random.nextInt(_codeAlphabet.length)),
    ),
  );
}

String normalizeTogetherCode(String raw) {
  return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

class TogetherEpisode {
  const TogetherEpisode({
    required this.feedUrl,
    required this.guid,
    required this.title,
    required this.podcastTitle,
    required this.audioUrl,
  });

  final String feedUrl;
  final String guid;
  final String title;
  final String podcastTitle;
  final String audioUrl;

  bool sameAs(TogetherEpisode other) {
    if (guid.isNotEmpty && other.guid.isNotEmpty) {
      return feedUrl == other.feedUrl && guid == other.guid;
    }
    return audioUrl.isNotEmpty && audioUrl == other.audioUrl;
  }

  Map<String, String> toJson() {
    return {
      'feedUrl': feedUrl,
      'guid': guid,
      'title': title,
      'podcastTitle': podcastTitle,
      'audioUrl': audioUrl,
    };
  }

  static TogetherEpisode? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final feedUrl = raw['feedUrl'];
    final audioUrl = raw['audioUrl'];
    final title = raw['title'];
    if (feedUrl is! String || audioUrl is! String || title is! String) {
      return null;
    }
    if (feedUrl.isEmpty || audioUrl.isEmpty) return null;
    return TogetherEpisode(
      feedUrl: feedUrl,
      guid: raw['guid'] is String ? raw['guid'] as String : '',
      title: title,
      podcastTitle: raw['podcastTitle'] is String
          ? raw['podcastTitle'] as String
          : '',
      audioUrl: audioUrl,
    );
  }
}

class TogetherSnapshot {
  const TogetherSnapshot({
    required this.seq,
    required this.playing,
    required this.positionMs,
    required this.speed,
    required this.episode,
  });

  final int seq;
  final bool playing;
  final int positionMs;
  final double speed;
  final TogetherEpisode episode;
}

enum TogetherIntentKind { play, pause, seek }

class TogetherIntent {
  const TogetherIntent({required this.kind, required this.positionMs});

  final TogetherIntentKind kind;
  final int positionMs;
}

/// Ce qu’un appareil doit changer pour coller à l’état reçu.
class TogetherAdjustment {
  const TogetherAdjustment({
    required this.load,
    required this.seek,
    required this.playing,
    required this.speed,
  });

  final bool load;
  final bool seek;

  /// `null` : ne pas toucher à lecture / pause.
  final bool? playing;
  final bool speed;

  bool get isEmpty => !load && !seek && playing == null && !speed;
}

TogetherAdjustment planTogetherAdjustment({
  required TogetherSnapshot? local,
  required TogetherSnapshot remote,
  int snapMs = togetherSnapMs,
}) {
  final episode = local?.episode;
  final load = episode == null || !episode.sameAs(remote.episode);
  final seek = load || (local!.positionMs - remote.positionMs).abs() > snapMs;
  final playing = load || local!.playing != remote.playing
      ? remote.playing
      : null;
  final speed = load || (local!.speed - remote.speed).abs() > 0.05;
  return TogetherAdjustment(
    load: load,
    seek: seek,
    playing: playing,
    speed: speed,
  );
}

/// Un saut plus grand que le temps écoulé vient d’un geste, pas de la lecture.
bool isTogetherSeek({
  required int previousMs,
  required int nextMs,
  required Duration elapsed,
}) {
  if (elapsed > const Duration(seconds: 2)) return false;
  final delta = (nextMs - previousMs).abs();
  if (delta < togetherSnapMs) return false;
  return delta > elapsed.inMilliseconds + 1500;
}

sealed class TogetherMessage {
  const TogetherMessage();

  String encode();

  static TogetherMessage? decode(Object? data) {
    if (data is! String || data.isEmpty) return null;
    Object? json;
    try {
      json = jsonDecode(data);
    } catch (_) {
      return null;
    }
    if (json is! Map) return null;
    if (json['v'] != 1) return null;
    switch (json['kind']) {
      case 'hello':
        final name = json['name'];
        if (name is! String || name.trim().isEmpty) return null;
        return TogetherHello(name.trim());
      case 'state':
        final episode = TogetherEpisode.fromJson(json['episode']);
        final positionMs = json['positionMs'];
        final speed = json['speed'];
        final seq = json['seq'];
        if (episode == null ||
            positionMs is! int ||
            speed is! num ||
            seq is! int ||
            json['playing'] is! bool) {
          return null;
        }
        return TogetherStateMessage(
          TogetherSnapshot(
            seq: seq,
            playing: json['playing'] as bool,
            positionMs: positionMs < 0 ? 0 : positionMs,
            speed: speed.toDouble(),
            episode: episode,
          ),
        );
      case 'intent':
        final positionMs = json['positionMs'];
        if (positionMs is! int) return null;
        final kind = switch (json['action']) {
          'play' => TogetherIntentKind.play,
          'pause' => TogetherIntentKind.pause,
          'seek' => TogetherIntentKind.seek,
          _ => null,
        };
        if (kind == null) return null;
        return TogetherIntentMessage(
          TogetherIntent(
            kind: kind,
            positionMs: positionMs < 0 ? 0 : positionMs,
          ),
        );
    }
    return null;
  }
}

class TogetherHello extends TogetherMessage {
  const TogetherHello(this.name);

  final String name;

  @override
  String encode() => jsonEncode({'v': 1, 'kind': 'hello', 'name': name});
}

class TogetherStateMessage extends TogetherMessage {
  const TogetherStateMessage(this.snapshot);

  final TogetherSnapshot snapshot;

  @override
  String encode() {
    final snapshot = this.snapshot;
    return jsonEncode({
      'v': 1,
      'kind': 'state',
      'seq': snapshot.seq,
      'playing': snapshot.playing,
      'positionMs': snapshot.positionMs,
      'speed': snapshot.speed,
      'episode': snapshot.episode.toJson(),
    });
  }
}

class TogetherIntentMessage extends TogetherMessage {
  const TogetherIntentMessage(this.intent);

  final TogetherIntent intent;

  @override
  String encode() {
    final action = switch (intent.kind) {
      TogetherIntentKind.play => 'play',
      TogetherIntentKind.pause => 'pause',
      TogetherIntentKind.seek => 'seek',
    };
    return jsonEncode({
      'v': 1,
      'kind': 'intent',
      'action': action,
      'positionMs': intent.positionMs,
    });
  }
}
