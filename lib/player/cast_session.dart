import 'dart:async';

import 'package:cast/device.dart';

import '../data/app_database.dart';
import 'cast_playback.dart';

/// Résultat d’une ouverture. [message] est absent quand la session est prête
/// ou quand l’ouverture a été abandonnée.
class CastOpen {
  const CastOpen.connected() : message = null, aborted = false;

  const CastOpen.failed(this.message) : aborted = false;

  const CastOpen.aborted() : message = null, aborted = true;

  final String? message;
  final bool aborted;

  bool get connected => message == null && !aborted;
}

/// Session Cast du lecteur. Les mises à jour reviennent à [onUpdate].
class CastSession {
  CastPlayback? _playback;
  StreamSubscription<CastPlaybackUpdate>? _subscription;

  bool get active => _playback != null;

  void play() => _playback?.play();

  void pause() => _playback?.pause();

  void seek(Duration position) => _playback?.seek(position);

  Future<CastOpen> connect(
    CastDevice device, {
    required bool Function() isGone,
    required void Function(CastPlaybackUpdate update) onUpdate,
  }) async {
    final playback = CastPlayback();
    try {
      await playback.open(device);
    } catch (_) {
      await playback.close();
      return CastOpen.failed('Connexion à ${device.name} impossible');
    }
    if (isGone()) {
      await playback.close();
      return const CastOpen.aborted();
    }
    await _subscription?.cancel();
    await _playback?.close();
    _playback = playback;
    _subscription = playback.updates.listen(onUpdate);
    return const CastOpen.connected();
  }

  /// Charge l’épisode sur le récepteur déjà ouvert.
  Future<String?> load({
    required Episode episode,
    required Podcast podcast,
    required Duration position,
    required bool preferPodcastCover,
  }) async {
    final playback = _playback;
    if (playback == null) return null;
    final url = episode.audioUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'Cet épisode n’a pas d’adresse que le Cast peut lire';
    }
    final cover = EpisodeEntry(episode: episode, podcast: podcast);
    try {
      playback.load(
        url: url,
        contentType: _contentType(episode),
        title: episode.title,
        artist: podcast.title,
        imageUrl: cover.imageUrl(preferPodcastCover: preferPodcastCover),
        position: position,
      );
    } catch (_) {
      return 'Envoi vers le Cast impossible';
    }
    return null;
  }

  /// Ferme le récepteur. `false` s’il n’y en avait pas.
  Future<bool> release() async {
    final playback = _playback;
    if (playback == null) return false;
    _playback = null;
    await _subscription?.cancel();
    _subscription = null;
    await playback.close();
    return true;
  }

  String _contentType(Episode episode) {
    final mime = episode.mimeType?.trim();
    if (mime != null && mime.isNotEmpty) return mime;
    final url = episode.audioUrl.toLowerCase();
    if (url.contains('.m4a') || url.contains('.mp4') || url.contains('.aac')) {
      return 'audio/mp4';
    }
    if (url.contains('.ogg') || url.contains('.opus')) return 'audio/ogg';
    return 'audio/mpeg';
  }
}
