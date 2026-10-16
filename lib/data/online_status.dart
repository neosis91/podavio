import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
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

/// Vrai si le réseau actif est mobile (ou satellite), sans Wi-Fi ni Ethernet.
///
/// Un VPN qui accompagne le Wi-Fi ne compte pas. Si le type est inconnu,
/// on ne bloque pas : un ordinateur ne doit pas attendre un Wi-Fi.
bool connectionUsesMobileData({
  required bool wifi,
  required bool ethernet,
  required bool mobile,
}) {
  if (wifi || ethernet) return false;
  return mobile;
}

/// Vrai quand un téléchargement non confirmé doit attendre le Wi-Fi.
bool mobileDataBlocksDownload({
  required bool allowMobileData,
  required bool mobileDataActive,
}) {
  return !allowMobileData && mobileDataActive;
}

/// Lecture du type de réseau. Remplaçable dans les tests.
final mobileDataProbeProvider = Provider<Future<bool> Function()>((ref) {
  return currentConnectionUsesMobileData;
});

Future<bool> currentConnectionUsesMobileData() async {
  try {
    final results = await Connectivity().checkConnectivity();
    var wifi = false;
    var ethernet = false;
    var mobile = false;
    for (final result in results) {
      switch (result) {
        case ConnectivityResult.wifi:
          wifi = true;
        case ConnectivityResult.ethernet:
          ethernet = true;
        case ConnectivityResult.mobile:
        case ConnectivityResult.satellite:
          mobile = true;
        case ConnectivityResult.bluetooth:
        case ConnectivityResult.vpn:
        case ConnectivityResult.other:
        case ConnectivityResult.none:
          break;
      }
    }
    return connectionUsesMobileData(
      wifi: wifi,
      ethernet: ethernet,
      mobile: mobile,
    );
  } catch (_) {
    return false;
  }
}
