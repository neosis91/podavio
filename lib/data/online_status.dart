import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `null` tant que le premier essai n’est pas fini, puis vrai si internet répond.
final onlineStatusProvider = NotifierProvider<OnlineStatusNotifier, bool?>(
  OnlineStatusNotifier.new,
);

class OnlineStatusNotifier extends Notifier<bool?> {
  Timer? _timer;
  var _running = false;

  @override
  bool? build() {
    final observer = _ResumeObserver(refresh);
    WidgetsBinding.instance.addObserver(observer);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
    ref.onDispose(() {
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(observer);
    });
    unawaited(refresh());
    return null;
  }

  Future<void> refresh() async {
    if (_running) return;
    _running = true;
    try {
      final online = await internetIsReachable();
      if (ref.mounted && state != online) state = online;
    } finally {
      _running = false;
    }
  }
}

class _ResumeObserver extends WidgetsBindingObserver {
  _ResumeObserver(this.onResume);

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

const _probes = <String>[
  'https://cp.cloudflare.com/generate_204',
  'https://www.gstatic.com/generate_204',
];

/// Vrai si l’une des adresses de contrôle répond.
Future<bool> internetIsReachable() async {
  final result = Completer<bool>();
  var pending = _probes.length;
  for (final url in _probes) {
    unawaited(
      _headOk(url).then((ok) {
        if (result.isCompleted) return;
        if (ok) {
          result.complete(true);
          return;
        }
        pending--;
        if (pending == 0) result.complete(false);
      }),
    );
  }
  return result.future;
}

Future<bool> _headOk(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client
        .headUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 4));
    final response = await request.close().timeout(const Duration(seconds: 4));
    await response.drain<void>();
    final code = response.statusCode;
    return code == 204 || code == 200;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
