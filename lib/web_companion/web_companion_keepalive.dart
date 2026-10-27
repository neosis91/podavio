import 'dart:io';

import 'package:flutter/services.dart';

const _channel = MethodChannel('fr.podavio.podavio/web_companion');

Future<void> startWebCompanionKeepAlive(String title) async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('start', {'title': title});
  } catch (_) {}
}

Future<void> stopWebCompanionKeepAlive() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('stop');
  } catch (_) {}
}
