import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../player/player_controller.dart';
import 'web_companion_crypto.dart';
import 'web_companion_keepalive.dart';
import 'web_companion_library.dart';
import 'web_companion_link.dart';
import 'web_companion_store.dart';

class WebCompanionState {
  const WebCompanionState({
    this.linked = false,
    this.socketOpen = false,
    this.browserOnline = false,
    this.fingerprint,
    this.error,
  });

  final bool linked;
  final bool socketOpen;
  final bool browserOnline;
  final String? fingerprint;
  final String? error;

  WebCompanionState copyWith({
    bool? linked,
    bool? socketOpen,
    bool? browserOnline,
    String? fingerprint,
    String? error,
    bool clearError = false,
  }) {
    return WebCompanionState(
      linked: linked ?? this.linked,
      socketOpen: socketOpen ?? this.socketOpen,
      browserOnline: browserOnline ?? this.browserOnline,
      fingerprint: fingerprint ?? this.fingerprint,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final webCompanionProvider =
    NotifierProvider<WebCompanionController, WebCompanionState>(
      WebCompanionController.new,
    );

class WebCompanionController extends Notifier<WebCompanionState> {
  final _store = WebCompanionStore();
  WebCompanionLink? _link;
  Timer? _pushTimer;
  var _pushing = false;
  var _generation = 0;

  @override
  WebCompanionState build() {
    ref.onDispose(() {
      _generation++;
      _pushTimer?.cancel();
      unawaited(_link?.close());
    });
    ref.listen(preferredPodcastsProvider, (_, _) => _schedulePush());
    ref.listen(
      playerProvider.select((player) => player.position),
      (_, _) => _schedulePush(),
    );
    unawaited(_restore());
    return const WebCompanionState();
  }

  Future<void> pair(String raw) async {
    final qr = WebCompanionQr.parse(raw);
    if (qr == null) {
      state = state.copyWith(error: 'invalid');
      return;
    }
    final generation = ++_generation;
    await _link?.close();
    WebCompanionHandshake handshake;
    try {
      handshake = await webCompanionHandshake(
        pwaPub: qr.pwaPub,
        conn: 'pair',
        random: Random.secure(),
      );
    } catch (_) {
      state = state.copyWith(error: 'invalid');
      return;
    }
    if (generation != _generation) return;
    final session = WebCompanionSession(
      relay: qr.relay,
      session: qr.session,
      pwaPub: qr.pwaPub,
      phonePub: handshake.phonePub,
      key: handshake.key,
      fingerprint: handshake.fingerprint,
    );
    await _store.write(session);
    if (generation != _generation) return;
    state = WebCompanionState(
      linked: true,
      fingerprint: session.fingerprint,
    );
    await _open(session, generation);
  }

  Future<void> disconnect() async {
    _generation++;
    _pushTimer?.cancel();
    await _link?.close();
    _link = null;
    await _store.clear();
    await stopWebCompanionKeepAlive();
    state = const WebCompanionState();
  }

  Future<void> _restore() async {
    final generation = _generation;
    final session = await _store.read();
    if (generation != _generation || session == null) return;
    state = state.copyWith(
      linked: true,
      fingerprint: session.fingerprint,
      clearError: true,
    );
    await _open(session, generation);
  }

  Future<void> _open(WebCompanionSession session, int generation) async {
    await startWebCompanionKeepAlive(_keepAliveTitle());
    final link = WebCompanionLink(
      session: session,
      onBrowser: (online) {
        if (generation != _generation) return;
        state = state.copyWith(browserOnline: online, socketOpen: true);
        if (online) _schedulePush();
      },
      onProgress: (progress) {
        unawaited(_saveProgress(progress.episodeId, progress.positionMs));
      },
    );
    _link = link;
    unawaited(link.start());
    if (generation == _generation) {
      state = state.copyWith(socketOpen: true, clearError: true);
    }
  }

  void _schedulePush() {
    if (_link?.browserOnline != true) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_push());
    });
  }

  Future<void> _push() async {
    final link = _link;
    if (link == null || !link.browserOnline || _pushing) return;
    _pushing = true;
    try {
      final snapshot = await buildWebCompanionSnapshot(
        ref.read(databaseProvider),
      );
      await link.sendSnapshot(snapshot);
    } catch (_) {
      // La session peut se fermer pendant l’envoi.
    } finally {
      _pushing = false;
    }
  }

  Future<void> _saveProgress(int episodeId, int positionMs) async {
    final database = ref.read(databaseProvider);
    final episode = await database.getEpisode(episodeId);
    if (episode == null) return;
    await database.setPosition(episodeId, positionMs);
  }

  String _keepAliveTitle() {
    final language = Platform.localeName.toLowerCase();
    if (language.startsWith('fr')) return 'Podavio Web est connecté';
    return 'Podavio Web is connected';
  }
}
