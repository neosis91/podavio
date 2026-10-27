/// Pont entre le lecteur et la session Podavio Web, sans import croisé.
class WebRemoteHooks {
  static var active = false;
  static void Function(Map<String, Object?> command)? send;

  static void command(Map<String, Object?> payload) {
    if (!active) return;
    send?.call(payload);
  }
}
