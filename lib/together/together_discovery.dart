import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';

const togetherServiceType = '_podavio-listen._tcp';

class TogetherEndpoint {
  const TogetherEndpoint({required this.host, required this.port});

  final String host;
  final int port;
}

class TogetherAdvertiser {
  BonsoirBroadcast? _broadcast;

  Future<void> start({required int port, required String code}) async {
    await stop();
    final broadcast = BonsoirBroadcast(
      printLogs: false,
      service: BonsoirService(
        name: 'Podavio $code',
        type: togetherServiceType,
        port: port,
        attributes: {'code': code},
      ),
    );
    _broadcast = broadcast;
    await broadcast.initialize();
    await broadcast.start();
  }

  Future<void> stop() async {
    final broadcast = _broadcast;
    _broadcast = null;
    if (broadcast == null) return;
    await broadcast.stop();
  }
}

/// Cherche une session annoncée sur le réseau local.
Future<TogetherEndpoint?> findTogetherSession(
  String code, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final discovery = BonsoirDiscovery(
    type: togetherServiceType,
    printLogs: false,
  );
  await discovery.initialize();
  final found = Completer<TogetherEndpoint?>();
  final subscription = discovery.eventStream?.listen((event) {
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      event.service.resolve(discovery.serviceResolver);
      return;
    }
    if (event is! BonsoirDiscoveryServiceResolvedEvent || found.isCompleted) {
      return;
    }
    final service = event.service;
    if ((service.attributes['code'] ?? '').toUpperCase() != code) return;
    final host = _ipv4Host(service);
    if (host == null) return;
    found.complete(TogetherEndpoint(host: host, port: service.port));
  });
  try {
    await discovery.start();
    return await found.future.timeout(timeout, onTimeout: () => null);
  } finally {
    await subscription?.cancel();
    await discovery.stop();
  }
}

String? _ipv4Host(BonsoirService service) {
  for (final host in service.hostAddresses) {
    final parsed = InternetAddress.tryParse(host);
    if (parsed != null && parsed.type == InternetAddressType.IPv4) {
      return host;
    }
  }
  return service.hostAddress;
}
